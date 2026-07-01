#!/usr/bin/env bats
# test_wallpaper.bats

setup() {
    load 'test_helper/common'
    common_setup
    FIND_USE_REAL=true
    export FIND_USE_REAL
    mkdir -p "$HOME/Pictures/Wallpapers"
}

teardown() {
    common_teardown
}

@test "wallpaper: feh called with --bg-fill on selection" {
    touch "$HOME/Pictures/Wallpapers/mountain.jpg"
    ROFI_MOCK_OUTPUT="mountain.jpg"
    run bash "$(get_script rofi-wallpaper.sh)"
    assert_mock_called_with "feh" "--bg-fill"
    assert_mock_called_with "feh" "mountain.jpg"
}

@test "wallpaper: notification sent on set" {
    touch "$HOME/Pictures/Wallpapers/sunset.png"
    ROFI_MOCK_OUTPUT="sunset.png"
    run bash "$(get_script rofi-wallpaper.sh)"
    assert_mock_called_with "notify-send" "Wallpaper Set"
}

@test "wallpaper: empty selection does nothing" {
    touch "$HOME/Pictures/Wallpapers/test.jpg"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-wallpaper.sh)"
    assert_mock_not_called "feh"
}

@test "wallpaper: handles empty directory" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-wallpaper.sh)"
    assert_mock_called_with "notify-send" "No images found"
}

@test "wallpaper: rofi called with wallpaper theme" {
    touch "$HOME/Pictures/Wallpapers/test.jpg"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-wallpaper.sh)"
    assert_mock_called_with "rofi" "wallpaper.rasi"
}
