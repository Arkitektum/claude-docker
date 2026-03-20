#!/bin/bash
# Clone the Arkitektum marketplace and build a Claude Code plugin seed directory.
# Runs on the host before docker build — the seed dir ends up in the build context.
set -e

SEED_DIR="${1:?Usage: seed-plugins.sh <seed-dir>}"
MARKETPLACE_REPO="https://github.com/Arkitektum/claude-code-marketplace.git"
MARKETPLACE_OWNER="Arkitektum"
MARKETPLACE_REPO_NAME="claude-code-marketplace"
MARKETPLACE_CLONE="$SEED_DIR/clone"

# Slug used by Claude Code for filesystem paths (owner-repo)
MARKETPLACE_SLUG="${MARKETPLACE_OWNER}-${MARKETPLACE_REPO_NAME}"

# Clone or update marketplace
if [ -d "$MARKETPLACE_CLONE/.git" ]; then
  git -C "$MARKETPLACE_CLONE" pull --ff-only 2>/dev/null || true
else
  mkdir -p "$SEED_DIR"
  git clone --depth 1 "$MARKETPLACE_REPO" "$MARKETPLACE_CLONE"
fi

MARKETPLACE_JSON="$MARKETPLACE_CLONE/.claude-plugin/marketplace.json"
MARKETPLACE_NAME=$(jq -r '.name' "$MARKETPLACE_JSON")

# Build seed directory structure
mkdir -p "$SEED_DIR/seed/marketplaces" "$SEED_DIR/seed/cache"
rm -rf "$SEED_DIR/seed/marketplaces/$MARKETPLACE_SLUG"
cp -r "$MARKETPLACE_CLONE" "$SEED_DIR/seed/marketplaces/$MARKETPLACE_SLUG"

# Register marketplace
jq -n --arg name "$MARKETPLACE_NAME" --arg owner "$MARKETPLACE_OWNER" --arg repo "${MARKETPLACE_OWNER}/${MARKETPLACE_REPO_NAME}" \
  '{($name): {"source": {"source": "github", "repo": $repo}}}' \
  > "$SEED_DIR/seed/known_marketplaces.json"

# Populate plugin cache from relative-path plugins
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
