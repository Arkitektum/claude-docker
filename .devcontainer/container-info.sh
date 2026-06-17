#!/bin/bash
# Emit container documentation for the Claude Code SessionStart hook.
# The network section depends on whether the firewall/proxy is active
# (DISABLE_FIREWALL=1 is set by claude-docker's --no-firewall flag).
set -eu

cat /etc/claude-code/container.md

if [ "${DISABLE_FIREWALL:-}" = "1" ]; then
    cat <<'EOF'

## Network

The container shares the host's network namespace:
- `localhost` is the host's localhost. Services the user runs on their machine are reachable at `localhost:PORT`.
- A server you start in the container binds directly to the host's network, so the user can reach it at `localhost:PORT` in their browser.
EOF
else
    cat <<'EOF'

## Network

**Internet access** is restricted by a Squid proxy and iptables firewall:
- HTTP/HTTPS traffic goes through a Squid proxy that only allows approved domains (listed below).
- Direct outbound connections are blocked by iptables.
- If a request fails unexpectedly, the domain is likely not in the proxy allowlist.

**`localhost` reaches the host machine**, not this container:
- `localhost` resolves to the user's host machine via `/etc/hosts`.
- `localhost:5173`, `localhost:8080`, etc. connect to services the user is running outside Docker.
- Use `localhost` (the hostname), not `127.0.0.1`. The raw IP `127.0.0.1` still points to the container.
- `curl` hardcodes `localhost` to `127.0.0.1` and bypasses `/etc/hosts`. When testing with curl, use the host IP directly: `curl http://$(getent hosts localhost | awk '{print $1}'):PORT`

**Container-internal services** use `container.local`:
- Bind to `container.local` (resolves to `127.0.0.2`) for servers started inside this container.
- Example: `vite --host container.local`, `python -m http.server --bind 127.0.0.2 8000`
- These are only reachable from inside the container, not from the user's browser.
- If you plan to run a service that the user needs to access in their browser, ask them to run it on their machine instead.

**Do not modify proxy or firewall settings.** The proxy config, iptables rules, and related system files are protected and read-only.

## Proxy allowlist

Allowed domains (all subdomains included where prefixed with dot):

EOF
    sort -u /etc/squid/allowed_domains.txt | sed 's/^/- /'
fi
