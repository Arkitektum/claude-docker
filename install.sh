#!/bin/bash

set -e

BIN_DIR="${HOME}/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/claude-docker"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create directories
mkdir -p "$BIN_DIR" "$DATA_DIR"

# Install build context
cp "$SCRIPT_DIR/.devcontainer/Dockerfile" "$DATA_DIR/Dockerfile"
cp "$SCRIPT_DIR/.devcontainer/init-firewall.sh" "$DATA_DIR/init-firewall.sh"
cp "$SCRIPT_DIR/.devcontainer/seed-plugins.sh" "$DATA_DIR/seed-plugins.sh"
cp "$SCRIPT_DIR/.devcontainer/setup-plugins.sh" "$DATA_DIR/setup-plugins.sh"
cp "$SCRIPT_DIR/.devcontainer/container.md" "$DATA_DIR/container.md"
cp "$SCRIPT_DIR/.devcontainer/claude-wrapper.sh" "$DATA_DIR/claude-wrapper.sh"
chmod +x "$DATA_DIR/seed-plugins.sh" "$DATA_DIR/setup-plugins.sh" "$DATA_DIR/claude-wrapper.sh"

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
