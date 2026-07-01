#!/usr/bin/env bash
# generate-previews.sh — Screenshot each rofi style for the selector
#
# Run this manually with a display active. It will open each style,
# screenshot it, and save to themes/assets/.

ROFI_DIR="$HOME/.config/rofi"
ASSET_DIR="$ROFI_DIR/themes/assets"
ORIG_STYLE=$(cat "$ROFI_DIR/style.conf" 2>/dev/null)

mkdir -p "$ASSET_DIR"

for i in $(seq 1 12); do
    echo "Capturing style_$i..."
    echo "rofiStyle=style_$i" > "$ROFI_DIR/style.conf"
    "$ROFI_DIR/scripts/rofilaunch.sh" d &
    sleep 2
    maim "$ASSET_DIR/style_$i.png"
    pkill rofi
    sleep 0.5
done

# Launchpad
echo "Capturing launchpad..."
rofi -show drun -theme "$ROFI_DIR/themes/launchpad.rasi" &
sleep 2
maim "$ASSET_DIR/launchpad.png"
pkill rofi

# Restore original style
echo "$ORIG_STYLE" > "$ROFI_DIR/style.conf"

echo "Done! Generated $(ls "$ASSET_DIR"/*.png 2>/dev/null | wc -l) preview images."
