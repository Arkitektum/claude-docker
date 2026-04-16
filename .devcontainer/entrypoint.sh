#!/bin/bash
set -euo pipefail

# Symlink .claude.json from the mounted .claude/ directory
# (the real file lives at ~/.claude/.claude.json, managed by the host script)
ln -sf "${HOME}/.claude/.claude.json" "${HOME}/.claude.json"

# Container initialization
if [ "${DISABLE_FIREWALL:-}" != "1" ] && [ ! -f /tmp/.proxy-ready ]; then
    sudo --preserve-env=LOCAL_USER /usr/local/bin/init-proxy.sh
fi
/usr/local/bin/setup-plugins.sh

# Source proxy host bypass so claude inherits the updated no_proxy
# (BASH_ENV is not honored by Claude Code's internal shell)
if [ -f /etc/proxy-host.sh ]; then
    . /etc/proxy-host.sh
fi

exec "$@"
