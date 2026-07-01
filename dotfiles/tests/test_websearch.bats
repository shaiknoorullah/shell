#!/usr/bin/env bats
# test_websearch.bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

# Note: rofi -dump-config is the FIRST rofi call (to check for blocks plugin).
# The mock returns the first multi-output line for that call, so we prepend
# a dummy value that doesn't contain "blocks" to force the fallback path.

@test "websearch: google search opens correct URL" {
    set_rofi_outputs "no-blocks" "  Google" "test query"
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_called_with "firefox" "google.com/search"
}

@test "websearch: duckduckgo search opens correct URL" {
    set_rofi_outputs "no-blocks" "  DuckDuckGo" "test query"
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_called_with "firefox" "duckduckgo.com"
}

@test "websearch: youtube search opens correct URL" {
    set_rofi_outputs "no-blocks" "  YouTube" "test query"
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_called_with "firefox" "youtube.com/results"
}

@test "websearch: wikipedia search opens correct URL" {
    set_rofi_outputs "no-blocks" "󰖬  Wikipedia" "test query"
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_called_with "firefox" "wikipedia.org"
}

@test "websearch: empty engine selection exits" {
    set_rofi_outputs "no-blocks" ""
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_not_called "firefox"
}

@test "websearch: empty query exits" {
    set_rofi_outputs "no-blocks" "  Google" ""
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_not_called "firefox"
}

@test "websearch: rofi called with websearch theme" {
    set_rofi_outputs "no-blocks" ""
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_called_with "rofi" "websearch.rasi"
}
