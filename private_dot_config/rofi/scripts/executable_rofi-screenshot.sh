#!/usr/bin/env bash
#
# rofi-screenshot.sh — Wayland screenshot (grim + slurp + wl-copy).
# Ported from the old X11 version (maim/xclip/xdotool), which produced black
# images on Hyprland. STOPGAP until the native caelestia screenshot widget
# (Phase 2) lands; see dotfiles/docs/superpowers/specs/*caelestia*screenshot*.
#
set -euo pipefail

THEME="$HOME/.config/rofi/themes/clipboard.rasi"
SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"
FILE="$SAVE_DIR/screenshot-$(date +%Y%m%d-%H%M%S).png"

fullscreen="󰍹"; area="󰩭"; window="󰖯"
chosen=$(printf '%s\n%s\n%s' "$fullscreen" "$area" "$window" \
    | rofi -dmenu -theme "$THEME" -p "Screenshot" -mesg "Select Mode")

case "$chosen" in
    "$fullscreen")
        sleep 0.3
        grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" "$FILE"
        ;;
    "$area")
        geom=$(slurp) || exit 0     # user cancelled the selection
        grim -g "$geom" "$FILE"
        ;;
    "$window")
        geom=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        grim -g "$geom" "$FILE"
        ;;
    *) exit 0 ;;                     # Esc / empty selection
esac

if [ ! -s "$FILE" ]; then
    notify-send -u critical "Screenshot failed" "grim produced no output"
    exit 1
fi

wl-copy < "$FILE"
notify-send -i "$FILE" "Screenshot taken" "Saved to $FILE and copied to clipboard"
