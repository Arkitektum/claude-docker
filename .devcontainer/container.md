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

## Playwright (browser automation)

Playwright with a matching headless **Chromium** is preinstalled. Use the CLI directly:
- `playwright screenshot <url> out.png`
- `playwright pdf <url> out.pdf`
- `playwright codegen <url>`

For Python scripts, `import playwright` does not work under plain `python3`. Run with `uv run`, pinning the version shown by `playwright --version`:

```bash
uv run --with playwright==1.60.0 python my_script.py
```

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    page = p.chromium.launch().new_page()
    page.goto("http://container.local:8099/")
    page.screenshot(path="shot.png")
```

For Node, install the matching version (`npm install playwright@1.60.0`) and it reuses the bundled Chromium instead of downloading. A mismatched version pulls a different Chromium build, which fails (browser CDN is not in the allowlist).

## Constraints

- **You only have access to the mounted project directory.** The host filesystem is not available beyond the current working directory and `~/.claude`.
- **You are inside Docker.** System-level changes (modifying system config) require root/sudo and won't persist across container restarts unless part of the Dockerfile. Use `sudo apt-safe` to install packages.
- **No SSH keys or git credentials are available.** Git operations to private repositories will fail. Public HTTPS clones work for reachable domains (see Network below).
