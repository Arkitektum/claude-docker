#!/bin/bash
set -euo pipefail

# Idempotent: skip if already initialized
if [ -f /tmp/.proxy-ready ]; then
    exit 0
fi

# --- Print logo ----

echo
printf '\033[91m'
  cat << 'EOF'
   █████╗  ██████╗  ██╗  ██╗ ██╗ ████████╗ ███████╗ ██╗  ██╗ ████████╗ ██╗   ██╗ ███╗   ███╗
   ██╔══██╗ ██╔══██╗ ██║ ██╔╝ ██║ ╚══██╔══╝ ██╔════╝ ██║ ██╔╝ ╚══██╔══╝ ██║   ██║ ████╗ ████║
   ███████║ ██████╔╝ █████╔╝  ██║    ██║    █████╗   █████╔╝     ██║    ██║   ██║ ██╔████╔██║
   ██╔══██║ ██╔══██╗ ██╔═██╗  ██║    ██║    ██╔══╝   ██╔═██╗     ██║    ██║   ██║ ██║╚██╔╝██║
   ██║  ██║ ██║  ██║ ██║  ██╗ ██║    ██║    ███████╗ ██║  ██╗    ██║    ╚██████╔╝ ██║ ╚═╝ ██║
   ╚═╝  ╚═╝ ╚═╝  ╚═╝ ╚═╝  ╚═╝ ╚═╝    ╚═╝    ╚══════╝ ╚═╝  ╚═╝    ╚═╝     ╚═════╝  ╚═╝     ╚═╝
EOF
printf '\033[0m'

# --- Status helpers ---
RED='\033[91m'
GREEN='\033[32m'
BOLD='\033[1m'
RESET='\033[0m'
status_line() { echo -e "  ${RED}$1${RESET}"; }

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
status_line "Squid proxy started"

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

# Docker host network
HOST_IP=$(ip route | grep default | cut -d" " -f3)
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

status_line "Firewall configured"

# --- Verification ---
if ! curl -sf -x http://127.0.0.1:3128 --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Cannot reach api.github.com through proxy" >&2
    exit 1
fi
status_line "Verified: allowed domain reachable through proxy"

if curl -sf -x http://127.0.0.1:3128 --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: example.com should be blocked by proxy" >&2
    exit 1
fi
status_line "Verified: blocked domain rejected by proxy"

if su -s /bin/sh "$CLAUDE_USER" -c 'curl -sf --noproxy "*" --connect-timeout 3 https://api.github.com/zen' >/dev/null 2>&1; then
    echo "ERROR: Direct outbound connection should be blocked" >&2
    exit 1
fi
status_line "Verified: direct connections blocked by firewall"

touch /tmp/.proxy-ready
echo -e "\n  ${GREEN}${BOLD}Proxy and firewall ready${RESET}\n"
