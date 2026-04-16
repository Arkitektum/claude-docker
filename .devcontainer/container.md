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

## Network

**Internet access** is restricted by a Squid proxy and iptables firewall:
- HTTP/HTTPS traffic goes through a Squid proxy that only allows approved domains (listed below).
- Direct outbound connections are blocked by iptables.
- If a request fails unexpectedly, the domain is likely not in the proxy allowlist.

**`localhost` reaches the host machine**, not this container:
- `localhost` resolves to the user's host machine via `/etc/hosts`.
- `localhost:5173`, `localhost:8080`, etc. connect to services the user is running outside Docker.
- Use `localhost` (the hostname), not `127.0.0.1`. The raw IP `127.0.0.1` still points to the container.
- `curl` hardcodes `localhost` to `127.0.0.1` and bypasses `/etc/hosts`. When testing with curl, use the host IP directly: `curl http://$(getent hosts localhost | awk '{print $1}'):PORT`

**Container-internal services** use `container.local`:
- Bind to `container.local` (resolves to `127.0.0.2`) for servers started inside this container.
- Example: `vite --host container.local`, `python -m http.server --bind 127.0.0.2 8000`
- These are only reachable from inside the container, not from the user's browser.
- If you plan to run a service that the user needs to access in their browser, ask them to run it on their machine instead.

## Constraints

- **You only have access to the mounted project directory.** The host filesystem is not available beyond the current working directory and `~/.claude`.
- **You are inside Docker.** System-level changes (modifying system config) require root/sudo and won't persist across container restarts unless part of the Dockerfile. Use `sudo apt-safe` to install packages.
- **No SSH keys or git credentials are available.** Git operations to private repositories will fail. Public HTTPS clones work if the domain is in the proxy allowlist.
- **Do not modify proxy or firewall settings.** The proxy config, iptables rules, and related system files are protected and read-only.
