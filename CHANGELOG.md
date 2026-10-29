# Changelog

## 2026-10-29

- Plugins update automatically in the container. The image sets `FORCE_AUTOUPDATE_PLUGINS=1`, because `DISABLE_AUTOUPDATER` and `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` also stopped plugin updates, which left even `claude-plugins-official` frozen. The entrypoint sets `autoUpdate: true` for `arkitektum-marketplace` in `~/.claude/settings.json` when the key is missing, and an explicit `false` stays. A managed settings file in the image can't carry the setting: server-managed settings from claude.ai take precedence, and Claude Code then ignores plugin keys in the file.
- `mattpocock-skills` and `arkitektum-security` from `arkitektum-marketplace`, and `superpowers` from `claude-plugins-official`, are installed at container start when missing. Unlike the mandatory plugin, they are not enabled again, so turning one off in `/plugin` sticks.
- The image sets `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1`. Claude Code clones GitHub `owner/repo` plugin sources over SSH first, which the firewall blocks, and a `git-subdir` source then failed to install instead of falling back to HTTPS.

## 2026-09-07

- `--add-dir` now bind-mounts each directory into the container at its host path, instead of being forwarded to `claude` as a path that does not exist on the inside. The flag keeps its upstream meaning and variadic form, so nothing new to learn. Paths are resolved before the build so a bad one fails fast; a path missing on the host is forwarded unmounted (for directories that only exist in the image), and `/` and the user's home are refused because on Linux the latter would bury the container's own home and `~/.claude` with it.

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
