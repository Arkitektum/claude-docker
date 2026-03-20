#!/bin/bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

echo "Network tests"
echo "============="

# Blocked sites
assert_fail "example.com is blocked" \
    curl --connect-timeout 5 -s https://example.com

assert_fail "wikipedia.org is blocked" \
    curl --connect-timeout 5 -s https://wikipedia.org

# Allowed sites
assert_pass "api.github.com is allowed" \
    curl --connect-timeout 5 -sf https://api.github.com/zen

assert_pass "api.anthropic.com is reachable" \
    curl --connect-timeout 5 -s -o /dev/null -w "%{http_code}" https://api.anthropic.com

# Package installs
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
