#!/bin/bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

echo "Filesystem tests"
echo "================"

# System directories should be read-only
assert_fail "cannot write to /etc" \
    touch /etc/_test_probe

assert_fail "cannot write to /usr/local/bin" \
    touch /usr/local/bin/_test_probe

assert_fail "cannot write to /usr/bin" \
    touch /usr/bin/_test_probe

assert_fail "cannot write to /sbin" \
    touch /sbin/_test_probe

# Sensitive files should not be readable
assert_fail "cannot read /etc/shadow" \
    cat /etc/shadow

# Root home should be inaccessible
assert_fail "cannot write to /root" \
    touch /root/_test_probe

# Proxy and firewall files should not be modifiable
assert_fail "cannot modify squid config" \
    sh -c "echo x >> /etc/squid/squid.conf"

assert_fail "cannot modify entrypoint" \
    sh -c "echo x >> /usr/local/bin/entrypoint.sh"

assert_fail "cannot modify init-proxy" \
    sh -c "echo x >> /usr/local/bin/init-proxy.sh"

assert_fail "cannot modify sudoers" \
    sh -c "echo x >> /etc/sudoers.d/init-proxy"

# User home should be writable
assert_pass "can write to home dir" \
    sh -c "touch ~/._test_probe && rm ~/._test_probe"

# Mounted workspace should be writable
assert_pass "can write to workspace" \
    sh -c "touch $DIR/._test_probe && rm $DIR/._test_probe"

# Cannot escalate privileges
assert_fail "cannot su to root" \
    su -c "id" root

assert_fail "cannot modify /proc/sys" \
    sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

test_summary
