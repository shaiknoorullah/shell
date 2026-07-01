#!/usr/bin/env bash
#
# rofi-wallpaper-slider.sh — Horizontal wallpaper browser
#
# Shows wallpaper thumbnails in a horizontal grid using dmenu mode.
# Enter applies the wallpaper and closes. Escape reverts to original.
#
# Usage: rofi-wallpaper-slider.sh <category>
#   category: subdirectory name under ~/walls/

ROFI_DIR="$HOME/.config/rofi"
THEME_DIR="$ROFI_DIR/themes"
WALL_DIR="$HOME/walls"
CACHE_DIR="$HOME/.cache/rofi-wallpaper"
CATEGORY="$1"

if [[ -z "$CATEGORY" || ! -d "$WALL_DIR/$CATEGORY" ]]; then
    notify-send "Error" "Invalid category: $CATEGORY" -u critical
    exit 1
fi

CAT_DIR="$WALL_DIR/$CATEGORY"
THUMB_DIR="$CACHE_DIR/thumbs/$CATEGORY"
mkdir -p "$THUMB_DIR"

# Save current wallpaper for revert on Escape
ORIGINAL_WALL=""
if [[ -f "$HOME/.fehbg" ]]; then
    ORIGINAL_WALL=$(grep -oP "(?<='|\")\S+\.(jpg|jpeg|png|webp|bmp)(?='|\")" "$HOME/.fehbg" | head -1)
fi

# Generate thumbnails for all wallpapers in category
for img in "$CAT_DIR"/*.{jpg,jpeg,png,webp,bmp,JPG,JPEG,PNG,WEBP,BMP}; do
    [[ -f "$img" ]] || continue
    base=$(basename "$img")
    thumb="$THUMB_DIR/$base"
    if [[ ! -f "$thumb" ]]; then
        convert "$img" -resize 300x169^ -gravity center -extent 300x169 "$thumb" 2>/dev/null
    fi
done

# Build sorted entries with thumbnails
entries=""
for img in "$CAT_DIR"/*.{jpg,jpeg,png,webp,bmp,JPG,JPEG,PNG,WEBP,BMP}; do
    [[ -f "$img" ]] || continue
    base=$(basename "$img")
    thumb="$THUMB_DIR/$base"
    if [[ -f "$thumb" ]]; then
        entries+="$base\x00icon\x1f$thumb\n"
    else
        entries+="$base\n"
    fi
done

# Launch rofi in dmenu mode with thumbnails
chosen=$(echo -en "$entries" | sort -V | rofi -dmenu \
    -theme "$THEME_DIR/wallpaper-slider" \
    -theme-str 'configuration {show-icons: true;}' \
    -show-icons \
    -p "$CATEGORY" \
    -mesg "Enter: apply | Esc: cancel")

# Handle result
if [[ -n "$chosen" ]]; then
    feh --bg-fill "$CAT_DIR/$chosen"
    notify-send "Wallpaper Set" "$CATEGORY/$chosen" -t 3000
else
    # Revert on Escape
    if [[ -n "$ORIGINAL_WALL" && -f "$ORIGINAL_WALL" ]]; then
        feh --bg-fill "$ORIGINAL_WALL"
    fi
fi
