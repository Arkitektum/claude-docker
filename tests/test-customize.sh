#!/bin/bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

echo "Customize tests"
echo "==============="

MARKER=/etc/claude-code/customize-test-marker

# Fixture (tests/fixtures/customize/customize.sh) is staged into the build
# context by run.sh, so this marker must exist if the COPY+RUN in the
# Dockerfile actually executed the user's script.
assert_pass "customize.sh marker file exists" \
    test -f "$MARKER"

assert_pass "customize.sh ran as root (uid=0 in marker)" \
    grep -q '^customize-ran uid=0$' "$MARKER"

test_summary
