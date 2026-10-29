#!/bin/bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

STATE="${HOME}/.claude/plugins/installed_plugins.json"
SETTINGS="${HOME}/.claude/settings.json"

echo "Plugin tests"
echo "============"

# run.sh starts testing once the proxy is up, while the entrypoint is still installing
# plugins. superpowers is the last one it installs.
for _ in $(seq 1 180); do
    jq -e '.plugins["superpowers@claude-plugins-official"][0]' "$STATE" >/dev/null 2>&1 && break
    sleep 1
done

assert_pass "plugin auto-update forced on" \
    test "${FORCE_AUTOUPDATE_PLUGINS:-}" = 1

assert_pass "arkitektum-marketplace auto-updates" \
    jq -e '.extraKnownMarketplaces["arkitektum-marketplace"].autoUpdate == true' "$SETTINGS"

for plugin in arkitektum-mandatory@arkitektum-marketplace \
    mattpocock-skills@arkitektum-marketplace \
    arkitektum-security@arkitektum-marketplace \
    superpowers@claude-plugins-official; do
    assert_pass "$plugin installed" \
        jq -e --arg p "$plugin" '.plugins[$p][0]' "$STATE"
done

test_summary
