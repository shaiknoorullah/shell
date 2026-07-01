#!/usr/bin/env bats
#
# test_eww_media.bats — eww-media.sh backend.
#
# The script queries playerctl for status + metadata and emits
# {"title","artist","status"}, or an empty object {} when no player is running.
# We mock playerctl via a per-test PATH-injected stub (PLAYERCTL_BIN) driven by
# env vars, so nothing touches a real MPRIS bus.

setup() {
    load 'test_helper/common'
    common_setup

    MEDIA_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_eww-media.sh"

    STUB_DIR="$TEST_TEMP/stubs"
    mkdir -p "$STUB_DIR"
    export PATH="$STUB_DIR:$PATH"

    # Stub behaviour: STUB_STATUS is printed for `playerctl status`. When empty,
    # the stub prints nothing and exits 1 (mirrors "No players found").
    export STUB_STATUS="Playing"
    export STUB_TITLE="Comfortably Numb"
    export STUB_ARTIST="Pink Floyd"

    cat > "$STUB_DIR/playerctl" <<'STUB'
#!/usr/bin/env bash
echo "playerctl $*" >> "$MOCK_LOG"
case "$1" in
    status)
        if [ -z "$STUB_STATUS" ]; then
            echo "No players found" >&2
            exit 1
        fi
        echo "$STUB_STATUS"
        ;;
    metadata)
        case "$2" in
            title)  printf '%s\n' "$STUB_TITLE" ;;
            artist) printf '%s\n' "$STUB_ARTIST" ;;
        esac
        ;;
esac
STUB
    chmod +x "$STUB_DIR/playerctl"
}

teardown() {
    common_teardown
}

@test "eww-media: emits a valid JSON object" {
    run bash "$MEDIA_SH"
    assert_success
    echo "$output" | jq -e 'type == "object"' >/dev/null
}

@test "eww-media: object has title, artist and status keys" {
    run bash "$MEDIA_SH"
    echo "$output" | jq -e 'has("title") and has("artist") and has("status")' >/dev/null
}

@test "eww-media: reports the playerctl status" {
    run bash "$MEDIA_SH"
    assert_equal "$(echo "$output" | jq -r '.status')" "Playing"
}

@test "eww-media: reports title and artist" {
    run bash "$MEDIA_SH"
    assert_equal "$(echo "$output" | jq -r '.title')"  "Comfortably Numb"
    assert_equal "$(echo "$output" | jq -r '.artist')" "Pink Floyd"
}

@test "eww-media: reflects a paused status" {
    export STUB_STATUS="Paused"
    run bash "$MEDIA_SH"
    assert_equal "$(echo "$output" | jq -r '.status')" "Paused"
}

@test "eww-media: empty object when no player is running" {
    export STUB_STATUS=""
    run bash "$MEDIA_SH"
    assert_success
    assert_equal "$output" "{}"
}

@test "eww-media: does not query metadata when no player is running" {
    export STUB_STATUS=""
    run bash "$MEDIA_SH"
    run grep -c "^playerctl metadata" "$MOCK_LOG"
    assert_equal "$output" "0"
}

@test "eww-media: produces valid JSON for titles with quotes" {
    export STUB_TITLE='She said "hi"'
    export STUB_ARTIST='AC\DC'
    run bash "$MEDIA_SH"
    echo "$output" | jq -e '.' >/dev/null
    assert_equal "$(echo "$output" | jq -r '.title')" 'She said "hi"'
}

@test "eww-media: tolerates missing metadata (empty strings)" {
    export STUB_TITLE=""
    export STUB_ARTIST=""
    run bash "$MEDIA_SH"
    assert_success
    assert_equal "$(echo "$output" | jq -r '.title')"  ""
    assert_equal "$(echo "$output" | jq -r '.artist')" ""
    assert_equal "$(echo "$output" | jq -r '.status')" "Playing"
}
