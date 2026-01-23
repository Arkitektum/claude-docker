#!/bin/bash

set -e

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_NAME="claude-docker"
SCRIPT_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/claude-docker"

# Create ~/.local/bin if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Copy the script
cp "$SCRIPT_SOURCE" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "ℹ️  ${INSTALL_DIR} is not in your PATH"
    echo "Add this to your shell config (~/.bashrc, ~/.zshrc, etc):"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
else
    echo "✓ Installation complete: $INSTALL_DIR/$SCRIPT_NAME"
fi
