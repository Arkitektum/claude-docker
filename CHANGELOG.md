# Changelog

## 2026-08-28

- Container instructions reach Claude as the managed-policy `CLAUDE.md` at `/etc/claude-code/CLAUDE.md`, which subagents load too. The image ships it as a copy of `container.md`, which covers the container regardless of the firewall. With the firewall active the entrypoint runs `write-container-md` on each start, appending the proxy's package-management and network rules and the live allowlist. `--no-firewall` keeps the copy: nothing to append, and no route to root to append it with.
- Container instructions cover `CLAUDE_DOCKER_CUSTOMIZE`, so Claude can guide users through making a tool permanent instead of only reaching for `apt-safe`. Claude proposes the script contents but never writes the file: it runs as root before the proxy and firewall exist, so it stays on a host path outside the container's mounts.
- The mandatory Arkitektum plugin is checked for enablement at container start, and enabled when the flag is missing. Installing records enablement, but `claude plugin update` leaves a disabled plugin disabled, so the install/update path alone could not guarantee it was active.

## 2026-08-17

- Faster container start: the plugin refresh now probes the marketplace repo with a single `git ls-remote` and compares remote HEAD against the installed plugin's commit SHA. The slow `claude plugin` CLI commands only run on first install or when the marketplace actually changed. The entrypoint stays silent when the plugin is current and prints a status line when installing or updating.

## 2026-08-12

- Fix image build on arm64 (Apple Silicon). Two x86-only assumptions broke it: the apt sources rewrite pointed arm64 builds at `ftp.uninett.no`, which does not mirror `ports.ubuntu.com` (making `apt-get update` 404 and the package install fail), and the Go tarball was hardcoded to `linux-amd64` (installing an unrunnable `go` binary). Both now key off `dpkg --print-architecture`; amd64 builds are unchanged.

## 2026-06-22

- The mandatory Arkitektum marketplace plugin is now installed and refreshed to the latest version automatically at container start, instead of being baked into the image at build time. Requires `github.com` (already in the proxy allowlist).

## 2026-05-28

- Add `CLAUDE_DOCKER_CC_VERSION` env var to pin a specific Claude Code release (`stable`, `latest`, or `X.Y.Z`) at image build time. Forwarded to the Dockerfile as the `CLAUDE_CODE_VERSION` build arg.
- Add `.deps.dev` to the proxy allowlist.

## 2026-05-13

- Add `CLAUDE_DOCKER_CUSTOMIZE` env var pointing to a shell script that is copied into the build context and run as `root` in the final layer of the Dockerfile, letting users install their own tooling without forking the image.
- Add `CLAUDE_DOCKER_ALLOW_DOMAINS` env var (whitespace- or comma-separated) for appending domains to the proxy allowlist at container start. Squid's domain list now lives in `allowed_domains.txt` rather than inline in `squid.conf`.
- Fix missing timezone info in the Docker image (`tzdata` package) so container time matches the host (commit 0de7862).
