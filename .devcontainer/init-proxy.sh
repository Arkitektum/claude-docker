#!/bin/bash
set -euo pipefail

# --- Status helpers ---
GREEN='\033[32m'
YELLOW='\033[33m'
GREY='\033[90m'
BOLD='\033[1m'
RESET='\033[0m'

# Firewall disabled (--no-firewall): no proxy/iptables to set up, just report.
# Runs unprivileged in this mode (sudo is unavailable under --cap-drop=ALL).
if [ "${DISABLE_FIREWALL:-}" = "1" ]; then
    echo ""
    echo -e "  ${YELLOW}${BOLD}Firewall disabled (--no-firewall)${RESET}"
    echo -e "  ${GREY}└ Direct, unrestricted network access; localhost reaches the host network${RESET}"
    echo ""
    exit 0
fi

# Idempotent: skip if already initialized
if [ -f /tmp/.proxy-ready ]; then
    exit 0
fi

# --- Append user-supplied allowed domains (from CLAUDE_DOCKER_ALLOW_DOMAINS) ---
# Accepts whitespace- or comma-separated domain names. squid loads
# /etc/squid/allowed_domains.txt at startup, so appending here is sufficient.
if [ -n "${CLAUDE_DOCKER_ALLOW_DOMAINS:-}" ]; then
    EXTRA_DOMAINS=$(echo "$CLAUDE_DOCKER_ALLOW_DOMAINS" | tr ',\t\n' '   ')
    for d in $EXTRA_DOMAINS; do
        echo "$d" >> /etc/squid/allowed_domains.txt
    done
fi

# --- Start squid proxy ---
squid -f /etc/squid/squid.conf -N -d 2 2>/dev/null &
SQUID_PID=$!

for _ in $(seq 1 30); do
    if ss -tlnp 2>/dev/null | grep -q ':3128'; then
        break
    fi
    if ! kill -0 "$SQUID_PID" 2>/dev/null; then
        echo "ERROR: Squid process died" >&2
        wait "$SQUID_PID" 2>/dev/null || true
        cat /var/log/squid/cache.log 2>/dev/null >&2
        exit 1
    fi
    sleep 0.5
done

if ! ss -tlnp 2>/dev/null | grep -q ':3128'; then
    echo "ERROR: Squid not listening on port 3128" >&2
    cat /var/log/squid/cache.log 2>/dev/null >&2
    exit 1
fi
# --- Setup iptables ---
# Preserve Docker internal DNS NAT rules
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

if [ -n "$DOCKER_DNS_RULES" ]; then
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

# Loopback (proxy <-> claude communication)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Established/related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Docker host network (set via --add-host=host.docker.internal:host-gateway)
HOST_IP=$(getent ahostsv4 host.docker.internal 2>/dev/null | awk 'NR==1{print $1}')
if [ -n "$HOST_IP" ]; then
    HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
    iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
    iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT
fi

# Squid (proxy user) gets full outbound for proxying
iptables -A OUTPUT -m owner --uid-owner proxy -j ACCEPT

# Claude user: localhost only (to reach the proxy)
CLAUDE_USER="${LOCAL_USER:-claude}"
CLAUDE_UID=$(id -u "$CLAUDE_USER")
iptables -A OUTPUT -m owner --uid-owner "$CLAUDE_UID" -d 127.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -m owner --uid-owner "$CLAUDE_UID" -j REJECT --reject-with icmp-admin-prohibited

# root and _apt: localhost only (for apt-safe via sudo)
iptables -A OUTPUT -m owner --uid-owner 0 -d 127.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -m owner --uid-owner 0 -j REJECT --reject-with icmp-admin-prohibited
if id -u _apt &>/dev/null; then
    iptables -A OUTPUT -m owner --uid-owner _apt -d 127.0.0.0/8 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner _apt -j REJECT --reject-with icmp-admin-prohibited
fi

# Default: drop everything else
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# IPv6: mirror IPv4 policy (loopback + proxy user allowed, claude user blocked)
if command -v ip6tables &>/dev/null; then
    ip6tables -F 2>/dev/null || true
    ip6tables -A INPUT -i lo -j ACCEPT
    ip6tables -A OUTPUT -o lo -j ACCEPT
    ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A OUTPUT -m owner --uid-owner proxy -j ACCEPT
    ip6tables -A OUTPUT -m owner --uid-owner "$CLAUDE_UID" -j REJECT
    ip6tables -P INPUT DROP
    ip6tables -P FORWARD DROP
    ip6tables -P OUTPUT DROP
fi

# --- localhost -> host mapping ---
# Point "localhost" to the Docker host so that localhost:PORT reaches
# services on the user's machine. The proxy uses 127.0.0.1 directly
# so it's unaffected. Container-internal services bind to container.local.
if [ -n "$HOST_IP" ]; then
    # sed -i fails on /etc/hosts (Docker bind mount rejects rename), so use cp.
    # Remove IPv6 localhost too, otherwise getent/curl prefer ::1 over the IPv4 mapping.
    sed -e "s/^127\.0\.0\.1\s\+localhost.*/$HOST_IP localhost/" \
        -e "s/^::1\s\+localhost.*/#::1 localhost/" /etc/hosts > /tmp/hosts.tmp
    if ! grep -q 'container.local' /tmp/hosts.tmp; then
        echo "127.0.0.2 container.local" >> /tmp/hosts.tmp
    fi
    cp /tmp/hosts.tmp /etc/hosts
    rm /tmp/hosts.tmp
fi

# --- Verification ---
if ! curl -sf -x http://127.0.0.1:3128 --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Cannot reach api.github.com through proxy" >&2
    exit 1
fi

if curl -sf -x http://127.0.0.1:3128 --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: example.com should be blocked by proxy" >&2
    exit 1
fi

if su -s /bin/sh "$CLAUDE_USER" -c 'curl -sf --noproxy "*" --connect-timeout 3 https://api.github.com/zen' >/dev/null 2>&1; then
    echo "ERROR: Direct outbound connection should be blocked" >&2
    exit 1
fi
echo ""
echo -e "  ${GREEN}${BOLD}Proxy started, firewall configured${RESET}"
echo -e "  ${GREY}\u251C Proxy allow/deny verified, direct connections blocked${RESET}"
if [ -n "$HOST_IP" ]; then
    echo -e "  ${GREY}\u2514 localhost remapped to host machine ($HOST_IP), use container.local for this container's localhost${RESET}"
fi
echo ""

# --- Host proxy bypass ---
# Add host gateway IP to no_proxy so traffic to the host bypasses Squid.
# Sourced by entrypoint.sh before exec'ing claude.
if [ -n "$HOST_IP" ]; then
    cat > /etc/proxy-host.sh <<EOF
export no_proxy="\${no_proxy},${HOST_IP}"
export NO_PROXY="\${NO_PROXY},${HOST_IP}"
EOF
fi

touch /tmp/.proxy-ready
