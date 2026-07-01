#!/usr/bin/env bats
# test_eww_active.bats — eww-active.sh: active taskwarrior task + live
# timewarrior elapsed as JSON.
#
# We assert valid JSON with `.task` and `.elapsed` keys (via jq) across:
#   - an active task (id -> description, open timew interval -> duration)
#   - no active task (em-dash placeholder, zero clock)
#   - TASK_BIN routing (go-task shadows `task`).
#
# task/timew are mocked per-test via an override dir prepended to PATH so
# we control exact output without touching the shared fixtures.

setup() {
    load 'test_helper/common'
    common_setup
    ACTIVE_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_eww-active.sh"

    # Per-test mock override dir (ahead of the shared mocks on PATH).
    MOCK_BIN="$TEST_TEMP/eww-active-mocks"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"

    # Route taskwarrior through the mock (go-task shadows `task`).
    export TASK_BIN="$MOCK_BIN/task"
}

teardown() {
    common_teardown
}

# write_task_mock <active_ids> <description>
# Emulates `task +ACTIVE ids` and `task _get <id>.description`. Values are
# passed via files (not source interpolation) so quotes survive intact.
write_task_mock() {
    printf '%s' "$1" > "$MOCK_BIN/.task_ids"
    printf '%s' "$2" > "$MOCK_BIN/.task_desc"
    cat > "$MOCK_BIN/task" <<EOF
#!/usr/bin/env bash
echo "task \$*" >> "$MOCK_LOG"
case "\$*" in
    *"+ACTIVE ids"*) cat "$MOCK_BIN/.task_ids"; echo ;;
    *_get*.description*) cat "$MOCK_BIN/.task_desc"; echo ;;
esac
EOF
    chmod +x "$MOCK_BIN/task"
}

# write_timew_mock <duration>
# Emulates `timew get dom.active.duration`.
write_timew_mock() {
    printf '%s' "$1" > "$MOCK_BIN/.timew_dur"
    cat > "$MOCK_BIN/timew" <<EOF
#!/usr/bin/env bash
echo "timew \$*" >> "$MOCK_LOG"
case "\$*" in
    *"get dom.active.duration"*) cat "$MOCK_BIN/.timew_dur"; echo ;;
esac
EOF
    chmod +x "$MOCK_BIN/timew"
}

# ── JSON shape ────────────────────────────────────────────────

@test "eww-active: emits valid JSON with task + elapsed keys" {
    write_task_mock "1" "boolgen otel"
    write_timew_mock "0:42:11"
    run bash "$ACTIVE_SH"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.task and .elapsed' >/dev/null
}

@test "eww-active: output is parseable JSON" {
    write_task_mock "3" "write phase-2 bars"
    write_timew_mock "1:05:00"
    run bash "$ACTIVE_SH"
    echo "$output" | jq -e '.' >/dev/null
}

# ── active task ───────────────────────────────────────────────

@test "eww-active: reports the active task description" {
    write_task_mock "7" "ship eww backends"
    write_timew_mock "0:03:20"
    run bash "$ACTIVE_SH"
    [ "$(echo "$output" | jq -r '.task')" = "ship eww backends" ]
}

@test "eww-active: reports the live timew elapsed" {
    write_task_mock "7" "ship eww backends"
    write_timew_mock "2:17:46"
    run bash "$ACTIVE_SH"
    [ "$(echo "$output" | jq -r '.elapsed')" = "2:17:46" ]
}

@test "eww-active: routes taskwarrior via TASK_BIN" {
    write_task_mock "1" "boolgen otel"
    write_timew_mock "0:00:05"
    run bash "$ACTIVE_SH"
    assert_mock_called_with "task" "+ACTIVE ids"
}

# ── no active task / not tracking ─────────────────────────────

@test "eww-active: no active task -> em-dash placeholder, still valid JSON" {
    write_task_mock "" ""
    write_timew_mock ""
    run bash "$ACTIVE_SH"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.task and .elapsed' >/dev/null
    [ "$(echo "$output" | jq -r '.task')" = "—" ]
}

@test "eww-active: not tracking -> zero clock elapsed" {
    write_task_mock "1" "boolgen otel"
    write_timew_mock ""
    run bash "$ACTIVE_SH"
    [ "$(echo "$output" | jq -r '.elapsed')" = "0:00:00" ]
}

# ── robustness ────────────────────────────────────────────────

@test "eww-active: description with double-quote stays valid JSON" {
    write_task_mock "5" 'fix "race" in poller'
    write_timew_mock "0:09:00"
    run bash "$ACTIVE_SH"
    echo "$output" | jq -e '.task' >/dev/null
    [ "$(echo "$output" | jq -r '.task')" = 'fix "race" in poller' ]
}
