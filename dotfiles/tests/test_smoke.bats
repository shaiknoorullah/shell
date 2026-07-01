#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

@test "mock rofi returns ROFI_MOCK_OUTPUT" {
    ROFI_MOCK_OUTPUT="test selection"
    result=$(rofi -dmenu)
    assert_equal "$result" "test selection"
}

@test "mock rofi logs invocation" {
    rofi -dmenu -theme foo.rasi -p "Test"
    assert_mock_called "rofi"
    assert_mock_called_with "rofi" "-theme foo.rasi"
}

@test "multi-call rofi returns sequential outputs" {
    set_rofi_outputs "first" "second" "third"
    r1=$(rofi -dmenu)
    r2=$(rofi -dmenu)
    r3=$(rofi -dmenu)
    assert_equal "$r1" "first"
    assert_equal "$r2" "second"
    assert_equal "$r3" "third"
}

@test "mock systemctl logs invocation" {
    systemctl poweroff
    assert_mock_called_with "systemctl" "poweroff"
}

@test "mock pgrep returns success when PGREP_FOUND=true" {
    export PGREP_FOUND=true
    run pgrep -x greenclip
    assert_success
}

@test "mock pgrep returns failure when PGREP_FOUND unset" {
    unset PGREP_FOUND
    run pgrep -x greenclip
    assert_failure
}
