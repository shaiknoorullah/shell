#!/usr/bin/env bats
# test_eww_tasks.bats — eww-tasks.sh: "now · next" task rows for the left bar.
#
# Asserts a valid JSON array of rows with the expected keys across:
#   - an active task surfaced first (active:true, live timew elapsed as meta)
#   - +today / +next tasks appended and de-duplicated
#   - the MAX_ROWS cap
#   - no tasks at all → empty array (defpoll never breaks)
#   - TASK_BIN routing (go-task shadows `task`)
#
# task/timew are mocked per-test via an override dir prepended to PATH so we
# control exact output without touching the shared fixtures.

setup() {
    load 'test_helper/common'
    common_setup
    TASKS_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_eww-tasks.sh"

    MOCK_BIN="$TEST_TEMP/eww-tasks-mocks"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"

    # Route taskwarrior through the mock (go-task shadows `task`).
    export TASK_BIN="$MOCK_BIN/task"
}

teardown() {
    common_teardown
}

# write_task_mock <active_ids> <today_ids> <next_ids>
# Emulates the three id queries plus per-id _get lookups. Descriptions / metas
# are derived deterministically from the id ("desc N" / tag "ctx").
write_task_mock() {
    printf '%s' "$1" > "$MOCK_BIN/.active"
    printf '%s' "$2" > "$MOCK_BIN/.today"
    printf '%s' "$3" > "$MOCK_BIN/.next"
    cat > "$MOCK_BIN/task" <<EOF
#!/usr/bin/env bash
echo "task \$*" >> "$MOCK_LOG"
case "\$*" in
    *"+ACTIVE ids"*) cat "$MOCK_BIN/.active"; echo ;;
    *"+today ids"*)  cat "$MOCK_BIN/.today"; echo ;;
    *"+next ids"*)   cat "$MOCK_BIN/.next"; echo ;;
    *_get*.description*) id="\${*}"; id="\${id##*_get }"; id="\${id%%.description*}"; echo "desc \$id" ;;
    *_get*.tags*) echo "ctx" ;;
    *_get*.project*) echo "" ;;
esac
EOF
    chmod +x "$MOCK_BIN/task"
}

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

@test "eww-tasks: emits a valid JSON array" {
    write_task_mock "1" "2 3" "4"
    write_timew_mock "1:47"
    run bash "$TASKS_SH"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'type == "array"' >/dev/null
}

@test "eww-tasks: each row has the expected keys" {
    write_task_mock "1" "2" "3"
    write_timew_mock "0:05"
    run bash "$TASKS_SH"
    echo "$output" | jq -e 'all(.[]; has("id") and has("desc") and has("meta") and has("active") and has("icon"))' >/dev/null
}

# ── active first ──────────────────────────────────────────────

@test "eww-tasks: active task is first and marked active with elapsed meta" {
    write_task_mock "7" "8 9" "10"
    write_timew_mock "2:17"
    run bash "$TASKS_SH"
    [ "$(echo "$output" | jq -r '.[0].id')" = "7" ]
    [ "$(echo "$output" | jq -r '.[0].active')" = "true" ]
    [ "$(echo "$output" | jq -r '.[0].meta')" = "2:17" ]
}

@test "eww-tasks: non-active rows are marked inactive" {
    write_task_mock "7" "8" "9"
    write_timew_mock "0:01"
    run bash "$TASKS_SH"
    [ "$(echo "$output" | jq -r '.[1].active')" = "false" ]
}

# ── dedup + cap ───────────────────────────────────────────────

@test "eww-tasks: de-duplicates ids across active/today/next" {
    # id 5 appears in all three lists; should surface exactly once.
    write_task_mock "5" "5 6" "5 7"
    write_timew_mock "0:30"
    run bash "$TASKS_SH"
    count="$(echo "$output" | jq '[.[] | select(.id == 5)] | length')"
    [ "$count" -eq 1 ]
}

@test "eww-tasks: caps rows at EWW_TASKS_MAX" {
    export EWW_TASKS_MAX=2
    write_task_mock "1" "2 3 4 5" "6 7"
    write_timew_mock "0:10"
    run bash "$TASKS_SH"
    [ "$(echo "$output" | jq 'length')" -eq 2 ]
}

# ── empty ─────────────────────────────────────────────────────

@test "eww-tasks: no tasks -> empty array, still valid JSON" {
    write_task_mock "" "" ""
    write_timew_mock ""
    run bash "$TASKS_SH"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq 'length')" -eq 0 ]
}

# ── routing ───────────────────────────────────────────────────

@test "eww-tasks: routes taskwarrior via TASK_BIN" {
    write_task_mock "1" "2" "3"
    write_timew_mock "0:00"
    run bash "$TASKS_SH"
    assert_mock_called_with "task" "+ACTIVE ids"
    assert_mock_called_with "task" "+today ids"
    assert_mock_called_with "task" "+next ids"
}
