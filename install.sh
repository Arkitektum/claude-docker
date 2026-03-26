#!/bin/bash

set -e

BIN_DIR="${HOME}/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/claude-docker"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/.devcontainer"

# Create directories
mkdir -p "$BIN_DIR" "$DATA_DIR"

# Install build context (everything Docker needs)
for f in Dockerfile squid.conf init-proxy.sh entrypoint.sh \
         seed-plugins.sh setup-plugins.sh container.md apt-safe; do
  cp "$SOURCE/$f" "$DATA_DIR/$f"
done
chmod +x "$DATA_DIR/init-proxy.sh" "$DATA_DIR/entrypoint.sh" \
         "$DATA_DIR/seed-plugins.sh" "$DATA_DIR/setup-plugins.sh"

# Install CLI script
cp "$SCRIPT_DIR/claude-docker" "$BIN_DIR/claude-docker"
chmod +x "$BIN_DIR/claude-docker"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "${BIN_DIR} is not in your PATH"
    echo "Add this to your shell config (~/.bashrc, ~/.zshrc, etc):"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
else
    echo "Installed: $BIN_DIR/claude-docker"
    echo "Build context: $DATA_DIR/"
fi
