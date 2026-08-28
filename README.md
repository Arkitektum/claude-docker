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

- **Docker** -- If you have WSL2 and Docker Desktop, this is already covered. [Linux install guide](https://docs.docker.com/engine/install/) or [macOS Docker Desktop](https://docs.docker.com/desktop/install/mac-install/)
- **git** and **jq** -- usually pre-installed on macOS; on Linux: `sudo apt install -y git jq`

The image builds natively on both x86_64 and arm64 (Apple Silicon) -- no emulation or `--platform` flag needed.

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

The first run builds the Docker image, which takes a few minutes. After that, subsequent runs start in seconds. You'll be prompted to log in to your Claude Code account on first use -- see [Logging in](#logging-in) below.

### Logging in

OAuth login has to run with `--no-firewall`:

```bash
claude-docker --no-firewall
# /login inside Claude, complete the browser flow, exit
```

Then start normally again (`claude-docker`). Tokens are stored in `~/.claude/.claude.json` and persist across restarts.

**Why:** Claude Code's login opens a browser on your host that calls back to a local server. That callback needs the container to share the host's network namespace (`--no-firewall` uses `--net=host`), and it also needs `localhost` to mean "this container's loopback" rather than the remapped "host machine" used in normal mode. Outside of login, `localhost` in the container points at your host machine so MCP servers running locally work with the same config you'd use outside Docker.

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

### Allowing extra domains through the proxy

Set `CLAUDE_DOCKER_ALLOW_DOMAINS` to a whitespace- or comma-separated list of domains. They are appended to the proxy allowlist when the container starts (no image rebuild required). Use a leading dot to match all subdomains.

```bash
export CLAUDE_DOCKER_ALLOW_DOMAINS=".internal.example.com api.partner.io"
claude-docker
```

Domains added this way are picked up by the SessionStart hook (it reads the live allowlist), so Claude sees them in the injected environment doc without a rebuild.

### Adding your own tooling to the image

Set `CLAUDE_DOCKER_CUSTOMIZE` to the path of a shell script. The script is copied into the build context and runs as `root` in the final layer of the Dockerfile, so it can install apt packages, write to `/etc/`, drop binaries in `/usr/local/bin`, etc. Build runs without the proxy, so direct network access is available.

```bash
export CLAUDE_DOCKER_CUSTOMIZE=~/.config/claude-docker/setup.sh
claude-docker
```

Example `setup.sh`:

```bash
#!/bin/bash
set -e
apt-get update && apt-get install -y --no-install-recommends fzf
# Install something for the unprivileged user:
su - "$LOCAL_USER" -c 'uv tool install httpie'
```

The image rebuilds automatically when the script's contents change. Unset the variable (or `unset CLAUDE_DOCKER_CUSTOMIZE`) to go back to the stock image on the next run.

### Pinning the Claude Code version

Set `CLAUDE_DOCKER_CC_VERSION` to `stable`, `latest`, or a specific version like `1.2.3` to control which Claude Code release is baked into the image. Defaults to `latest` when unset.

```bash
export CLAUDE_DOCKER_CC_VERSION=1.2.3
claude-docker --rebuild
```

Changing the value invalidates the install layer, so a rebuild is required for the new version to take effect.

### Committing as yourself

By default the container has no git identity, so commits the agent makes are attributed to a generic placeholder. Set `CLAUDE_DOCKER_GIT_IDENTITY` to any non-empty value to read your host `user.name` and `user.email` (via `git config`) and pass them in as `GIT_AUTHOR_*`/`GIT_COMMITTER_*`, so commits are attributed to you.

```bash
export CLAUDE_DOCKER_GIT_IDENTITY=1
claude-docker
```

This only forwards name and email, not your full `.gitconfig` (no credential helpers, signing keys, or aliases). No rebuild required.

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

- **Docker Desktop** -- [macOS](https://docs.docker.com/desktop/install/mac-install/) or [Linux](https://docs.docker.com/engine/install/). Windows users: install [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/) and enable the WSL 2 backend.
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

WSL2 (Windows Subsystem for Linux) is required for running this project on Windows.

1. Install WSL2 by following the [official Microsoft documentation](https://learn.microsoft.com/en-us/windows/wsl/install).
2. Install [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/) and enable the WSL 2 backend in its settings.

Once set up, run all commands from your **Ubuntu terminal**, not PowerShell. Follow [Option 1](#option-1-terminal-cli) or [Option 2](#option-2-vs-code-dev-container) above.

> For best performance, keep your projects inside the WSL2 filesystem (e.g. `~/projects/`) rather than `/mnt/c/`.

> **Line endings:** Git on Windows defaults to rewriting line endings to CRLF on checkout (`core.autocrlf=true`). If you use a Windows Git client (GitKraken, Visual Studio, Windows Git Bash) and access the same checkout from WSL2, shell scripts and tools inside the container will break due to unexpected `\r` characters. The proper fix is to add a `.gitattributes` file to each repo:
>
> ```
> * text=auto eol=lf
> ```
>
> This forces LF endings on checkout for everyone, regardless of local git config. Modern Visual Studio and GitKraken both handle LF fine on Windows. Without this, your only options are cloning from within WSL2 (separate checkout from your Windows tools) or setting `core.autocrlf=false` globally in your Windows Git config.

---

## How the proxy works

A Squid forward proxy runs inside the container. All HTTP/HTTPS requests from Claude go through the proxy, which only allows approved domains. Direct outbound connections are blocked by iptables using `owner` matching -- the proxy process runs as a different user than Claude, so iptables can distinguish their traffic.

On every container start, the init script verifies that:
1. Allowed domains are reachable through the proxy
2. Blocked domains are rejected by the proxy
3. Direct connections (bypassing the proxy) are blocked by iptables

Claude is informed about the container environment through the managed-policy `CLAUDE.md` at `/etc/claude-code/CLAUDE.md`, which every session and subagent loads. The image ships it as a copy of `/etc/claude-code/container.md`, which describes what holds regardless of the firewall. With the firewall active, the entrypoint calls `write-container-md` on each start to append the proxy's package-management and network rules plus the live allowlist. `--no-firewall` keeps the copy: it has no route to root to rewrite the file with, and nothing to add.

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
| NuGet | `.nuget.org`, `nugetserver-api.ft.dibk.no` | .NET packages (incl. DIBK feed) |
| VS Code | `.visualstudio.com`, `vscode.blob.core.windows.net` | Extensions and updates (dev container mode) |
| Ubuntu APT | `.ubuntu.com`, `ftp.uninett.no` | System package installation via `apt-safe` |
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

## Installing packages (for Claude)

The container includes `apt-safe`, a hardened wrapper around `apt` that the agent can use to install system packages during a session. Installed packages do not persist across container restarts.

## Caveats

- **First build is slow.** The image includes many language runtimes (~3-4 GB). Subsequent runs reuse the cached image.
- **`--no-firewall` disables all network restrictions** (CLI only). Use this if you need access to services not on the allow list, but be aware there is no network sandbox.

