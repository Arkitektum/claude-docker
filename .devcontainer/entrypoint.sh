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

# Publish the proxied container instructions as the managed-policy CLAUDE.md that
# every session and subagent loads. Only needed in firewall mode: the image ships
# CLAUDE.md as a copy of container.md, which is already complete without the
# firewall. Runs after the branch above so the allowlist it reads is the live one.
if [ "${DISABLE_FIREWALL:-}" != "1" ]; then
    if ! sudo /usr/local/bin/write-container-md; then
        echo "WARN: could not refresh /etc/claude-code/CLAUDE.md, it does not describe the proxy or the allowlist" >&2
    fi
fi

# Install and refresh the mandatory Arkitektum marketplace plugin. ~/.claude is
# host-mounted so installs persist. Needs github.com (allowlisted), no login.
#
# The claude CLI commands are slow (a full Node boot each), so warm starts use a
# cheap freshness probe instead: one git ls-remote round trip, compared against
# the installed plugin's commit SHA. The marketplace versions plugins by commit
# SHA, so remote HEAD == installed SHA means a full update would be a no-op.
# A raw git pull of the marketplace clone cannot replace the CLI: sessions load
# plugin content from a SHA-keyed snapshot under ~/.claude/plugins/cache/,
# which only claude plugin install/update writes.
PLUGIN_STATE="${HOME}/.claude/plugins/installed_plugins.json"
MARKETPLACE_URL="https://github.com/Arkitektum/claude-code-marketplace"
installed_sha=$(jq -r '.plugins["arkitektum-mandatory@arkitektum-marketplace"][0].gitCommitSha // empty' "$PLUGIN_STATE" 2>/dev/null || true)

if [ -z "$installed_sha" ]; then
    echo "Installing arkitektum-mandatory plugin (not found in ~/.claude)..."
    claude plugin marketplace add Arkitektum/claude-code-marketplace >/dev/null 2>&1 || true
    claude plugin marketplace update arkitektum-marketplace >/dev/null 2>&1 || true
    if ! claude plugin install arkitektum-mandatory@arkitektum-marketplace >/dev/null 2>&1; then
        echo "WARN: failed to install mandatory plugin arkitektum-mandatory (github unreachable?)" >&2
    fi
else
    remote_sha=$(git ls-remote "$MARKETPLACE_URL" HEAD 2>/dev/null | cut -f1 || true)
    if [ -z "$remote_sha" ]; then
        echo "WARN: marketplace repo unreachable, keeping arkitektum-mandatory at ${installed_sha:0:12}" >&2
    elif [ "$remote_sha" != "$installed_sha" ]; then
        echo "Updating arkitektum-mandatory plugin: ${installed_sha:0:12} -> ${remote_sha:0:12}..."
        claude plugin marketplace update arkitektum-marketplace >/dev/null 2>&1 || true
        if ! claude plugin update arkitektum-mandatory@arkitektum-marketplace >/dev/null 2>&1; then
            echo "WARN: plugin update failed, still at ${installed_sha:0:12}" >&2
        fi
    fi
fi

# Installing is not enough: enablement is a separate flag in settings.json,
# `claude plugin disable` writes an explicit false, and `claude plugin update`
# never touches it. Reading the flag costs 3ms against 400ms for a CLI call, and
# `claude plugin enable` exits non-zero when the plugin is already enabled, so
# only call it when the flag is actually missing.
plugin_enabled=$(jq -r '.enabledPlugins["arkitektum-mandatory@arkitektum-marketplace"] // empty' "${HOME}/.claude/settings.json" 2>/dev/null || true)
if [ "$plugin_enabled" != "true" ]; then
    echo "Enabling arkitektum-mandatory plugin..."
    if ! enable_out=$(claude plugin enable arkitektum-mandatory@arkitektum-marketplace 2>&1); then
        echo "WARN: ${enable_out}" >&2
    fi
fi

# Source proxy host bypass so claude inherits the updated no_proxy
# (BASH_ENV is not honored by Claude Code's internal shell)
if [ -f /etc/proxy-host.sh ]; then
    . /etc/proxy-host.sh
fi

exec "$@"
