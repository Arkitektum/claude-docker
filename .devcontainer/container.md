You are running inside a Docker container based on Ubuntu.

## Environment

The container includes multiple language runtimes (Node.js, Python with uv, Go, Rust, .NET), Playwright with Chromium, and common tools (git, ripgrep, jq, tree, postgresql-client). A Terraform MCP Server is also available.

## APT package management

Use `sudo apt-safe` to install system packages. This is a hardened wrapper around apt that validates package names. **Installed packages do not persist across container restarts.**

Usage:
- `sudo apt-safe update` -- refresh the package index (always run this first)
- `sudo apt-safe install <packages...>` -- install one or more packages
- `sudo apt-safe search <query>` -- search available packages
- `sudo apt-safe list-installed` -- list installed packages

Examples:
- `sudo apt-safe update && sudo apt-safe install ffmpeg`
- `sudo apt-safe update && sudo apt-safe install libxml2-dev libxslt1-dev`

Do NOT use `apt-get` or `apt` directly. The `apt-safe` script is the only permitted way to install packages.

## Constraints

- **Network proxy is active.** All outbound traffic is routed through a Squid proxy that only allows approved domains (listed below). Direct outbound connections are blocked by iptables. If a network request fails unexpectedly, this is likely why.
- **You only have access to the mounted project directory.** The host filesystem is not available beyond the current working directory and `~/.claude`.
- **You are inside Docker.** System-level changes (modifying system config) require root/sudo and won't persist across container restarts unless part of the Dockerfile. Use `sudo apt-safe` to install packages.
- **No SSH keys or git credentials are available.** Git operations to private repositories will fail. Public HTTPS clones work if the domain is in the proxy allowlist.
- **Do not modify proxy or firewall settings.** The proxy config, iptables rules, and related system files are protected and read-only.
