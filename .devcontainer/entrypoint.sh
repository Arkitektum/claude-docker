#!/bin/bash
set -euo pipefail

# Container initialization
if [ "${DISABLE_FIREWALL:-}" != "1" ] && [ ! -f /tmp/.proxy-ready ]; then
    sudo --preserve-env=LOCAL_USER /usr/local/bin/init-proxy.sh
fi
/usr/local/bin/setup-plugins.sh

exec "$@"
