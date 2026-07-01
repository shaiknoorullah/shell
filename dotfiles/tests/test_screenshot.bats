#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
    mkdir -p "$HOME/Pictures/Screenshots"
}

teardown() {
    common_teardown
}

@test "screenshot: fullscreen calls maim with output path" {
    ROFI_MOCK_OUTPUT="󰍹"
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called "maim"
    # Should NOT have -s flag (that's area mode)
    local maim_call
    maim_call=$(grep "^maim " "$MOCK_LOG" | head -1)
    refute [[ "$maim_call" == *"-s"* ]]
}

@test "screenshot: area calls maim with -s flag" {
    ROFI_MOCK_OUTPUT="󰩭"
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called_with "maim" "-s"
}

@test "screenshot: window calls maim with -i flag" {
    ROFI_MOCK_OUTPUT="󰖯"
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called_with "maim" "-i"
    assert_mock_called "xdotool"
}

@test "screenshot: file saved to Screenshots directory" {
    ROFI_MOCK_OUTPUT="󰩭"
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called_with "maim" "Pictures/Screenshots/screenshot-"
}

@test "screenshot: clipboard populated via xclip" {
    ROFI_MOCK_OUTPUT="󰩭"
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called_with "xclip" "-selection clipboard"
    assert_mock_called_with "xclip" "image/png"
}

@test "screenshot: notification sent on success" {
    ROFI_MOCK_OUTPUT="󰩭"
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called_with "notify-send" "Screenshot Saved"
}

@test "screenshot: rofi called with screenshot theme" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called_with "rofi" "screenshot.rasi"
}

@test "screenshot: empty selection does nothing" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_not_called "maim"
    assert_mock_not_called "xclip"
}
