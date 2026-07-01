#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
    export TASK_BIN=task
    FOCUS_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_adhd-focus.sh"
    mkdir -p "$HOME/.config/adhd" "$HOME/.cache"
}

teardown() {
    common_teardown
}

# ── start ─────────────────────────────────────────────────────

@test "focus: start begins a timew interval for the task" {
    run bash "$FOCUS_SH" start 1
    assert_mock_called_with "task" "start"
}

@test "focus: start writes the focus state file" {
    run bash "$FOCUS_SH" start 1
    [ -f "$HOME/.cache/focus" ]
}

@test "focus: start notifies with next prayer" {
    printf 'Asr 16:42\nMaghrib 19:05\n' > "$HOME/.config/adhd/prayer-times.conf"
    run bash "$FOCUS_SH" start 1
    assert_mock_called_with "notify-send" "→"
}

# ── status ────────────────────────────────────────────────────

@test "focus: status reports minutes to next prayer" {
    printf 'Asr 16:42\nMaghrib 19:05\n' > "$HOME/.config/adhd/prayer-times.conf"
    run bash "$FOCUS_SH" status
    assert_output --partial "→"
}

# ── stop ──────────────────────────────────────────────────────

@test "focus: stop stops the task and clears state" {
    bash "$FOCUS_SH" start 7
    run bash "$FOCUS_SH" stop
    assert_mock_called_with "task" "stop"
    [ ! -f "$HOME/.cache/focus" ]
}

# ── nudge ─────────────────────────────────────────────────────

@test "focus: nudge stays silent for a fresh block (<90m)" {
    printf '%s %s\n' "$(date +%s)" "1" > "$HOME/.cache/focus"
    run bash "$FOCUS_SH" nudge
    assert_mock_not_called "notify-send"
}

@test "focus: nudge fires a dismissible notice past 90m" {
    printf '%s %s\n' "$(( $(date +%s) - 100 * 60 ))" "1" > "$HOME/.cache/focus"
    run bash "$FOCUS_SH" nudge
    assert_mock_called_with "notify-send" "breathe"
}
