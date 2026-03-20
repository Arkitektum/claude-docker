# Claude Code Docker

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) inside a Docker container with a network firewall. The firewall restricts internet access to only the services Claude needs (Anthropic API, GitHub, package registries), so Claude can work autonomously without risking unintended network access.

There are two ways to use this: the **CLI wrapper** (for terminal usage) and the **VS Code Dev Container** (for VS Code with the Claude Code extension).

## Prerequisites

- **Docker** installed and running ([install guide](https://docs.docker.com/get-docker/))
- A **Claude Code account** -- you'll be prompted to log in on first run
- **Linux or macOS** host (Windows users: use WSL2)

## Option 1: CLI

### Install

```bash
git clone <this-repo>
cd claudecode-docker
./install.sh
```

This copies the Docker build files to `~/.local/share/claude-docker/` and installs the `claude-docker` command to `~/.local/bin/`. If `~/.local/bin` is not in your `PATH`, the installer will tell you how to add it.

### Usage

Navigate to any project directory and run:

```bash
claude-docker
```

This builds the Docker image (first run takes a few minutes), sets up the firewall, and starts Claude Code. Your current directory is mounted into the container, so Claude can read and edit your files directly.

Because the firewall prevents Claude from reaching anything outside the allowed list, permission prompts are automatically skipped (`--dangerously-skip-permissions`). This is the whole point -- the firewall is the safety net instead of manual approval.

#### Commands

```bash
claude-docker                  # Start Claude Code (with firewall)
claude-docker --no-firewall    # Start without firewall (permission prompts enabled)
claude-docker --rebuild        # Force rebuild the Docker image (e.g. after updates)
claude-docker bash             # Drop into a bash shell inside the container
```

### Important notes

- **First build is slow.** The image includes Node.js, Python, Go, Rust, .NET, and Playwright. Subsequent runs reuse the cached image and start in seconds.
- **Your Claude config is shared.** `~/.claude` and `~/.claude.json` are mounted into the container so your session, settings, and API keys persist.
- **Files are mounted read-write.** Claude can modify files in your current directory. This is intentional -- it's how Claude Code works. Use version control.

## Option 2: VS Code Dev Container

### Setup

1. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) in VS Code
2. Copy the `.devcontainer/` folder into the root of your project
3. Open your project in VS Code
4. When prompted "Reopen in Container", click yes -- or run the command **Dev Containers: Reopen in Container** from the command palette (`Ctrl+Shift+P`)

The container will build, then the firewall will initialize automatically. The Claude Code extension is pre-installed and configured to skip permission prompts (since the firewall is active).

### Important notes

- **The firewall runs on container start.** If it fails, the `postStartCommand` will error and you'll see a notification. Check the terminal output for details.
- **Your workspace is mounted at `/workspace`.** This is standard for dev containers.
- **Your Claude config is mounted from the host.** `~/.claude` and `~/.claude.json` are bind-mounted into the container, so your session and settings persist across rebuilds. These are created automatically on the host if they don't exist yet.
- **The container user matches your host user.** The devcontainer passes your local `$USER` to the Dockerfile so paths and file ownership are consistent between host and container.

## What the firewall allows

All other outbound traffic is blocked. The firewall is verified on every start by confirming that `example.com` is unreachable and `api.github.com` is reachable.

| Service | Domains | Why |
|---|---|---|
| Anthropic | `api.anthropic.com`, `statsig.anthropic.com`, `statsig.com`, `sentry.io` | Claude Code API and telemetry |
| GitHub | All IPs from `api.github.com/meta`, `objects.githubusercontent.com` | Git operations, downloading releases |
| npm | `registry.npmjs.org` | Node.js packages |
| PyPI | `pypi.org`, `files.pythonhosted.org`, `astral.sh` | Python packages |
| Crates.io | `crates.io`, `index.crates.io`, `static.crates.io` | Rust packages |
| Rust toolchain | `static.rust-lang.org`, `sh.rustup.rs` | Rust installer |
| Go | `proxy.golang.org`, `sum.golang.org`, `storage.googleapis.com` | Go modules |
| NuGet | `api.nuget.org` | .NET packages |
| VS Code | `marketplace.visualstudio.com`, `vscode.blob.core.windows.net`, `update.code.visualstudio.com` | Extensions and updates (dev container mode) |
| DNS | Port 53 (UDP) | Name resolution |

## What's in the container

The image is based on Ubuntu 24.04 and includes:

- Node.js 24 (via nvm)
- Python 3 with [uv](https://docs.astral.sh/uv/)
- Go 1.25
- Rust (via rustup)
- .NET (latest SDK)
- Playwright with Chromium
- Common tools: git, ripgrep, jq, tree, postgresql-client
- Terraform MCP server

## Caveats

- **The firewall resolves domain IPs at container start.** If a service changes its IPs while the container is running, connections to it may break. Restart the container to re-resolve.
- **`--no-firewall` disables all network restrictions.** In this mode, Claude Code runs with normal permission prompts instead of auto-skip. Use this if you need access to services not on the allow list, but be aware there is no network sandbox.
- **The container runs with `NET_ADMIN` and `NET_RAW` capabilities** when the firewall is active (required for iptables). These are dropped when using `--no-firewall`.
- **IPv6 is not firewalled.** The current rules only cover IPv4. On most Docker setups this is fine since Docker defaults to IPv4 bridge networking, but be aware of this if you enable IPv6 in Docker.
- **The image is large** (~3-4 GB) due to all the included language runtimes. This is a one-time cost.
