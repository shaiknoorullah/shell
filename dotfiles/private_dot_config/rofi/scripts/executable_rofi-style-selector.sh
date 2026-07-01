#!/usr/bin/env bash
#
# rofi-style-selector.sh — Switch between rofi launcher styles
#
# Scans theme files for launcher styles, shows preview grid,
# saves selection to style.conf.

ROFI_DIR="$HOME/.config/rofi"
THEME_DIR="$ROFI_DIR/themes"
ASSET_DIR="$THEME_DIR/assets"
CONF_FILE="$ROFI_DIR/style.conf"

# Read current style
[[ -f "$CONF_FILE" ]] && source "$CONF_FILE"

# Font override
font_override='* {font: "JetBrainsMono Nerd Font 10";}'

# Get monitor width for column calculation
mon_width=$(xrandr --query | grep ' connected primary' | grep -oP '\d+(?=x)' | head -1)
mon_width=${mon_width:-1920}
col_count=$(( mon_width / 400 ))
[[ $col_count -gt 5 ]] && col_count=5

r_override="window{width:100%;}
    listview{columns:$col_count;}
    element{orientation:vertical;border-radius:16px;}
    element-icon{border-radius:12px;size:20em;}
    element-text{enabled:false;}"

# Build entries: scan for launcher-attributed themes
entries=""
for file in "$THEME_DIR"/style_*.rasi "$THEME_DIR"/launchpad.rasi; do
    [[ -f "$file" ]] || continue
    base=$(basename "$file" .rasi)
    asset="$ASSET_DIR/$base.png"
    if [[ -f "$asset" ]]; then
        entries+="$base\x00icon\x1f$asset\n"
    else
        entries+="$base\n"
    fi
done

chosen=$(echo -en "$entries" | sort -V | rofi -dmenu \
    -theme-str "$font_override" \
    -theme-str "$r_override" \
    -theme "$THEME_DIR/selector" \
    -select "$rofiStyle" \
    -p "Style")

if [[ -n "$chosen" ]]; then
    echo "rofiStyle=$chosen" > "$CONF_FILE"
    notify-send "Rofi Style" "Switched to $chosen" -t 2000 \
        -i "$ASSET_DIR/$chosen.png" 2>/dev/null
fi
