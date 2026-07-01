#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

@test "media: previous triggers playerctl previous" {
    ROFI_MOCK_OUTPUT="󰒮"
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "playerctl" "previous"
}

@test "media: play/pause triggers playerctl play-pause" {
    ROFI_MOCK_OUTPUT="󰐎"
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "playerctl" "play-pause"
}

@test "media: next triggers playerctl next" {
    ROFI_MOCK_OUTPUT="󰒭"
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "playerctl" "next"
}

@test "media: shuffle triggers playerctl shuffle toggle" {
    ROFI_MOCK_OUTPUT="󰒟"
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "playerctl" "shuffle toggle"
}

@test "media: loop triggers playerctl loop" {
    ROFI_MOCK_OUTPUT="󰑖"
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "playerctl" "loop"
}

@test "media: track info passed as rofi message" {
    export PLAYERCTL_ARTIST="Pink Floyd"
    export PLAYERCTL_TITLE="Comfortably Numb"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "rofi" "Pink Floyd - Comfortably Numb"
}

@test "media: rofi called with media theme" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "rofi" "media.rasi"
}

@test "media: empty selection does nothing" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-media.sh)"
    # playerctl is called for metadata but not for any action
    local action_calls
    action_calls=$(grep "^playerctl " "$MOCK_LOG" | grep -v "metadata" | wc -l)
    assert_equal "$action_calls" "0"
}
