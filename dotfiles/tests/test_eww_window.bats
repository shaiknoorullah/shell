#!/usr/bin/env bats
#
# test_eww_window.bats — eww-window.sh backend (focused i3 window title).
#
# The script asks i3 for the window tree and prints the focused leaf's name,
# trimmed to a max width, with an em-dash placeholder when nothing is focused
# or i3 is unreachable. We mock i3-msg via a per-test PATH-injected stub
# (I3MSG_BIN) so nothing touches a real i3.

setup() {
    load 'test_helper/common'
    common_setup

    WINDOW_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_eww-window.sh"

    STUB_DIR="$TEST_TEMP/stubs"
    mkdir -p "$STUB_DIR"
    export PATH="$STUB_DIR:$PATH"

    # The stub prints whatever JSON tree the test puts in I3_TREE_FILE.
    export I3_TREE_FILE="$TEST_TEMP/tree.json"
    export I3MSG_BIN="$STUB_DIR/i3-msg"

    cat > "$STUB_DIR/i3-msg" <<'STUB'
#!/usr/bin/env bash
echo "i3-msg $*" >> "$MOCK_LOG"
if [ -r "$I3_TREE_FILE" ]; then
    cat "$I3_TREE_FILE"
fi
STUB
    chmod +x "$STUB_DIR/i3-msg"
}

teardown() {
    common_teardown
}

# A minimal i3 tree with one focused leaf.
write_tree() {
    local name="$1"
    cat > "$I3_TREE_FILE" <<JSON
{
  "type": "root",
  "nodes": [
    { "type": "con", "name": "unfocused", "focused": false, "nodes": [] },
    { "type": "con", "name": "$name", "focused": true, "nodes": [] }
  ]
}
JSON
}

@test "eww-window: prints the focused window title" {
    write_tree "nvim — boolgen-otel.ts"
    run bash "$WINDOW_SH"
    assert_success
    assert_equal "$output" "nvim — boolgen-otel.ts"
}

@test "eww-window: queries i3 for the tree" {
    write_tree "kitty"
    run bash "$WINDOW_SH"
    assert_mock_called_with "i3-msg" "get_tree"
}

@test "eww-window: em-dash placeholder when nothing is focused" {
    cat > "$I3_TREE_FILE" <<'JSON'
{ "type": "root", "name": "root", "focused": false, "nodes": [] }
JSON
    run bash "$WINDOW_SH"
    assert_success
    assert_equal "$output" "—"
}

@test "eww-window: em-dash when i3 returns nothing" {
    : > "$I3_TREE_FILE"
    run bash "$WINDOW_SH"
    assert_success
    assert_equal "$output" "—"
}

@test "eww-window: em-dash when focused name is null" {
    cat > "$I3_TREE_FILE" <<'JSON'
{ "type": "root", "nodes": [ { "type": "con", "name": null, "focused": true, "nodes": [] } ] }
JSON
    run bash "$WINDOW_SH"
    assert_success
    assert_equal "$output" "—"
}

@test "eww-window: trims overly long titles and appends ellipsis" {
    write_tree "this-is-a-really-long-window-title-that-should-be-trimmed-down-because-it-is-too-wide"
    EWW_WINDOW_MAXLEN=20 run bash "$WINDOW_SH"
    assert_success
    # 20 chars + ellipsis
    assert_equal "${#output}" "21"
    [[ "$output" == *"…" ]]
}

@test "eww-window: tolerates malformed JSON (em-dash, no crash)" {
    printf 'not json at all {{{' > "$I3_TREE_FILE"
    run bash "$WINDOW_SH"
    assert_success
    assert_equal "$output" "—"
}
