#!/usr/bin/env bats
#
# test_eww_workspaces.bats — eww-workspaces.sh backend.
#
# The script shells out to `i3-msg -t get_workspaces` and reshapes the result
# with jq into a compact array of {num, focused, name}. We mock i3-msg via a
# per-test PATH-injected stub (I3MSG_BIN) so we never touch the live i3 socket.

setup() {
    load 'test_helper/common'
    common_setup

    WS_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_eww-workspaces.sh"

    # Per-test stub dir for i3-msg, prepended ahead of the shared mocks so our
    # JSON-emitting stub wins. Real jq is still resolved from PATH.
    STUB_DIR="$TEST_TEMP/stubs"
    mkdir -p "$STUB_DIR"
    export PATH="$STUB_DIR:$PATH"

    # I3MSG_OUTPUT controls what the stub prints; I3MSG_EXIT its exit code.
    export I3MSG_OUTPUT_FILE="$TEST_TEMP/i3msg_output"
    export I3MSG_EXIT_FILE="$TEST_TEMP/i3msg_exit"
    : > "$I3MSG_OUTPUT_FILE"
    echo 0 > "$I3MSG_EXIT_FILE"

    cat > "$STUB_DIR/i3-msg" <<'STUB'
#!/usr/bin/env bash
echo "i3-msg $*" >> "$MOCK_LOG"
cat "$I3MSG_OUTPUT_FILE"
exit "$(cat "$I3MSG_EXIT_FILE")"
STUB
    chmod +x "$STUB_DIR/i3-msg"
}

teardown() {
    common_teardown
}

# i3's get_workspaces returns verbose objects; the script keeps only num/focused/name.
i3_fixture() {
    cat > "$I3MSG_OUTPUT_FILE" <<'JSON'
[
  {"num":1,"name":"1","focused":true,"visible":true,"urgent":false,"output":"DP-1"},
  {"num":2,"name":"2:web","focused":false,"visible":false,"urgent":false,"output":"DP-1"},
  {"num":3,"name":"3:chat","focused":false,"visible":true,"urgent":true,"output":"HDMI-1"}
]
JSON
}

@test "eww-workspaces: queries i3 for the workspace list" {
    i3_fixture
    run bash "$WS_SH"
    assert_success
    assert_mock_called_with "i3-msg" "-t get_workspaces"
}

@test "eww-workspaces: emits a valid JSON array" {
    i3_fixture
    run bash "$WS_SH"
    assert_success
    echo "$output" | jq -e 'type == "array"' >/dev/null
}

@test "eww-workspaces: each entry has num, focused and name" {
    i3_fixture
    run bash "$WS_SH"
    echo "$output" | jq -e 'all(.[]; has("num") and has("focused") and has("name"))' >/dev/null
}

@test "eww-workspaces: preserves num/name/focused values" {
    i3_fixture
    run bash "$WS_SH"
    assert_equal "$(echo "$output" | jq -r '.[0].num')"     "1"
    assert_equal "$(echo "$output" | jq -r '.[0].focused')" "true"
    assert_equal "$(echo "$output" | jq -r '.[1].name')"    "2:web"
}

@test "eww-workspaces: drops i3's extra fields (only num/focused/name)" {
    i3_fixture
    run bash "$WS_SH"
    assert_equal "$(echo "$output" | jq -r '.[0] | keys | sort | join(",")')" "focused,name,num"
}

@test "eww-workspaces: preserves i3 ordering" {
    i3_fixture
    run bash "$WS_SH"
    assert_equal "$(echo "$output" | jq -r '[.[].num] | join(",")')" "1,2,3"
}

@test "eww-workspaces: empty array when i3 returns nothing" {
    : > "$I3MSG_OUTPUT_FILE"
    run bash "$WS_SH"
    assert_success
    assert_equal "$output" "[]"
}

@test "eww-workspaces: empty array when i3 is unreachable (non-zero exit)" {
    : > "$I3MSG_OUTPUT_FILE"
    echo 1 > "$I3MSG_EXIT_FILE"
    run bash "$WS_SH"
    assert_success
    assert_equal "$output" "[]"
}

@test "eww-workspaces: empty array on malformed i3 output" {
    printf 'not json at all' > "$I3MSG_OUTPUT_FILE"
    run bash "$WS_SH"
    assert_success
    assert_equal "$output" "[]"
}
