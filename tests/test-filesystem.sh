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

# Firewall script should not be modifiable
assert_fail "cannot modify firewall script" \
    sh -c "echo x >> /usr/local/bin/init-firewall.sh"

assert_fail "cannot modify sudoers" \
    sh -c "echo x >> /etc/sudoers.d/firewall"

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
