#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

# ── Option Generation ─────────────────────────────────────────

@test "power: presents 5 options to rofi" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-power.sh)"
    # Rofi should be called with 5 newline-separated icons
    assert_mock_called "rofi"
}

# ── Shutdown (with confirmation) ──────────────────────────────

@test "power: shutdown confirmed triggers systemctl poweroff" {
    set_rofi_outputs "⏻" "Yes"
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "systemctl" "poweroff"
}

@test "power: shutdown denied does not trigger poweroff" {
    set_rofi_outputs "⏻" "No"
    run bash "$(get_script rofi-power.sh)"
    assert_mock_not_called "systemctl"
}

# ── Reboot (with confirmation) ────────────────────────────────

@test "power: reboot confirmed triggers systemctl reboot" {
    set_rofi_outputs $'\uf0e2' "Yes"
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "systemctl" "reboot"
}

@test "power: reboot denied does not trigger reboot" {
    set_rofi_outputs $'\uf0e2' "No"
    run bash "$(get_script rofi-power.sh)"
    assert_mock_not_called "systemctl"
}

# ── Lock (no confirmation) ────────────────────────────────────

@test "power: lock triggers i3lock immediately (no confirm)" {
    export ROFI_MOCK_OUTPUT=$'\uf023'
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "i3lock" "-c 1E1E2E"
}

# ── Suspend (no confirmation) ─────────────────────────────────

@test "power: suspend triggers systemctl suspend" {
    ROFI_MOCK_OUTPUT="⏾"
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "systemctl" "suspend"
}

# ── Logout (with confirmation) ────────────────────────────────

@test "power: logout confirmed triggers i3-msg exit" {
    set_rofi_outputs "󰍃" "Yes"
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "i3-msg" "exit"
}

# ── Cancel (empty selection) ──────────────────────────────────

@test "power: empty selection does nothing" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-power.sh)"
    assert_mock_not_called "systemctl"
    assert_mock_not_called "i3lock"
    assert_mock_not_called "i3-msg"
}

# ── Rofi invocation correctness ───────────────────────────────

@test "power: rofi called with correct theme" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "rofi" "power.rasi"
}

@test "power: rofi called with dmenu mode" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "rofi" "-dmenu"
}

@test "power: rofi called with Power Menu message" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "rofi" "Power Menu"
}
