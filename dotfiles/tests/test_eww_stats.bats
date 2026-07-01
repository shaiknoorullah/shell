#!/usr/bin/env bats
# test_eww_stats.bats — eww-stats.sh: shame-free daily consistency stats.
#
# Owns ONLY eww-stats.sh. Drives it through a temp ~/.local/share/adhd/stats.json
# (no command mocks needed — it reads a file + real jq). The load-bearing
# guarantee under test: output is ALWAYS valid JSON with all five keys, numbers
# are NEVER negative, and the encouragement is NEVER scolding/empty.

setup() {
    STATS_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_eww-stats.sh"
    TEST_TEMP="$(mktemp -d)"
    export ADHD_STATS_FILE="$TEST_TEMP/stats.json"
}

teardown() {
    rm -rf "$TEST_TEMP"
}

# write_stats <json> — drop a stats.json into the isolated location.
write_stats() {
    printf '%s' "$1" > "$ADHD_STATS_FILE"
}

# ── valid input ───────────────────────────────────────────────

@test "eww-stats: emits all five keys from a full log" {
    write_stats '{"focus_score":84,"streak":12,"coffee":2,"walks":3,"encourage":"✦ best focus this week"}'
    run bash "$STATS_SH"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.focus_score and .streak and (.coffee != null) and (.walks != null) and .encourage' >/dev/null
}

@test "eww-stats: passes through provided numeric values" {
    write_stats '{"focus_score":84,"streak":12,"coffee":2,"walks":3,"encourage":"✦ best focus this week"}'
    run bash "$STATS_SH"
    [ "$(echo "$output" | jq '.focus_score')" -eq 84 ]
    [ "$(echo "$output" | jq '.streak')" -eq 12 ]
    [ "$(echo "$output" | jq '.coffee')" -eq 2 ]
    [ "$(echo "$output" | jq '.walks')" -eq 3 ]
}

@test "eww-stats: honours a provided encouragement line" {
    write_stats '{"focus_score":50,"streak":3,"coffee":1,"walks":1,"encourage":"✦ best focus this week"}'
    run bash "$STATS_SH"
    [ "$(echo "$output" | jq -r '.encourage')" = "✦ best focus this week" ]
}

# ── missing file → calm defaults ──────────────────────────────

@test "eww-stats: missing file yields valid JSON with zeroed, non-negative stats" {
    # ADHD_STATS_FILE intentionally does not exist
    run bash "$STATS_SH"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null
    [ "$(echo "$output" | jq '.focus_score')" -eq 0 ]
    [ "$(echo "$output" | jq '.streak')" -eq 0 ]
    [ "$(echo "$output" | jq '.coffee')" -eq 0 ]
    [ "$(echo "$output" | jq '.walks')" -eq 0 ]
}

@test "eww-stats: missing file still emits an encouraging line (never empty)" {
    run bash "$STATS_SH"
    enc="$(echo "$output" | jq -r '.encourage')"
    [ -n "$enc" ]
    [ "$enc" != "null" ]
}

# ── malformed input → defaults, no crash ──────────────────────

@test "eww-stats: malformed JSON falls back to defaults without erroring" {
    write_stats 'not json at all {{{'
    run bash "$STATS_SH"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null
    [ "$(echo "$output" | jq '.focus_score')" -eq 0 ]
}

# ── SHAME-FREE invariants ─────────────────────────────────────

@test "eww-stats: a negative streak in the log is never surfaced as negative" {
    write_stats '{"focus_score":10,"streak":-5,"coffee":-2,"walks":-1}'
    run bash "$STATS_SH"
    [ "$(echo "$output" | jq '.streak')"  -ge 0 ]
    [ "$(echo "$output" | jq '.coffee')"  -ge 0 ]
    [ "$(echo "$output" | jq '.walks')"   -ge 0 ]
    [ "$(echo "$output" | jq '.focus_score')" -ge 0 ]
}

@test "eww-stats: zero streak is framed as a fresh start, not a broken streak" {
    write_stats '{"focus_score":0,"streak":0,"coffee":0,"walks":0}'
    run bash "$STATS_SH"
    enc="$(echo "$output" | jq -r '.encourage')"
    [ -n "$enc" ]
    # Must not contain scolding / negative framing.
    echo "$enc" | grep -qiv 'broke'
    echo "$enc" | grep -qiv 'fail'
    echo "$enc" | grep -qiv 'miss'
}

@test "eww-stats: a long streak earns the strongest positive line" {
    write_stats '{"focus_score":90,"streak":12,"coffee":2,"walks":3}'
    run bash "$STATS_SH"
    [ "$(echo "$output" | jq -r '.encourage')" = "✦ best focus this week" ]
}
