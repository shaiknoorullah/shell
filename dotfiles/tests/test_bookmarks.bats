#!/usr/bin/env bats
# test_bookmarks.bats

setup() {
    load 'test_helper/common'
    common_setup
    # Create fake Firefox profile with places.sqlite
    mkdir -p "$HOME/snap/firefox/common/.mozilla/firefox/abc123.default"
    touch "$HOME/snap/firefox/common/.mozilla/firefox/abc123.default/places.sqlite"
    FIND_USE_REAL=true
    export FIND_USE_REAL
}

teardown() {
    common_teardown
}

@test "bookmarks: finds places.sqlite in snap path" {
    SQLITE3_OUTPUT="GitHub | https://github.com"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bookmarks.sh)"
    assert_mock_called "sqlite3"
}

@test "bookmarks: copies db to /tmp (avoids Firefox lock)" {
    SQLITE3_OUTPUT="GitHub | https://github.com"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bookmarks.sh)"
    # sqlite3 should be called with a /tmp path
    assert_mock_called_with "sqlite3" "/tmp/"
}

@test "bookmarks: opens selected URL in firefox" {
    SQLITE3_OUTPUT="GitHub | https://github.com"
    ROFI_MOCK_OUTPUT="GitHub | https://github.com"
    run bash "$(get_script rofi-bookmarks.sh)"
    assert_mock_called_with "firefox" "https://github.com"
}

@test "bookmarks: error if no Firefox profile" {
    rm -rf "$HOME/snap" "$HOME/.mozilla"
    run bash "$(get_script rofi-bookmarks.sh)"
    assert_mock_called_with "notify-send" "Firefox profile not found"
}

@test "bookmarks: rofi called with bookmarks theme" {
    SQLITE3_OUTPUT="Test | https://test.com"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bookmarks.sh)"
    assert_mock_called_with "rofi" "bookmarks.rasi"
}
