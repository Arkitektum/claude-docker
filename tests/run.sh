#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$REPO_DIR/.devcontainer"

IMAGE_NAME="claude-code"
IMAGE_TAG="test"
IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

LOCAL_USER="${USER}"
LOCAL_UID="$(id -u)"
LOCAL_GID="$(id -g)"

cleanup() {
    if [ -n "${CONTAINER_ID:-}" ]; then
        docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

echo "Building image..."
if ! docker build \
    --build-arg LOCAL_USER="$LOCAL_USER" \
    --build-arg LOCAL_UID="$LOCAL_UID" \
    --build-arg LOCAL_GID="$LOCAL_GID" \
    -t "$IMAGE" \
    "$DATA_DIR"; then
    echo "Build failed" >&2
    exit 1
fi

echo
echo "Starting container (entrypoint sets up proxy and firewall)..."
HOST_TZ="${TZ:-$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')}"
TZ_ARGS=()
[ -n "$HOST_TZ" ] && TZ_ARGS=(-e TZ="$HOST_TZ")
CONTAINER_ID=$(docker run -d --init --rm \
    --cap-drop=ALL \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    --cap-add=SETUID \
    --cap-add=SETGID \
    --cap-add=AUDIT_WRITE \
    "${TZ_ARGS[@]}" \
    -v "$REPO_DIR:$REPO_DIR" \
    -w "$REPO_DIR" \
    "$IMAGE")

# Wait for entrypoint to finish proxy/firewall setup
for i in $(seq 1 60); do
    if docker exec "$CONTAINER_ID" test -f /tmp/.proxy-ready 2>/dev/null; then
        echo "Proxy setup complete"
        break
    fi
    sleep 0.5
done
if ! docker exec "$CONTAINER_ID" test -f /tmp/.proxy-ready 2>/dev/null; then
    echo "ERROR: Proxy setup did not complete in time" >&2
    docker logs "$CONTAINER_ID" >&2
    exit 1
fi

echo
TOTAL_FAIL=0

for test_script in "$SCRIPT_DIR"/test-*.sh; do
    echo "--------------------------------------"
    docker exec --user "${LOCAL_UID}:${LOCAL_GID}" \
        -w "$REPO_DIR" \
        "$CONTAINER_ID" \
        bash "$test_script" || TOTAL_FAIL=$((TOTAL_FAIL + 1))
    echo
done

echo "======================================"
if [ "$TOTAL_FAIL" -eq 0 ]; then
    echo "All test suites passed"
else
    echo "$TOTAL_FAIL test suite(s) failed"
    exit 1
fi
