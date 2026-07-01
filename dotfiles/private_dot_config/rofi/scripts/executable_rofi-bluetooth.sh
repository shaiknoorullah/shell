#!/usr/bin/env bash
#
# rofi-bluetooth.sh -- Bluetooth Device Manager
#
# Description:
#   Full-featured Bluetooth manager driven by rofi. The main menu lists all
#   paired devices (showing their connection status) and offers a scan option
#   for discovering new devices. Selecting a paired device opens a sub-menu
#   with context-sensitive actions (connect/disconnect, trust, remove). The
#   scan flow discovers nearby devices, then performs a pair + trust + connect
#   sequence on the user's selection.
#
# Keybinding: $mod+Shift+b
#
# Dependencies:
#   - rofi         : menu/prompt interface
#   - bluetoothctl : BlueZ command-line Bluetooth controller
#   - notify-send  : desktop notifications
#
# Usage:
#   ~/.config/rofi/scripts/rofi-bluetooth.sh
#
# Architecture:
#   main_menu()    -> top-level paired-device list + scan option
#   device_menu()  -> per-device action sub-menu (connect/disconnect/trust/remove)
#   Helper functions: power_on, get_paired_devices, get_device_mac, is_connected
#

THEME="$HOME/.config/rofi/themes/simple.rasi"

# power_on()
#   Ensures the Bluetooth adapter is powered on before any operation.
#   Checks the current power state and, if off, sends the power-on command
#   and waits 1 second for the adapter to initialize. This avoids confusing
#   errors when the user has Bluetooth disabled.
#
#   Parameters: none
#   Returns:    nothing (side effect: adapter powered on)
power_on() {
    if bluetoothctl show | grep -q "Powered: no"; then
        bluetoothctl power on > /dev/null
        sleep 1
    fi
}

# get_paired_devices()
#   Retrieves the human-readable names of all paired Bluetooth devices.
#   The raw output of "bluetoothctl devices Paired" looks like:
#       Device AA:BB:CC:DD:EE:FF My Headphones
#   We strip the "Device" keyword and the MAC address, keeping only the name.
#
#   Parameters: none
#   Output:     one device name per line to stdout
get_paired_devices() {
    bluetoothctl devices Paired 2>/dev/null | awk '{$1=""; $2=""; print substr($0,3)}'
}

# get_device_mac()
#   Looks up the MAC address for a paired device given its display name.
#
#   Parameters:
#     $1 - Device name (as returned by get_paired_devices)
#
#   Output:
#     The MAC address (e.g., "AA:BB:CC:DD:EE:FF") to stdout, or empty if
#     the device is not found.
get_device_mac() {
    local name="$1"
    bluetoothctl devices Paired 2>/dev/null | grep "$name" | awk '{print $2}'
}

# is_connected()
#   Checks whether a device (identified by MAC) is currently connected.
#
#   Parameters:
#     $1 - MAC address of the device
#
#   Returns:
#     0 (true) if connected, 1 (false) otherwise
is_connected() {
    local mac="$1"
    bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"
}

# main_menu()
#   Builds and displays the primary rofi menu. The menu always starts with
#   a "Scan for devices" entry, followed by each paired device annotated
#   with its connection status (an icon + optional "[connected]" tag).
#
#   Selecting "Scan" triggers a 5-second Bluetooth scan, then presents
#   discovered devices for pairing. Selecting a paired device delegates to
#   device_menu() for further actions.
main_menu() {
    # Ensure adapter is on before querying devices
    power_on

    local options="󰂰  Scan for devices\n"
    local paired
    paired=$(get_paired_devices)

    # Append each paired device with a status-indicating icon:
    # - 󰂱 (connected icon) + "[connected]" suffix for active connections
    # -  (generic bluetooth icon) for disconnected devices
    if [[ -n "$paired" ]]; then
        while IFS= read -r device; do
            local mac
            mac=$(get_device_mac "$device")
            if is_connected "$mac"; then
                options+="󰂱  $device [connected]\n"
            else
                options+="  $device\n"
            fi
        done <<< "$paired"
    fi

    local chosen
    chosen=$(echo -e "$options" | rofi -dmenu -theme "$THEME" -p "Bluetooth" -mesg "Bluetooth Devices")

    [[ -z "$chosen" ]] && exit 0

    if [[ "$chosen" == *"Scan"* ]]; then
        # --- Scan for new devices ---
        notify-send "Bluetooth" "Scanning for devices..." -t 3000

        # Start a background scan with a 5-second timeout. The scan runs
        # asynchronously so we sleep to give it time to discover devices.
        bluetoothctl --timeout 5 scan on > /dev/null 2>&1 &
        sleep 5

        # Retrieve ALL known devices (paired + newly discovered).
        # In practice, the new scan results get merged into the device list.
        local new_devices
        new_devices=$(bluetoothctl devices | awk '{$1=""; $2=""; print substr($0,3)}')

        if [[ -z "$new_devices" ]]; then
            notify-send "Bluetooth" "No devices found" -t 3000
            return
        fi

        local scan_chosen
        scan_chosen=$(echo "$new_devices" | rofi -dmenu -theme "$THEME" -p "Found" -mesg "Select device to pair")

        # Execute the full pair -> trust -> connect sequence on selection.
        # Trust is set so the device auto-connects in the future without
        # requiring manual authorization each time.
        if [[ -n "$scan_chosen" ]]; then
            local mac
            mac=$(bluetoothctl devices | grep "$scan_chosen" | awk '{print $2}')
            bluetoothctl pair "$mac" 2>/dev/null
            bluetoothctl trust "$mac" 2>/dev/null
            bluetoothctl connect "$mac" 2>/dev/null
            notify-send "Bluetooth" "Paired & connected: $scan_chosen" -t 3000
        fi
    else
        # --- Selected a paired device -> open device sub-menu ---
        # Strip the leading icon and trailing "[connected]" tag to recover
        # the raw device name for lookup.
        local device_name
        device_name=$(echo "$chosen" | sed 's/^[^ ]* *//' | sed 's/ \[connected\]$//')
        device_menu "$device_name"
    fi
}

# device_menu()
#   Shows a context-sensitive action menu for a specific paired device.
#   If the device is currently connected, offers Disconnect and Remove.
#   If disconnected, offers Connect, Trust, and Remove.
#
#   Parameters:
#     $1 - Device name (human-readable)
device_menu() {
    local name="$1"
    local mac
    mac=$(get_device_mac "$name")

    # Bail out if we cannot resolve the name to a MAC (device was removed?)
    [[ -z "$mac" ]] && return

    # Build a context-sensitive option list: connected devices can disconnect,
    # disconnected devices can connect or re-trust. Remove is always available.
    local options
    if is_connected "$mac"; then
        options="󰂲  Disconnect\n󰜺  Remove"
    else
        options="󰂱  Connect\n󰤾  Trust\n󰜺  Remove"
    fi

    local action
    action=$(echo -e "$options" | rofi -dmenu -theme "$THEME" -p "$name" -mesg "Device: $name")

    [[ -z "$action" ]] && return

    case "$action" in
        *"Connect"*)
            bluetoothctl connect "$mac" > /dev/null 2>&1
            # Verify the connection actually succeeded before reporting
            if is_connected "$mac"; then
                notify-send "Bluetooth" "Connected: $name" -t 3000
            else
                notify-send "Bluetooth" "Failed to connect: $name" -u critical -t 3000
            fi
            ;;
        *"Disconnect"*)
            bluetoothctl disconnect "$mac" > /dev/null 2>&1
            notify-send "Bluetooth" "Disconnected: $name" -t 3000
            ;;
        *"Trust"*)
            # Trusting a device means it will not prompt for authorization
            # on future connections.
            bluetoothctl trust "$mac" > /dev/null 2>&1
            notify-send "Bluetooth" "Trusted: $name" -t 3000
            ;;
        *"Remove"*)
            # Remove fully un-pairs the device; it will need to be scanned
            # and paired again to reconnect.
            bluetoothctl remove "$mac" > /dev/null 2>&1
            notify-send "Bluetooth" "Removed: $name" -t 3000
            ;;
    esac
}

# Entry point
main_menu
