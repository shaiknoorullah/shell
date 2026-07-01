#!/usr/bin/env bats
# test_clipboard.bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

@test "clipboard: starts greenclip daemon if not running" {
    export PGREP_FOUND=false
    run bash "$(get_script rofi-clipboard.sh)"
    assert_mock_called_with "greenclip" "daemon"
}

@test "clipboard: skips daemon start if already running" {
    export PGREP_FOUND=true
    run bash "$(get_script rofi-clipboard.sh)"
    assert_mock_not_called "greenclip"
}

@test "clipboard: rofi called with greenclip modi" {
    export PGREP_FOUND=true
    run bash "$(get_script rofi-clipboard.sh)"
    assert_mock_called_with "rofi" "clipboard:greenclip print"
}

@test "clipboard: rofi called with clipboard theme" {
    export PGREP_FOUND=true
    run bash "$(get_script rofi-clipboard.sh)"
    assert_mock_called_with "rofi" "clipboard.rasi"
}
