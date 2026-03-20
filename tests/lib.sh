#!/bin/bash
# Shared test helpers

_PASS=0
_FAIL=0
_TESTS=()

assert_pass() {
    local name="$1"
    shift
    echo -n "  $name ... "
    if output=$("$@" 2>&1); then
        echo "PASS"
        _PASS=$((_PASS + 1))
    else
        echo "FAIL"
        echo "    output: $output"
        _FAIL=$((_FAIL + 1))
    fi
    _TESTS+=("$name")
}

assert_fail() {
    local name="$1"
    shift
    echo -n "  $name ... "
    if output=$("$@" 2>&1); then
        echo "FAIL (should have been denied)"
        echo "    output: $output"
        _FAIL=$((_FAIL + 1))
    else
        echo "PASS"
        _PASS=$((_PASS + 1))
    fi
    _TESTS+=("$name")
}

test_summary() {
    echo
    echo "  Results: $_PASS passed, $_FAIL failed (${#_TESTS[@]} total)"
    [ "$_FAIL" -eq 0 ]
}
