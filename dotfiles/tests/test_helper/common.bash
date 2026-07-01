#!/usr/bin/env bash
# common.bash — Shared test infrastructure for all rofi script tests.
#
# Provides:
#   - BATS helper loading (bats-support, bats-assert)
#   - Mock infrastructure (PATH injection, logging, response control)
#   - Temp directory management with automatic cleanup
#   - Helper functions for asserting mock invocations

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$HOME/.config/rofi/scripts"
MOCKS_DIR="$TESTS_DIR/test_helper/mocks"
MOCK_RESPONSES_DIR="$TESTS_DIR/test_helper/mock_responses"

# Load BATS helpers
load "$TESTS_DIR/test_helper/bats-support/load"
load "$TESTS_DIR/test_helper/bats-assert/load"

# ── Setup / Teardown ──────────────────────────────────────────

# Called before each test. Creates temp dirs, injects mocks into PATH.
common_setup() {
    # Create temp directory for this test
    TEST_TEMP="$(mktemp -d)"
    export TEST_TEMP

    # Mock log — every mock appends its invocation here
    export MOCK_LOG="$TEST_TEMP/mock_calls.log"
    touch "$MOCK_LOG"

    # Rofi mock output — tests set this to simulate user selection
    export ROFI_MOCK_OUTPUT=""

    # Multi-call rofi output — for scripts that invoke rofi multiple times
    # Each line is consumed in order. File is created only when needed.
    export ROFI_MULTI_OUTPUT="$TEST_TEMP/rofi_multi_output"

    # Track which rofi call we're on (for multi-call scripts)
    export ROFI_CALL_COUNT="$TEST_TEMP/rofi_call_count"
    echo "0" > "$ROFI_CALL_COUNT"

    # Override HOME to isolate file operations
    export REAL_HOME="$HOME"
    export HOME="$TEST_TEMP/fakehome"
    mkdir -p "$HOME/.config/rofi/themes" "$HOME/.config/rofi/scripts/apis" "$HOME/.config/i3"

    # Copy theme files so scripts can reference them (they just need to exist)
    for theme in power media screenshot keybindings wallpaper clipboard git-profile \
                 tmux projects obsidian obsidian-search bluetooth display systemd \
                 bookmarks websearch calculator emoji; do
        touch "$HOME/.config/rofi/themes/${theme}.rasi"
    done

    # Inject mocks into PATH (mocks take priority over real commands)
    export PATH="$MOCKS_DIR:$PATH"
}

# Called after each test. Removes temp directory.
common_teardown() {
    rm -rf "$TEST_TEMP"
}

# ── Mock Assertion Helpers ────────────────────────────────────

# assert_mock_called <command> — Asserts that a mock was invoked
assert_mock_called() {
    local cmd="$1"
    grep -q "^$cmd " "$MOCK_LOG" || grep -q "^$cmd$" "$MOCK_LOG" || {
        echo "Expected mock '$cmd' to be called, but it wasn't."
        echo "Mock log contents:"
        cat "$MOCK_LOG"
        return 1
    }
}

# assert_mock_not_called <command> — Asserts that a mock was NOT invoked
assert_mock_not_called() {
    local cmd="$1"
    if grep -q "^$cmd " "$MOCK_LOG" 2>/dev/null || grep -q "^$cmd$" "$MOCK_LOG" 2>/dev/null; then
        echo "Expected mock '$cmd' NOT to be called, but it was."
        echo "Mock log contents:"
        cat "$MOCK_LOG"
        return 1
    fi
}

# assert_mock_called_with <command> <substring> — Asserts mock called with args containing substring
assert_mock_called_with() {
    local cmd="$1"
    local expected="$2"
    grep "^$cmd " "$MOCK_LOG" | grep -qF -- "$expected" || {
        echo "Expected '$cmd' to be called with args containing '$expected'"
        echo "Actual calls:"
        grep "^$cmd " "$MOCK_LOG" || echo "(none)"
        return 1
    }
}

# assert_mock_called_with_exact <full_line> — Asserts exact line exists in mock log
assert_mock_called_with_exact() {
    local expected="$1"
    grep -qF "$expected" "$MOCK_LOG" || {
        echo "Expected exact mock call: $expected"
        echo "Mock log contents:"
        cat "$MOCK_LOG"
        return 1
    }
}

# get_mock_calls <command> — Returns all invocations of a mock
get_mock_calls() {
    local cmd="$1"
    grep "^$cmd " "$MOCK_LOG" || true
}

# set_rofi_outputs <output1> <output2> ... — Sets multi-call rofi responses
set_rofi_outputs() {
    > "$ROFI_MULTI_OUTPUT"
    for output in "$@"; do
        echo "$output" >> "$ROFI_MULTI_OUTPUT"
    done
}

# get_script <name> — Returns the real path to a script (not in fake HOME)
get_script() {
    echo "$SCRIPTS_DIR/$1"
}
