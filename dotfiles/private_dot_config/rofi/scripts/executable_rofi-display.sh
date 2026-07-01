#!/usr/bin/env bash
#
# rofi-display.sh -- Multi-Monitor Display Layout Manager
#
# Description:
#   Detects connected monitors via xrandr and presents a rofi menu with
#   layout options. Supports single-display setups (gracefully exits with
#   a notification) and dual-display setups with six layout modes: laptop
#   only, external only, mirror, extend left, extend right, and auto-detect.
#
#   The first connected output is assumed to be the laptop's built-in
#   display; the second is the external monitor. The menu dynamically
#   includes the output names (e.g., "eDP-1", "HDMI-1") so the user can
#   see exactly which physical display corresponds to which option.
#
# Keybinding: $mod+Shift+m
#
# Dependencies:
#   - rofi        : menu/prompt interface
#   - xrandr      : X11 display configuration tool
#   - notify-send : desktop notifications
#
# Usage:
#   ~/.config/rofi/scripts/rofi-display.sh
#

THEME="$HOME/.config/rofi/themes/simple.rasi"

# get_outputs()
#   Queries xrandr for all physically connected outputs.
#
#   Output:
#     One output name per line (e.g., "eDP-1", "HDMI-1") to stdout.
#
#   Note: "connected" (with a leading space) is matched to avoid false
#   positives on "disconnected" lines.
get_outputs() {
    xrandr --query | grep " connected" | awk '{print $1}'
}

# Capture output names into an array for indexed access
outputs=($(get_outputs))
num_outputs=${#outputs[@]}

# Guard: no outputs means something is very wrong (no display server?)
if [[ $num_outputs -lt 1 ]]; then
    notify-send "Display" "No displays detected" -u critical
    exit 1
fi

# Assume the first output is the laptop's integrated display
laptop="${outputs[0]}"

# With only one display connected, there is nothing to configure
if [[ $num_outputs -eq 1 ]]; then
    notify-send "Display" "Only one display connected: $laptop" -t 3000
    exit 0
fi

# The second output is the external monitor
external="${outputs[1]}"

# Build the options list, embedding actual output names for clarity
options="󰍹  Laptop Only ($laptop)\n󰍹  External Only ($external)\n󰍺  Mirror\n  Extend Left\n  Extend Right\n󰕥  Auto Detect"

chosen=$(echo -e "$options" | rofi -dmenu -theme "$THEME" -p "Display" -mesg "Outputs: $laptop + $external")

[[ -z "$chosen" ]] && exit 0

# Apply the selected layout via xrandr.
# --auto lets xrandr pick the preferred resolution/refresh rate for each output.
# --primary ensures desktop panels and new windows appear on the intended screen.
case "$chosen" in
    *"Laptop Only"*)
        # Use only the laptop display; turn off the external
        xrandr --output "$laptop" --auto --primary --output "$external" --off
        ;;
    *"External Only"*)
        # Use only the external display; turn off the laptop panel
        xrandr --output "$external" --auto --primary --output "$laptop" --off
        ;;
    *"Mirror"*)
        # Both displays show the same content (--same-as clones the framebuffer)
        xrandr --output "$laptop" --auto --primary --output "$external" --auto --same-as "$laptop"
        ;;
    *"Extend Left"*)
        # External monitor sits to the LEFT of the laptop display
        xrandr --output "$laptop" --auto --primary --output "$external" --auto --left-of "$laptop"
        ;;
    *"Extend Right"*)
        # External monitor sits to the RIGHT of the laptop display
        xrandr --output "$laptop" --auto --primary --output "$external" --auto --right-of "$laptop"
        ;;
    *"Auto"*)
        # Let xrandr auto-configure all connected outputs with preferred modes
        xrandr --auto
        ;;
esac

notify-send "Display" "Layout changed" -t 3000
