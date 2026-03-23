# Claude Code Docker

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) inside a Docker container with a network proxy. A Squid forward proxy restricts internet access to only the services Claude needs (Anthropic API, GitHub, package registries), so Claude can work autonomously without risking unintended network access.

## Choose your setup

There are three ways to use this depending on your operating system and preferred workflow:

| Setup | OS | Best for |
|---|---|---|
| [Terminal (CLI)](#option-1-terminal-cli) | Linux or macOS | Developers who prefer the command line |
| [VS Code Dev Container](#option-2-vs-code-dev-container) | Linux, macOS, or Windows | Developers who use VS Code |
| [Terminal via WSL2](#option-3-terminal-on-windows-via-wsl2) | Windows | Developers who prefer the command line on Windows |

**Windows users:** The simplest path is [Option 2 (VS Code Dev Container)](#option-2-vs-code-dev-container) -- it works directly on Windows with Docker Desktop. If you prefer the terminal, you'll need to set up WSL2 first ([Option 3](#option-3-terminal-on-windows-via-wsl2)).

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

**Works on:** Linux, macOS, Windows

This sets up a dev container in your project. VS Code runs inside the container with the Claude Code extension pre-installed. No terminal setup needed -- everything is handled by VS Code.

### Prerequisites

- **Docker Desktop** -- [Windows](https://docs.docker.com/desktop/install/windows-install/), [macOS](https://docs.docker.com/desktop/install/mac-install/), or [Linux](https://docs.docker.com/engine/install/)
- **VS Code** with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- **git** -- [Windows download](https://git-scm.com/download/win) (includes Git Bash), pre-installed on macOS/Linux

Verify Docker is working by opening a terminal (PowerShell on Windows, Terminal on macOS/Linux) and running:

```
docker run hello-world
```

### Install

Clone this repo and run the install script, passing your project directory:

**Linux/macOS:**
```bash
git clone <this-repo>
cd claudecode-docker
./install-devcontainer.sh /path/to/your/project
```

**Windows (PowerShell):**
```powershell
git clone <this-repo>
cd claudecode-docker
bash install-devcontainer.sh C:\path\to\your\project
```

> On Windows without Git Bash, you can manually copy the `.devcontainer/` folder from this repo into your project directory.

### Open in container

1. Open your project in VS Code
2. VS Code will detect the `.devcontainer/` folder and show a notification: **"Reopen in Container"** -- click it
3. Alternatively, press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS) and select **Dev Containers: Reopen in Container**

The first build takes a few minutes. After that, reopening is fast. The proxy and firewall initialize automatically when the container starts.

### Notes

- **Your workspace is mounted at `/workspace`** inside the container.
- **Your Claude config is mounted from your home directory.** `~/.claude` and `~/.claude.json` are shared between host and container, so your session and settings persist across rebuilds.
- **On Windows**, the container user defaults to `claude`. On Linux/macOS, it matches your host user for consistent file ownership.

---

## Option 3: Terminal on Windows (via WSL2)

**Works on:** Windows 10/11

If you prefer using Claude Code from the command line on Windows, you need WSL2 (Windows Subsystem for Linux). This gives you a Linux terminal inside Windows where the CLI works just like on Linux.

> If you just want VS Code, skip this and use [Option 2](#option-2-vs-code-dev-container) instead -- it's simpler.

### What is WSL2?

WSL2 lets you run a real Linux environment inside Windows. It's built into Windows 10 and 11 -- you just need to turn it on. You'll get an Ubuntu terminal that works alongside your normal Windows apps.

### Install WSL2

Open **PowerShell as Administrator** (right-click PowerShell in the Start menu, select "Run as administrator") and run:

```powershell
wsl --install
```

Restart your computer when prompted. After restarting, open **Ubuntu** from the Start menu. You'll be asked to create a username and password -- this is your Linux account inside WSL2.

### Install Docker

Install [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/). After installing, open Docker Desktop settings and confirm **"Use the WSL 2 based engine"** is checked (it should be by default).

Verify Docker works from your Ubuntu terminal:

```bash
docker run hello-world
```

### Install git and jq

In your Ubuntu terminal:

```bash
sudo apt update && sudo apt install -y git jq
```

### Install and run

From here, follow the same steps as [Option 1](#install). All commands should be run in the **Ubuntu terminal**, not PowerShell.

```bash
git clone <this-repo>
cd claudecode-docker
./install.sh
```

Then navigate to your project and run `claude-docker`.

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
- **`--no-firewall` disables all network restrictions** (CLI only). Use this if you need access to services not on the allow list, but be aware there is no network sandbox.
- **IPv6 is not firewalled.** The current rules only cover IPv4. On most Docker setups this is fine since Docker defaults to IPv4 bridge networking.
