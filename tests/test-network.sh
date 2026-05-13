#!/bin/bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

echo "Network tests"
echo "============="

PROXY="http://127.0.0.1:3128"

# Direct connections blocked by iptables (even to allowed domains)
assert_fail "direct connection to github is blocked" \
    curl --noproxy "*" --connect-timeout 3 -sf https://api.github.com/zen

assert_fail "direct connection to example.com is blocked" \
    curl --noproxy "*" --connect-timeout 3 -sf https://example.com

# Direct IPv6 connections blocked
assert_fail "direct IPv6 connection is blocked" \
    curl -6 --noproxy "*" --connect-timeout 3 -sf https://api.github.com/zen

# Proxy blocks unauthorized domains
assert_fail "example.com blocked through proxy" \
    curl -x "$PROXY" --connect-timeout 5 -sf https://example.com

assert_fail "wikipedia.org blocked through proxy" \
    curl -x "$PROXY" --connect-timeout 5 -sf https://wikipedia.org

# Proxy allows authorized domains
assert_pass "api.github.com allowed through proxy" \
    curl -x "$PROXY" --connect-timeout 5 -sf https://api.github.com/zen

assert_pass "api.anthropic.com reachable through proxy" \
    curl -x "$PROXY" --connect-timeout 5 -s -o /dev/null -w "%{http_code}" https://api.anthropic.com

# CLAUDE_DOCKER_ALLOW_DOMAINS appended google.com to the allowlist at startup
assert_pass "google.com allowed via CLAUDE_DOCKER_ALLOW_DOMAINS" \
    curl -x "$PROXY" --connect-timeout 5 -sf -o /dev/null https://www.google.com

# Package installs (use proxy via env vars set in Dockerfile)
assert_pass "npm install (lodash)" \
    sh -c "cd $DIR/fixtures/node && rm -rf node_modules package-lock.json && npm install --no-audit --no-fund 2>&1"

assert_pass "uv pip install (requests)" \
    sh -c "cd $DIR/fixtures/python && rm -rf .venv && uv venv .venv && uv pip install -p .venv -r requirements.txt 2>&1"

assert_pass "cargo fetch (serde)" \
    sh -c "cd $DIR/fixtures/rust && cargo fetch 2>&1"

assert_pass "go mod download (google/uuid)" \
    sh -c "cd $DIR/fixtures/go && go mod download 2>&1"

assert_pass "dotnet restore (Newtonsoft.Json)" \
    sh -c "cd $DIR/fixtures/dotnet && dotnet restore 2>&1"

test_summary
