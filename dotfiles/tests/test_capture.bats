#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
    export TASK_BIN=task
}

teardown() {
    common_teardown
}

# Script lives in the chezmoi source (not deployed), so invoke it by SOURCE path.
CAPTURE_SCRIPT="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_adhd-capture.sh"

# ── Capture to Obsidian REST inbox ────────────────────────────

@test "capture: posts typed text to Obsidian REST inbox" {
    set_rofi_outputs "ship the otel patch"
    run bash "$CAPTURE_SCRIPT"
    assert_success
    assert_mock_called_with "curl" "27124"
}

@test "capture: posts under the Inbox heading" {
    set_rofi_outputs "ship the otel patch"
    run bash "$CAPTURE_SCRIPT"
    assert_mock_called_with "curl" "Inbox"
}

@test "capture: includes the captured text in the request body" {
    set_rofi_outputs "ship the otel patch"
    run bash "$CAPTURE_SCRIPT"
    assert_mock_called_with "curl" "ship the otel patch"
}

# ── t: / task: prefix also adds a task ────────────────────────

@test "capture: t: prefix also adds a task" {
    set_rofi_outputs "t: review FR-006 PR"
    run bash "$CAPTURE_SCRIPT"
    assert_mock_called_with "task" "add"
}

@test "capture: task: prefix also adds a task" {
    set_rofi_outputs "task: review FR-006 PR"
    run bash "$CAPTURE_SCRIPT"
    assert_mock_called_with "task" "add"
}

@test "capture: plain text does NOT add a task" {
    set_rofi_outputs "just a note"
    run bash "$CAPTURE_SCRIPT"
    assert_mock_not_called "task"
}

# ── Cancel / empty selection ──────────────────────────────────

@test "capture: empty selection does nothing" {
    set_rofi_outputs ""
    run bash "$CAPTURE_SCRIPT"
    assert_success
    assert_mock_not_called "curl"
    assert_mock_not_called "task"
}
