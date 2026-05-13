#!/bin/bash
# Test fixture: writes a marker file so tests can verify the script ran
# as root during the image build, as the CLAUDE_DOCKER_CUSTOMIZE contract requires.
set -e
mkdir -p /etc/claude-code
echo "customize-ran uid=$(id -u)" > /etc/claude-code/customize-test-marker
chmod 0644 /etc/claude-code/customize-test-marker
