# Changelog

## 2026-05-28

- Add `CLAUDE_DOCKER_CC_VERSION` env var to pin a specific Claude Code release (`stable`, `latest`, or `X.Y.Z`) at image build time. Forwarded to the Dockerfile as the `CLAUDE_CODE_VERSION` build arg.
- Add `.deps.dev` to the proxy allowlist.

## 2026-05-13

- Add `CLAUDE_DOCKER_CUSTOMIZE` env var pointing to a shell script that is copied into the build context and run as `root` in the final layer of the Dockerfile, letting users install their own tooling without forking the image.
- Add `CLAUDE_DOCKER_ALLOW_DOMAINS` env var (whitespace- or comma-separated) for appending domains to the proxy allowlist at container start. Squid's domain list now lives in `allowed_domains.txt` rather than inline in `squid.conf`.
- Fix missing timezone info in the Docker image (`tzdata` package) so container time matches the host (commit 0de7862).
