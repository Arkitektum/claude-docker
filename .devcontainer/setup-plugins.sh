#!/bin/bash
# Register the Arkitektum marketplace and populate the plugin cache if not already present.
# Runs inside the container at startup - writes to ~/.claude/plugins/ (bind-mounted from host).
# Only adds entries that don't already exist - never overwrites existing user config.
set -e

PLUGIN_DIR="${HOME}/.claude/plugins"
SEED_DIR="/opt/claude-plugin-seed"
MARKETPLACE_JSON="$SEED_DIR/marketplaces/arkitektum-marketplace/.claude-plugin/marketplace.json"

if [ ! -f "$MARKETPLACE_JSON" ]; then
  exit 0
fi

MARKETPLACE_NAME=$(jq -r '.name' "$MARKETPLACE_JSON")

# Skip entirely if marketplace is already registered
KM_FILE="$PLUGIN_DIR/known_marketplaces.json"
if [ -f "$KM_FILE" ] && jq -e --arg name "$MARKETPLACE_NAME" 'has($name)' "$KM_FILE" >/dev/null 2>&1; then
  exit 0
fi

MARKETPLACE_SRC="$SEED_DIR/marketplaces/$MARKETPLACE_NAME"
MARKETPLACE_DST="$PLUGIN_DIR/marketplaces/$MARKETPLACE_NAME"

mkdir -p "$PLUGIN_DIR/marketplaces" "$PLUGIN_DIR/cache"

# Copy marketplace content
cp -r "$MARKETPLACE_SRC" "$MARKETPLACE_DST"

# Register marketplace
[ -f "$KM_FILE" ] && [ -s "$KM_FILE" ] || echo '{}' > "$KM_FILE"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
ENTRY=$(jq -n --arg path "$MARKETPLACE_DST" --arg ts "$NOW" \
  '{"source":{"source":"github","repo":"Arkitektum/claude-code-marketplace"},"installLocation":$path,"lastUpdated":$ts}')
jq --arg name "$MARKETPLACE_NAME" --argjson entry "$ENTRY" \
  '.[$name] = $entry' "$KM_FILE" > "$KM_FILE.tmp" && mv "$KM_FILE.tmp" "$KM_FILE"

# Register and cache plugins
IP_FILE="$PLUGIN_DIR/installed_plugins.json"
if [ ! -f "$IP_FILE" ] || [ ! -s "$IP_FILE" ]; then
  echo '{"version":2,"plugins":{}}' > "$IP_FILE"
fi

jq -r '.plugins[] | select(.source | type == "string" and startswith("./")) | "\(.name)\t\(.version // "0.0.0")\t\(.source)"' "$MARKETPLACE_JSON" |
while IFS=$'\t' read -r name version source; do
  plugin_key="${name}@${MARKETPLACE_NAME}"
  plugin_cache_dir="$PLUGIN_DIR/cache/$MARKETPLACE_NAME/$name"
  install_path="$plugin_cache_dir/$version"

  # Cache plugin content if not already cached
  if [ ! -d "$plugin_cache_dir" ]; then
    plugin_src="$MARKETPLACE_SRC/$source"
    if [ -d "$plugin_src" ]; then
      mkdir -p "$install_path"
      cp -r "$plugin_src/." "$install_path/"
    fi
  fi

  # Register in installed_plugins.json if not already there
  if ! jq -e --arg key "$plugin_key" '.plugins | has($key)' "$IP_FILE" >/dev/null 2>&1; then
    PLUGIN_ENTRY=$(jq -n --arg path "$install_path" --arg ver "$version" --arg ts "$NOW" \
      '[{"scope":"user","installPath":$path,"version":$ver,"installedAt":$ts,"lastUpdated":$ts}]')
    jq --arg key "$plugin_key" --argjson entry "$PLUGIN_ENTRY" \
      '.plugins[$key] = $entry' "$IP_FILE" > "$IP_FILE.tmp" && mv "$IP_FILE.tmp" "$IP_FILE"
  fi
done
