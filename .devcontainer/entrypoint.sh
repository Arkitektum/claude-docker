#!/bin/bash
set -euo pipefail

# Symlink .claude.json from the mounted .claude/ directory
# (the real file lives at ~/.claude/.claude.json, managed by the host script)
ln -sf "${HOME}/.claude/.claude.json" "${HOME}/.claude.json"

# Banner (both modes); init-proxy.sh prints the status text per branch below.
printf '\n\033[91m%s\033[0m\n' "\
    █████╗  ██████╗  ██╗  ██╗ ██╗ ████████╗ ███████╗ ██╗  ██╗ ████████╗ ██╗   ██╗ ███╗   ███╗
   ██╔══██╗ ██╔══██╗ ██║ ██╔╝ ██║ ╚══██╔══╝ ██╔════╝ ██║ ██╔╝ ╚══██╔══╝ ██║   ██║ ████╗ ████║
   ███████║ ██████╔╝ █████╔╝  ██║    ██║    █████╗   █████╔╝     ██║    ██║   ██║ ██╔████╔██║
   ██╔══██║ ██╔══██╗ ██╔═██╗  ██║    ██║    ██╔══╝   ██╔═██╗     ██║    ██║   ██║ ██║╚██╔╝██║
   ██║  ██║ ██║  ██║ ██║  ██╗ ██║    ██║    ███████╗ ██║  ██╗    ██║    ╚██████╔╝ ██║ ╚═╝ ██║
   ╚═╝  ╚═╝ ╚═╝  ╚═╝ ╚═╝  ╚═╝ ╚═╝    ╚═╝    ╚══════╝ ╚═╝  ╚═╝    ╚═╝     ╚═════╝  ╚═╝     ╚═╝"

# Container initialization
if [ "${DISABLE_FIREWALL:-}" = "1" ]; then
    # No proxy is running; strip the baked-in proxy env so requests go direct.
    # (Must happen here: init-proxy.sh is a child and can't alter our env.)
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY
    # Unprivileged: just prints the disabled-firewall status (sudo is unavailable).
    /usr/local/bin/init-proxy.sh
elif [ ! -f /tmp/.proxy-ready ]; then
    sudo --preserve-env=LOCAL_USER,CLAUDE_DOCKER_ALLOW_DOMAINS /usr/local/bin/init-proxy.sh
fi
# Install and refresh the mandatory Arkitektum marketplace plugin on every start.
# All four commands are idempotent: add/install handle a cold ~/.claude, the two
# updates git-pull the marketplace and bring the plugin to the latest published
# version (deterministic refresh, one git pull per start). ~/.claude is
# host-mounted so installs persist. Needs github.com (allowlisted), no login.
# Note: an update only delivers content if the marketplace bumps its version or
# uses commit-SHA versioning; a frozen version string keeps the cached copy.
claude plugin marketplace add Arkitektum/claude-code-marketplace >/dev/null 2>&1 || true
claude plugin marketplace update arkitektum-marketplace >/dev/null 2>&1 || true
if ! claude plugin install arkitektum-mandatory@arkitektum-marketplace >/dev/null 2>&1; then
    echo "WARN: failed to install mandatory plugin arkitektum-mandatory (github unreachable?)" >&2
fi
claude plugin update arkitektum-mandatory@arkitektum-marketplace >/dev/null 2>&1 || true

# Source proxy host bypass so claude inherits the updated no_proxy
# (BASH_ENV is not honored by Claude Code's internal shell)
if [ -f /etc/proxy-host.sh ]; then
    . /etc/proxy-host.sh
fi

exec "$@"
