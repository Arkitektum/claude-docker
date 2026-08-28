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

## Permanent tooling (image customization)

Tools needed on every run can be baked into the image by a setup script that runs as `root` in the last build layer.

Do not volunteer this procedure. When you install something with `apt-safe` that the user will likely need again, say in one sentence that it can be made permanent and that you can help, then get on with the task. Give the steps below only when asked.

The script is the user's, not yours. It runs before the proxy and firewall exist, so it can undo every restriction you operate under. Propose the contents in the conversation and let the user create the file themselves. Never write or edit it, and never place it under `~/.claude`, which is shared with the host. You cannot rebuild the image either; that runs from the user's own terminal.

Assume the user does not know Linux. Give exact text to copy and say where to run it.

**1. Show the script and explain each line.**

```bash
#!/bin/bash
set -e
apt-get update && apt-get install -y --no-install-recommends fzf
su - "$LOCAL_USER" -c 'uv tool install httpie'  # tools that install into the home directory
```

Use `apt-get` here, not `apt-safe`, since the script is already root. The `su -` form is required for anything landing in a home directory, otherwise it goes to root's home and is invisible at runtime. No proxy exists during the build, so download sites blocked at runtime work here. A non-zero exit fails the build and leaves the user with no container, so keep `set -e` and confirm package names with `sudo apt-safe install` first.

**2. The user creates the file**, pasting the block whole:

```bash
mkdir -p ~/.config/claude-docker
cat > ~/.config/claude-docker/setup.sh <<'SETUP'
<the script from step 1>
SETUP
```

**3. The user points `claude-docker` at it** with the line for their computer, then closes that terminal and opens a new one:

```bash
echo 'export CLAUDE_DOCKER_CUSTOMIZE=~/.config/claude-docker/setup.sh' >> ~/.zshrc   # Mac
echo 'export CLAUDE_DOCKER_CUSTOMIZE=~/.config/claude-docker/setup.sh' >> ~/.bashrc  # Linux
```

This tells `claude-docker` where the script is on every start, and only applies to terminal windows opened afterwards. They then run `claude-docker` in the project folder; the first start is slow while the image rebuilds (no flag needed, changed contents trigger it). Afterwards, confirm the tool is really there with `which`. Running `claude-docker` from a terminal missing that line rebuilds without any of these tools, which is why it goes in the profile file.

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
