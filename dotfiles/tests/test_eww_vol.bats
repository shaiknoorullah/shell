#!/usr/bin/env bats
#
# test_eww_vol.bats — eww-vol.sh backend (system output volume).
#
# The script parses `wpctl get-volume` and emits {"vol":<int>,"muted":<bool>}.
# We mock wpctl via a per-test PATH-injected stub (WPCTL_BIN) driven by env
# vars, so nothing touches a real PipeWire graph.

setup() {
    load 'test_helper/common'
    common_setup

    VOL_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_eww-vol.sh"

    STUB_DIR="$TEST_TEMP/stubs"
    mkdir -p "$STUB_DIR"
    export PATH="$STUB_DIR:$PATH"

    # STUB_VOL is the raw line wpctl prints; empty => stub exits 1 (no sink).
    export STUB_VOL="Volume: 0.62"
    export WPCTL_BIN="$STUB_DIR/wpctl"

    cat > "$STUB_DIR/wpctl" <<'STUB'
#!/usr/bin/env bash
echo "wpctl $*" >> "$MOCK_LOG"
if [ -z "$STUB_VOL" ]; then
    echo "Object not found" >&2
    exit 1
fi
echo "$STUB_VOL"
STUB
    chmod +x "$STUB_DIR/wpctl"
}

teardown() {
    common_teardown
}

@test "eww-vol: emits a valid JSON object" {
    run bash "$VOL_SH"
    assert_success
    echo "$output" | jq -e 'type == "object"' >/dev/null
}

@test "eww-vol: object has vol and muted keys" {
    run bash "$VOL_SH"
    echo "$output" | jq -e 'has("vol") and has("muted")' >/dev/null
}

@test "eww-vol: converts fraction to integer percent" {
    export STUB_VOL="Volume: 0.62"
    run bash "$VOL_SH"
    assert_equal "$(echo "$output" | jq -r '.vol')" "62"
}

@test "eww-vol: vol is a JSON number, not a string" {
    run bash "$VOL_SH"
    echo "$output" | jq -e '.vol | type == "number"' >/dev/null
}

@test "eww-vol: rounds to nearest percent" {
    export STUB_VOL="Volume: 0.755"
    run bash "$VOL_SH"
    assert_equal "$(echo "$output" | jq -r '.vol')" "76"
}

@test "eww-vol: full volume reports 100" {
    export STUB_VOL="Volume: 1.00"
    run bash "$VOL_SH"
    assert_equal "$(echo "$output" | jq -r '.vol')" "100"
}

@test "eww-vol: not muted by default" {
    run bash "$VOL_SH"
    assert_equal "$(echo "$output" | jq -r '.muted')" "false"
}

@test "eww-vol: detects the MUTED flag" {
    export STUB_VOL="Volume: 0.62 [MUTED]"
    run bash "$VOL_SH"
    assert_equal "$(echo "$output" | jq -r '.muted')" "true"
    assert_equal "$(echo "$output" | jq -r '.vol')" "62"
}

@test "eww-vol: muted is a JSON boolean, not a string" {
    run bash "$VOL_SH"
    echo "$output" | jq -e '.muted | type == "boolean"' >/dev/null
}

@test "eww-vol: queries the default sink" {
    run bash "$VOL_SH"
    assert_mock_called_with "wpctl" "get-volume"
}

@test "eww-vol: degrades calmly when wpctl has no sink" {
    export STUB_VOL=""
    run bash "$VOL_SH"
    assert_success
    assert_equal "$(echo "$output" | jq -r '.vol')" "0"
    assert_equal "$(echo "$output" | jq -r '.muted')" "true"
}
