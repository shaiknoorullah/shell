#!/usr/bin/env bash
#
# rofi-keybindings.sh — i3 keybinding cheat sheet viewer
#
# Description:
#   Parses the i3 config file for all bindsym lines and displays them in a
#   rofi list with pango markup formatting. Keys are shown in bold purple
#   (Catppuccin Mauve #CBA6F7) and commands in dimmed gray (Catppuccin
#   Subtext0 #A6ADC8). This is a read-only reference — selecting a row
#   does nothing, so users can browse safely.
#
# Keybinding: $mod+F2 (defined in i3 config)
#
# Dependencies:
#   - rofi        : menu launcher (dmenu mode with -markup-rows)
#   - grep        : filters bindsym lines from the i3 config
#   - awk         : splits key from command and applies pango markup
#   - sed         : strips leading whitespace and noise strings
#   - notify-send : error notification if config is missing
#
# Usage:
#   ~/.config/rofi/scripts/rofi-keybindings.sh
#
# Notes:
#   The script only parses top-level bindsym lines. Bindings inside mode
#   blocks (e.g. resize mode) are included as well since they also start
#   with "bindsym". The "--no-startup-id" exec flag is stripped because
#   it's just i3 boilerplate and adds visual noise to the listing.

# Path to the dedicated rofi theme for the keybindings viewer
THEME="$HOME/.config/rofi/themes/clipboard.rasi"

# Path to the i3 window manager config file
I3_CONFIG="$HOME/.config/i3/config"

# Guard: exit early if the i3 config doesn't exist (e.g. running on a
# different WM or a fresh install).
if [[ ! -f "$I3_CONFIG" ]]; then
    notify-send "Error" "i3 config not found" -u critical
    exit 1
fi

# --------------------------------------------------------------------------
# Parse and format keybindings
#
# Pipeline breakdown:
#   1. grep    — extract only lines that define key bindings (bindsym)
#   2. sed #1  — remove the "bindsym" keyword and leading whitespace
#   3. sed #2  — remove "--no-startup-id" noise from exec commands
#   4. awk     — split the first field (key combo) from the rest (command),
#                escape HTML/pango special characters (&, <, >) to prevent
#                markup injection, then wrap each part in colored <span> tags.
#
# Pango markup is used instead of plain text because rofi's -markup-rows
# flag enables rich formatting, letting us visually distinguish keys from
# their commands at a glance. The 28-character field width for keys ensures
# columns stay aligned even with long modifier chains like $mod+Shift+Ctrl.
# --------------------------------------------------------------------------
bindings=$(grep -E '^\s*bindsym' "$I3_CONFIG" | \
    sed 's/^\s*bindsym\s*//' | \
    sed 's/--no-startup-id //' | \
    awk '{
        key = $1;
        $1 = "";
        cmd = substr($0, 2);
        # Escape XML/pango special characters to prevent markup breakage
        # when keys or commands contain &, <, or > (e.g. ">" in exec commands)
        gsub(/&/, "\\&amp;", key);
        gsub(/&/, "\\&amp;", cmd);
        gsub(/</, "\\&lt;", key);
        gsub(/</, "\\&lt;", cmd);
        gsub(/>/, "\\&gt;", key);
        gsub(/>/, "\\&gt;", cmd);
        printf "<b><span color=\"#CBA6F7\">%-28s</span></b> <span color=\"#A6ADC8\">%s</span>\n", key, cmd;
    }')

# Display the formatted keybindings in rofi. This is purely informational —
# selecting a row simply closes the menu without triggering any action.
echo -e "$bindings" | rofi -dmenu -theme "$THEME" -p "Keys" -markup-rows -mesg "i3 Keybindings (read-only)"
