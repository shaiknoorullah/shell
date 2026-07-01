#!/usr/bin/env bash
#
# rofilaunch.sh — Main launcher with dynamic style + wallpaper
#
# Reads style from ~/.config/rofi/style.conf, extracts current wallpaper
# from ~/.fehbg, generates HyDE-compatible wallpaper cache variants,
# and launches rofi with runtime overrides.
#
# Usage: rofilaunch.sh [d|w|f|r]
#   d/--drun       : Application launcher (default)
#   w/--window     : Window switcher
#   f/--filebrowser: File browser
#   r/--run        : Run command

# Kill existing rofi instance (toggle behavior)
pkill rofi && exit 0

ROFI_DIR="$HOME/.config/rofi"
THEME_DIR="$ROFI_DIR/themes"
CONF_FILE="$ROFI_DIR/style.conf"
CACHE_DIR="$HOME/.cache/hyde"

# Read saved style preference
if [[ -f "$CONF_FILE" ]]; then
    source "$CONF_FILE"
fi
rofi_style="${rofiStyle:-style_1}"

# Determine mode
case "$1" in
    d|--drun)     r_mode="drun" ;;
    w|--window)   r_mode="window" ;;
    f|--filebrowser) r_mode="filebrowser" ;;
    r|--run)      r_mode="run" ;;
    *)            r_mode="drun" ;;
esac

# Extract current wallpaper path from feh's saved state
wall_path=""
if [[ -f "$HOME/.fehbg" ]]; then
    wall_path=$(grep -oP "(?<='|\")\S+\.(jpg|jpeg|png|webp|bmp)(?='|\")" "$HOME/.fehbg" | head -1)
fi

# Generate HyDE-compatible wallpaper cache variants
# Styles reference: wall.blur, wall.thmb, wall.sqre, wall.quad
generate_wall_cache() {
    local src="$1"
    mkdir -p "$CACHE_DIR"

    # Track source wallpaper to avoid regenerating
    local stamp="$CACHE_DIR/.wall_source"
    if [[ -f "$stamp" ]] && [[ "$(cat "$stamp")" == "$src" ]] && [[ -f "$CACHE_DIR/wall.blur" ]]; then
        return
    fi

    if command -v convert &>/dev/null; then
        # wall.blur — gaussian-blurred version (frosted glass effect behind text)
        convert "$src" -resize 1920x1080^ -gravity center -extent 1920x1080 \
            -blur 0x14 "$CACHE_DIR/wall.blur" 2>/dev/null &
        # wall.thmb — thumbnail version
        convert "$src" -resize 960x540^ -gravity center -extent 960x540 \
            "$CACHE_DIR/wall.thmb" 2>/dev/null &
        # wall.sqre — square crop
        convert "$src" -resize 540x540^ -gravity center -extent 540x540 \
            "$CACHE_DIR/wall.sqre" 2>/dev/null &
        # wall.quad — 2x2 tiled version
        convert "$src" -resize 480x270^ -gravity center -extent 480x270 \
            \( +clone \) +append \( +clone \) -append \
            "$CACHE_DIR/wall.quad" 2>/dev/null &
        wait
    else
        # Fallback: just copy the original for all variants
        for variant in wall.blur wall.thmb wall.sqre wall.quad; do
            cp "$src" "$CACHE_DIR/$variant" 2>/dev/null
        done
    fi

    echo "$src" > "$stamp"
}

if [[ -n "$wall_path" && -f "$wall_path" ]]; then
    generate_wall_cache "$wall_path"
fi

# Border radius from picom (read corner-radius or default to 8)
border_radius=8
if [[ -f "$HOME/.config/picom/picom.conf" ]]; then
    br=$(grep -oP 'corner-radius\s*=\s*\K[0-9]+' "$HOME/.config/picom/picom.conf" 2>/dev/null)
    [[ -n "$br" ]] && border_radius=$br
fi
elem_border=$((border_radius * 2))
r_override="window {border: 0px; border-radius: ${border_radius}px;} element {border-radius: ${elem_border}px;}"

# Font override
font_override="* {font: \"JetBrainsMono Nerd Font 10\";}"

# Icon theme override
i_override="configuration {icon-theme: \"Adwaita\";}"

rofi -show "$r_mode" \
    -show-icons \
    -theme-str "$font_override" \
    -theme-str "$i_override" \
    -theme-str "$r_override" \
    -theme "$THEME_DIR/$rofi_style" &
disown
