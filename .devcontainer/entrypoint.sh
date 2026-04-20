#!/bin/bash
set -euo pipefail

# Symlink .claude.json from the mounted .claude/ directory
# (the real file lives at ~/.claude/.claude.json, managed by the host script)
ln -sf "${HOME}/.claude/.claude.json" "${HOME}/.claude.json"

# Container initialization
if [ "${DISABLE_FIREWALL:-}" = "1" ]; then
    # No proxy is running; strip the baked-in proxy env so requests go direct.
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY
elif [ ! -f /tmp/.proxy-ready ]; then
    sudo --preserve-env=LOCAL_USER /usr/local/bin/init-proxy.sh
fi
/usr/local/bin/setup-plugins.sh

exec "$@"
