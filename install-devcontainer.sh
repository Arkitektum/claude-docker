#!/bin/bash
set -e

TARGET="${1:?Usage: install-devcontainer.sh <project-dir>}"

if [ ! -d "$TARGET" ]; then
  echo "Error: $TARGET is not a directory" >&2
  exit 1
fi

if [ -d "$TARGET/.devcontainer" ]; then
  echo "Error: $TARGET/.devcontainer already exists — refusing to overwrite" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/.devcontainer"

if [ ! -d "$SOURCE" ]; then
  echo "Error: .devcontainer/ not found in $SCRIPT_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET/.devcontainer"

# Copy top-level files
for f in Dockerfile devcontainer.json squid.conf allowed_domains.txt init-proxy.sh entrypoint.sh \
         setup-plugins.sh seed-plugins.sh container.md apt-safe \
         init-host customize.sh; do
  cp "$SOURCE/$f" "$TARGET/.devcontainer/$f"
done

echo "Installed .devcontainer/ into $TARGET"
echo "Open the project in VS Code and reopen in container (Ctrl+Shift+P → 'Dev Containers: Reopen in Container')"
