#!/bin/bash
exec "$@" --append-system-prompt-file /etc/claude-code/container.md
