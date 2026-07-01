#!/usr/bin/env bats
# test_eww_salah.bats — eww-salah.sh: today's five-prayer strip for the left bar.
#
# Asserts a valid JSON array of prayers with name/time/state across:
#   - mid-day "now": past prayers done, the first upcoming one is next
#   - all states present and correctly ordered (schedule order preserved)
#   - end-of-day "now": every prayer done, none marked next
#   - missing config → empty array (defpoll never breaks)
#
# "now" is pinned via EWW_SALAH_NOW (HHMM) and the schedule via
# PRAYER_TIMES_CONF, so tests are deterministic and clock-independent.

setup() {
    load 'test_helper/common'
    common_setup
    SALAH_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_eww-salah.sh"

    CONF="$TEST_TEMP/prayer-times.conf"
    export PRAYER_TIMES_CONF="$CONF"
    cat > "$CONF" <<'EOF'
# test schedule
Fajr 04:55
Dhuhr 12:25
Asr 16:42
Maghrib 19:05
Isha 20:30
EOF
}

teardown() {
    common_teardown
}

# ── JSON shape ────────────────────────────────────────────────

@test "eww-salah: emits a valid JSON array" {
    export EWW_SALAH_NOW=1300
    run bash "$SALAH_SH"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'type == "array"' >/dev/null
}

@test "eww-salah: each prayer has name/time/state keys" {
    export EWW_SALAH_NOW=1300
    run bash "$SALAH_SH"
    echo "$output" | jq -e 'all(.[]; has("name") and has("time") and has("state"))' >/dev/null
}

@test "eww-salah: preserves schedule order with all five prayers" {
    export EWW_SALAH_NOW=1300
    run bash "$SALAH_SH"
    [ "$(echo "$output" | jq 'length')" -eq 5 ]
    [ "$(echo "$output" | jq -r '.[0].name')" = "Fajr" ]
    [ "$(echo "$output" | jq -r '.[4].name')" = "Isha" ]
}

# ── state logic ───────────────────────────────────────────────

@test "eww-salah: mid-afternoon -> Fajr/Dhuhr done, Asr next" {
    export EWW_SALAH_NOW=1300   # 13:00, after Dhuhr (12:25), before Asr (16:42)
    run bash "$SALAH_SH"
    [ "$(echo "$output" | jq -r '.[] | select(.name=="Fajr").state')" = "done" ]
    [ "$(echo "$output" | jq -r '.[] | select(.name=="Dhuhr").state')" = "done" ]
    [ "$(echo "$output" | jq -r '.[] | select(.name=="Asr").state')" = "next" ]
}

@test "eww-salah: prayers after next are neutral (empty state)" {
    export EWW_SALAH_NOW=1300
    run bash "$SALAH_SH"
    [ "$(echo "$output" | jq -r '.[] | select(.name=="Maghrib").state')" = "" ]
    [ "$(echo "$output" | jq -r '.[] | select(.name=="Isha").state')" = "" ]
}

@test "eww-salah: exactly one prayer is marked next" {
    export EWW_SALAH_NOW=1300
    run bash "$SALAH_SH"
    [ "$(echo "$output" | jq '[.[] | select(.state=="next")] | length')" -eq 1 ]
}

@test "eww-salah: before Fajr -> Fajr is next, none done" {
    export EWW_SALAH_NOW=0300   # 03:00, before Fajr
    run bash "$SALAH_SH"
    [ "$(echo "$output" | jq -r '.[] | select(.name=="Fajr").state')" = "next" ]
    [ "$(echo "$output" | jq '[.[] | select(.state=="done")] | length')" -eq 0 ]
}

@test "eww-salah: after Isha -> all done, none next" {
    export EWW_SALAH_NOW=2300   # 23:00, after Isha
    run bash "$SALAH_SH"
    [ "$(echo "$output" | jq '[.[] | select(.state=="done")] | length')" -eq 5 ]
    [ "$(echo "$output" | jq '[.[] | select(.state=="next")] | length')" -eq 0 ]
}

# ── robustness ────────────────────────────────────────────────

@test "eww-salah: missing config -> empty array, valid JSON" {
    export PRAYER_TIMES_CONF="$TEST_TEMP/does-not-exist.conf"
    run bash "$SALAH_SH"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq 'length')" -eq 0 ]
}
