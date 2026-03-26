# Claude Code Docker

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) inside a Docker container with a network proxy. A Squid forward proxy restricts internet access to only the services Claude needs (Anthropic API, GitHub, package registries), so Claude can work autonomously without risking unintended network access.

## Choose your setup

| Setup | OS | Best for |
|---|---|---|
| [Terminal (CLI)](#option-1-terminal-cli) | Linux, macOS, or Windows (WSL2) | Developers who prefer the command line |
| [VS Code Dev Container](#option-2-vs-code-dev-container) | Linux, macOS, or Windows (WSL2) | Developers who use VS Code |

**Windows users:** WSL2 is required. See [WSL2 setup](#windows-wsl2-setup) below before proceeding.

---

## Option 1: Terminal (CLI)

**Works on:** Linux, macOS

This installs a `claude-docker` command that runs Claude Code inside a container from any terminal.

### Prerequisites

- **Docker** -- [Linux install guide](https://docs.docker.com/engine/install/) or [macOS Docker Desktop](https://docs.docker.com/desktop/install/mac-install/)
- **git** and **jq** -- usually pre-installed on macOS; on Linux: `sudo apt install -y git jq`

After installing Docker on Linux, run `sudo usermod -aG docker $USER` and log out/in so you can run Docker without `sudo`.

Verify Docker is working:

```bash
docker run hello-world
```

### Install

```bash
git clone <this-repo>
cd claudecode-docker
./install.sh
```

If the installer says `~/.local/bin` is not in your PATH, add it:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Run

Navigate to any project directory and run:

```bash
claude-docker
```

The first run builds the Docker image, which takes a few minutes. After that, subsequent runs start in seconds. You'll be prompted to log in to your Claude Code account on first use.

### CLI options

```bash
claude-docker                  # Start Claude Code (with proxy)
claude-docker --no-firewall    # Start without proxy/firewall
claude-docker --rebuild        # Force rebuild the Docker image
claude-docker bash             # Drop into a bash shell inside the container
```

Any additional arguments are passed through to `claude`. For example:

```bash
claude-docker --allow-dangerously-skip-permissions
```

### How it works

- Your current directory is mounted into the container, so Claude can read and edit your files directly.
- A Squid proxy filters outbound traffic by domain name, only allowing approved services.
- Direct outbound connections from Claude are blocked by iptables; all traffic must go through the proxy.
- Container instructions are injected into Claude's context on every session start via a managed hook, so Claude is aware of the proxy restrictions.
- `~/.claude` and `~/.claude.json` are mounted so your session, settings, and API keys persist.
- Files are mounted read-write. Claude can modify files in your current directory. Use version control.

---

## Option 2: VS Code Dev Container

**Works on:** Linux, macOS, Windows (WSL2)

This sets up a dev container in your project. VS Code runs inside the container with the Claude Code extension pre-installed. No terminal setup needed -- everything is handled by VS Code.

### Prerequisites

- **Docker Desktop** -- [macOS](https://docs.docker.com/desktop/install/mac-install/) or [Linux](https://docs.docker.com/engine/install/). Windows users: install [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/) and enable the WSL 2 backend.
- **VS Code** with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- **git** -- pre-installed on macOS/Linux; on WSL2: `sudo apt install -y git`

Verify Docker is working:

```bash
docker run hello-world
```

### Install

Clone this repo and run the install script, passing your project directory:

```bash
git clone <this-repo>
cd claudecode-docker
./install-devcontainer.sh /path/to/your/project
```

### Open in container

1. Open your project in VS Code
2. VS Code will detect the `.devcontainer/` folder and show a notification: **"Reopen in Container"** -- click it
3. Alternatively, press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS) and select **Dev Containers: Reopen in Container**

The first build takes a few minutes. After that, reopening is fast. The proxy and firewall initialize automatically when the container starts.

### Notes

- **Your workspace is mounted at `/workspace`** inside the container.
- **Your Claude config is mounted from your home directory.** `~/.claude` and `~/.claude.json` are shared between host and container, so your session and settings persist across rebuilds.

---

## Windows: WSL2 setup

WSL2 (Windows Subsystem for Linux) is required for running this project on Windows. It gives you a real Linux environment inside Windows 10/11.

### Install WSL2

Open **PowerShell as Administrator** and run:

```powershell
wsl --install
```

Restart your computer when prompted. After restarting, open **Ubuntu** from the Start menu and create a username and password.

### Install Docker

Install [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/). In Docker Desktop settings, confirm **"Use the WSL 2 based engine"** is checked (default).

Verify Docker works from your Ubuntu terminal:

```bash
docker run hello-world
```

### Install dependencies

```bash
sudo apt update && sudo apt install -y git jq
```

### Next steps

Run all commands from your **Ubuntu terminal**, not PowerShell. Follow [Option 1](#option-1-terminal-cli) or [Option 2](#option-2-vs-code-dev-container) above.

> Your Windows files are accessible at `/mnt/c/Users/<your-name>/` inside WSL2, but for best performance, keep your projects inside the WSL2 filesystem (e.g. `~/projects/`).

---

## How the proxy works

A Squid forward proxy runs inside the container. All HTTP/HTTPS requests from Claude go through the proxy, which only allows approved domains. Direct outbound connections are blocked by iptables using `owner` matching -- the proxy process runs as a different user than Claude, so iptables can distinguish their traffic.

On every container start, the init script verifies that:
1. Allowed domains are reachable through the proxy
2. Blocked domains are rejected by the proxy
3. Direct connections (bypassing the proxy) are blocked by iptables

Claude is informed about the container environment via a managed SessionStart hook that injects `/etc/claude-code/container.md` into Claude's context. This file is generated at build time and includes the proxy allowlist.

### Allowed domains

| Service | Domains | Why |
|---|---|---|
| Anthropic | `.anthropic.com`, `.statsig.com`, `.sentry.io` | Claude Code API and telemetry |
| GitHub | `.github.com`, `.githubusercontent.com` | Git operations, downloading releases |
| npm | `.npmjs.org` | Node.js packages |
| PyPI | `.pypi.org`, `.pythonhosted.org`, `.astral.sh` | Python packages |
| Crates.io | `.crates.io` | Rust packages |
| Rust toolchain | `.rust-lang.org`, `.rustup.rs` | Rust installer |
| Go | `.golang.org`, `storage.googleapis.com` | Go modules |
| NuGet | `.nuget.org` | .NET packages |
| VS Code | `.visualstudio.com`, `vscode.blob.core.windows.net` | Extensions and updates (dev container mode) |
| Ubuntu APT | `.ubuntu.com` | System package installation via `apt-safe` |
| MCP servers | `mcp.exa.ai`, `mcp.context7.com`, `instances-mcp.vantage.sh` | Remote MCP services |

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
- `apt-safe` CLI for safe package installation

## Caveats

- **First build is slow.** The image includes many language runtimes (~3-4 GB). Subsequent runs reuse the cached image.
- **`--no-firewall` disables all network restrictions** (CLI only). Use this if you need access to services not on the allow list, but be aware there is no network sandbox.
- **IPv6 is not firewalled.** The current rules only cover IPv4. On most Docker setups this is fine since Docker defaults to IPv4 bridge networking.
