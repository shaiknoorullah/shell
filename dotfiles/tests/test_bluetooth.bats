#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

@test "bluetooth: powers on if powered off" {
    export BT_POWERED="no"
    export ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_mock_called_with "bluetoothctl" "power on"
}

@test "bluetooth: skips power on if already on" {
    export BT_POWERED="yes"
    export ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bluetooth.sh)"
    # power on should not appear in the log
    local power_calls
    power_calls=$(grep "bluetoothctl power" "$MOCK_LOG" | wc -l)
    assert_equal "$power_calls" "0"
}

@test "bluetooth: shows paired devices" {
    export BT_POWERED="yes"
    export BT_PAIRED_DEVICES="Device AA:BB:CC:DD:EE:FF My Headphones"
    export BT_CONNECTED="no"
    export ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_mock_called_with "bluetoothctl" "devices Paired"
}

@test "bluetooth: scan triggers bluetoothctl scan" {
    export BT_POWERED="yes"
    export BT_PAIRED_DEVICES=""
    export BT_ALL_DEVICES="Device 11:22:33:44:55:66 New Speaker"
    set_rofi_outputs "󰂰  Scan for devices" "New Speaker"
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_mock_called_with "bluetoothctl" "scan on"
    assert_mock_called_with "bluetoothctl" "pair"
}

@test "bluetooth: connect selected device" {
    export BT_POWERED="yes"
    export BT_PAIRED_DEVICES="Device AA:BB:CC:DD:EE:FF Headphones"
    export BT_CONNECTED="no"
    set_rofi_outputs "  Headphones" "󰂱  Connect"
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_mock_called_with "bluetoothctl" "connect"
}

@test "bluetooth: disconnect connected device" {
    export BT_POWERED="yes"
    export BT_PAIRED_DEVICES="Device AA:BB:CC:DD:EE:FF Headphones"
    export BT_CONNECTED="yes"
    set_rofi_outputs "󰂱  Headphones [connected]" "󰂲  Disconnect"
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_mock_called_with "bluetoothctl" "disconnect"
}

@test "bluetooth: empty selection exits cleanly" {
    export BT_POWERED="yes"
    export BT_PAIRED_DEVICES=""
    export ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_success
}

@test "bluetooth: rofi called with bluetooth theme" {
    export BT_POWERED="yes"
    export ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_mock_called_with "rofi" "bluetooth.rasi"
}
