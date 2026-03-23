You are running inside a Docker container based on Ubuntu.

## Environment

The container includes multiple language runtimes (Node.js, Python with uv, Go, Rust, .NET), Playwright with Chromium, and common tools (git, ripgrep, jq, tree, postgresql-client). A Terraform MCP Server is also available.

## Constraints

- **Network firewall may be active.** Outbound traffic is restricted to approved domains only (listed below). All other outbound connections are blocked. If a network request fails unexpectedly, this is likely why.
- **You only have access to the mounted project directory.** The host filesystem is not available beyond the current working directory and `~/.claude`.
- **You are inside Docker.** System-level changes (installing packages with apt, modifying system config) require root/sudo and won't persist across container restarts unless part of the Dockerfile.
- **No SSH keys or git credentials are available.** Git operations to private repositories will fail. Public HTTPS clones work if the domain is in the firewall allowlist.
