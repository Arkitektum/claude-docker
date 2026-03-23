# Claude Code Docker

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) inside a Docker container with a network firewall. The firewall restricts internet access to only the services Claude needs (Anthropic API, GitHub, package registries), so Claude can work autonomously without risking unintended network access.

There are two ways to use this: the **CLI wrapper** (for terminal usage) and the **VS Code Dev Container** (for VS Code with the Claude Code extension).

## Quick start

### 1. Install Docker

If you don't have Docker installed:

- **Linux**: Follow [Docker's install guide](https://docs.docker.com/engine/install/) for your distro, then run `sudo usermod -aG docker $USER` and log out/in so you can run Docker without `sudo`.
- **macOS**: Install [Docker Desktop](https://docs.docker.com/desktop/install/mac-install/).
- **Windows**: See [Windows setup (WSL2)](#windows-setup-wsl2) below.

Verify Docker is working:

```bash
docker run hello-world
```

### 2. Clone and install

```bash
git clone <this-repo>
cd claudecode-docker
./install.sh
```

If the installer says `~/.local/bin` is not in your PATH, add it to your shell config:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 3. Run

Navigate to any project directory and run:

```bash
claude-docker
```

The first run builds the Docker image, which takes a few minutes. After that, subsequent runs start in seconds.

You'll be prompted to log in to your Claude Code account on first use.

## Windows setup (WSL2)

Claude Code and this project require a Linux environment. On Windows, use WSL2 (Windows Subsystem for Linux):

### Install WSL2

Open PowerShell as Administrator and run:

```powershell
wsl --install
```

This installs Ubuntu by default. Restart your computer when prompted, then open "Ubuntu" from the Start menu to finish setup (you'll create a username and password).

### Install Docker

The easiest option is [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/) with WSL2 backend enabled (this is the default). After installing, open Docker Desktop settings and confirm **"Use the WSL 2 based engine"** is checked.

Alternatively, install Docker directly inside WSL2 without Docker Desktop by following the [Docker Engine install guide for Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

Verify Docker works from your WSL2 terminal:

```bash
docker run hello-world
```

### Install git and jq

Inside your WSL2 terminal:

```bash
sudo apt update && sudo apt install -y git jq
```

### Then follow the normal setup

From here, follow [Clone and install](#2-clone-and-install) above. All commands should be run inside the WSL2 terminal, not PowerShell.

Your Windows files are accessible at `/mnt/c/Users/<your-name>/` inside WSL2, but for best performance, keep your projects inside the WSL2 filesystem (e.g. `~/projects/`).

## CLI usage

```bash
claude-docker                  # Start Claude Code (with firewall)
claude-docker --no-firewall    # Start without firewall
claude-docker --rebuild        # Force rebuild the Docker image (e.g. after updates)
claude-docker bash             # Drop into a bash shell inside the container
```

Any additional arguments are passed through to `claude`. For example:

```bash
claude-docker --allow-dangerously-skip-permissions
```

### How it works

- Your current directory is mounted into the container, so Claude can read and edit your files directly.
- The firewall restricts outbound network access to only approved services.
- `~/.claude` and `~/.claude.json` are mounted into the container so your session, settings, and API keys persist.
- Files are mounted read-write. Claude can modify files in your current directory. Use version control.

## VS Code Dev Container

### Setup

1. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) in VS Code
2. Install the dev container into your project:

```bash
./install-devcontainer.sh /path/to/your/project
```

3. Open your project in VS Code
4. When prompted "Reopen in Container", click yes -- or run **Dev Containers: Reopen in Container** from the command palette (`Ctrl+Shift+P`)

The script refuses to run if `.devcontainer/` already exists in the target project.

The container will build, then the firewall will initialize automatically. The Claude Code extension is pre-installed.

### Notes

- **The firewall runs on container start.** If it fails, the `postStartCommand` will error and you'll see a notification.
- **Your workspace is mounted at `/workspace`.**
- **Your Claude config is mounted from the host.** `~/.claude` and `~/.claude.json` are bind-mounted so your session and settings persist across rebuilds.
- **The container user matches your host user.** Paths and file ownership are consistent between host and container.

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

- **First build is slow.** The image includes many language runtimes (~3-4 GB). Subsequent runs reuse the cached image.
- **The firewall resolves domain IPs at container start.** If a service changes its IPs while the container is running, connections to it may break. Restart the container to re-resolve.
- **`--no-firewall` disables all network restrictions.** Use this if you need access to services not on the allow list, but be aware there is no network sandbox.
- **The container runs with `NET_ADMIN` and `NET_RAW` capabilities** when the firewall is active (required for iptables). These are dropped when using `--no-firewall`.
- **IPv6 is not firewalled.** The current rules only cover IPv4. On most Docker setups this is fine since Docker defaults to IPv4 bridge networking.
