#!/usr/bin/env bats
#
# test_eww_island.bats — eww-island.sh backend (Dynamic Island payload).
#
# The script fuses the media object (eww-media.sh) with the focus engine's
# live-activity line (adhd-focus.sh status) into one JSON object the island
# widget polls. We stub both sibling backends via env-var overrides
# (EWW_MEDIA_BIN / ADHD_FOCUS_BIN) so nothing touches a real MPRIS bus,
# taskwarrior, or timewarrior.

setup() {
    load 'test_helper/common'
    common_setup

    ISLAND_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_eww-island.sh"

    STUB_DIR="$TEST_TEMP/stubs"
    mkdir -p "$STUB_DIR"

    # Fake media backend: prints whatever MEDIA_JSON holds (default = a playing
    # track). Tests override MEDIA_JSON to simulate paused / no-player states.
    export MEDIA_JSON='{"title":"Let It Happen","artist":"Tame Impala","status":"Playing"}'
    cat > "$STUB_DIR/eww-media" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$MEDIA_JSON"
STUB
    chmod +x "$STUB_DIR/eww-media"
    export EWW_MEDIA_BIN="$STUB_DIR/eww-media"

    # Fake focus backend: echoes the live-activity line for `status`.
    export ACTIVITY_LINE='block 47m · → ʿAsr 16:30'
    cat > "$STUB_DIR/adhd-focus" <<'STUB'
#!/usr/bin/env bash
case "${1:-status}" in
    status) printf '%s\n' "$ACTIVITY_LINE" ;;
    *) ;;
esac
STUB
    chmod +x "$STUB_DIR/adhd-focus"
    export ADHD_FOCUS_BIN="$STUB_DIR/adhd-focus"
}

teardown() {
    common_teardown
}

@test "eww-island: emits a valid JSON object" {
    run bash "$ISLAND_SH"
    assert_success
    echo "$output" | jq -e 'type == "object"' >/dev/null
}

@test "eww-island: object carries all island keys" {
    run bash "$ISLAND_SH"
    echo "$output" | jq -e '
        has("title") and has("artist") and has("status")
        and has("playing") and has("hasmedia") and has("activity")
    ' >/dev/null
}

@test "eww-island: surfaces title and artist from the media backend" {
    run bash "$ISLAND_SH"
    assert_equal "$(echo "$output" | jq -r '.title')"  "Let It Happen"
    assert_equal "$(echo "$output" | jq -r '.artist')" "Tame Impala"
}

@test "eww-island: surfaces the live-activity line verbatim" {
    run bash "$ISLAND_SH"
    assert_equal "$(echo "$output" | jq -r '.activity')" 'block 47m · → ʿAsr 16:30'
}

@test "eww-island: playing flag is true while a track plays" {
    run bash "$ISLAND_SH"
    assert_equal "$(echo "$output" | jq -r '.playing')"  "true"
    assert_equal "$(echo "$output" | jq -r '.hasmedia')" "true"
}

@test "eww-island: playing flag is false when paused" {
    export MEDIA_JSON='{"title":"Let It Happen","artist":"Tame Impala","status":"Paused"}'
    run bash "$ISLAND_SH"
    assert_equal "$(echo "$output" | jq -r '.playing')"  "false"
    assert_equal "$(echo "$output" | jq -r '.hasmedia')" "true"
}

@test "eww-island: calm empty state when no player is running" {
    export MEDIA_JSON='{}'
    run bash "$ISLAND_SH"
    assert_success
    assert_equal "$(echo "$output" | jq -r '.title')"    ""
    assert_equal "$(echo "$output" | jq -r '.hasmedia')" "false"
    assert_equal "$(echo "$output" | jq -r '.playing')"  "false"
}

@test "eww-island: live activity is independent of media presence" {
    export MEDIA_JSON='{}'
    run bash "$ISLAND_SH"
    assert_equal "$(echo "$output" | jq -r '.activity')" 'block 47m · → ʿAsr 16:30'
}

@test "eww-island: idle activity surfaces when no focus block is running" {
    export ACTIVITY_LINE='idle · → Fajr (tmrw)'
    run bash "$ISLAND_SH"
    assert_equal "$(echo "$output" | jq -r '.activity')" 'idle · → Fajr (tmrw)'
}

@test "eww-island: tolerates a malformed media payload (falls back to empty)" {
    export MEDIA_JSON='not json at all'
    run bash "$ISLAND_SH"
    assert_success
    echo "$output" | jq -e 'type == "object"' >/dev/null
    assert_equal "$(echo "$output" | jq -r '.hasmedia')" "false"
}

@test "eww-island: produces valid JSON for titles with quotes" {
    export MEDIA_JSON='{"title":"She said \"hi\"","artist":"AC/DC","status":"Playing"}'
    run bash "$ISLAND_SH"
    echo "$output" | jq -e '.' >/dev/null
    assert_equal "$(echo "$output" | jq -r '.title')" 'She said "hi"'
}
