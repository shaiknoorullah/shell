#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

@test "display: detects two monitors" {
    export XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0
HDMI-1 connected 2560x1440+1920+0"
    export ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "rofi" "display.rasi"
}

@test "display: laptop only turns off external" {
    export XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0
HDMI-1 connected 2560x1440+1920+0"
    export ROFI_MOCK_OUTPUT="󰍹  Laptop Only (eDP-1)"
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "xrandr" "--output eDP-1 --auto --primary --output HDMI-1 --off"
}

@test "display: external only turns off laptop" {
    export XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0
HDMI-1 connected 2560x1440+1920+0"
    export ROFI_MOCK_OUTPUT="󰍹  External Only (HDMI-1)"
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "xrandr" "--output HDMI-1 --auto --primary --output eDP-1 --off"
}

@test "display: mirror uses same-as" {
    export XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0
HDMI-1 connected 2560x1440+1920+0"
    export ROFI_MOCK_OUTPUT="󰍺  Mirror"
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "xrandr" "--same-as"
}

@test "display: extend right uses right-of" {
    export XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0
HDMI-1 connected 2560x1440+1920+0"
    export ROFI_MOCK_OUTPUT="  Extend Right"
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "xrandr" "--right-of"
}

@test "display: single monitor shows notification" {
    export XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0"
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "notify-send" "Only one display"
}

@test "display: notification sent after layout change" {
    export XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0
HDMI-1 connected 2560x1440+1920+0"
    export ROFI_MOCK_OUTPUT="󰕥  Auto Detect"
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "notify-send" "Layout changed"
}
