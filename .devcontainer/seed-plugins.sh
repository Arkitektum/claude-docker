#!/bin/bash
# Clone the Arkitektum marketplace and build a plugin seed directory.
# Runs on the host before docker build — the seed dir ends up in the build context.
# The seed is then used by setup-plugins.sh at container startup.
set -e

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed" >&2
  exit 1
fi

SEED_DIR="${1:?Usage: seed-plugins.sh <seed-dir>}"
MARKETPLACE_REPO="https://github.com/Arkitektum/claude-code-marketplace.git"
MARKETPLACE_CLONE="$SEED_DIR/clone"

# Clone or update marketplace
if [ -d "$MARKETPLACE_CLONE/.git" ]; then
  git -C "$MARKETPLACE_CLONE" pull --ff-only 2>/dev/null || true
else
  mkdir -p "$SEED_DIR"
  git clone --depth 1 "$MARKETPLACE_REPO" "$MARKETPLACE_CLONE"
fi

MARKETPLACE_JSON="$MARKETPLACE_CLONE/.claude-plugin/marketplace.json"
MARKETPLACE_NAME=$(jq -r '.name' "$MARKETPLACE_JSON")

# Copy marketplace content
mkdir -p "$SEED_DIR/seed/marketplaces"
rm -rf "$SEED_DIR/seed/marketplaces/$MARKETPLACE_NAME"
cp -r "$MARKETPLACE_CLONE" "$SEED_DIR/seed/marketplaces/$MARKETPLACE_NAME"

# Populate plugin cache from relative-path plugins
mkdir -p "$SEED_DIR/seed/cache"
jq -r '.plugins[] | select(.source | type == "string" and startswith("./")) | "\(.name)\t\(.version // "0.0.0")\t\(.source)"' "$MARKETPLACE_JSON" |
while IFS=$'\t' read -r name version source; do
  plugin_src="$MARKETPLACE_CLONE/$source"
  if [ -d "$plugin_src" ]; then
    cache_dst="$SEED_DIR/seed/cache/$MARKETPLACE_NAME/$name/$version"
    rm -rf "$cache_dst"
    mkdir -p "$cache_dst"
    cp -r "$plugin_src/." "$cache_dst/"
  fi
done
