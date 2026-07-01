#!/usr/bin/env bash
#
# rofi-clipboard.sh — Clipboard history manager via greenclip
#
# Description:
#   A thin wrapper that integrates greenclip (a clipboard history daemon)
#   with rofi's custom modi feature. It ensures the greenclip daemon is
#   running, then launches rofi with greenclip as a custom clipboard modi.
#   Selecting an entry from the history pastes it back to the clipboard.
#
# Keybinding: $mod+c (defined in i3 config)
#
# Dependencies:
#   - rofi      : menu launcher (custom modi mode)
#   - greenclip : clipboard history daemon for X11. Config lives at
#                 ~/.config/greenclip.toml (history size, excluded apps, etc.)
#
# Usage:
#   ~/.config/rofi/scripts/rofi-clipboard.sh
#
# Notes:
#   greenclip must be running as a background daemon to record clipboard
#   history. This script auto-starts it if it's not already running, but
#   for best results greenclip should be started in the i3 config with:
#     exec --no-startup-id greenclip daemon
#   The "clipboard:greenclip print" modi syntax tells rofi to use
#   "greenclip print" as the command backing the "clipboard" tab.

# Path to the dedicated rofi theme for the clipboard manager
THEME="$HOME/.config/rofi/themes/clipboard.rasi"

# Ensure the greenclip daemon is running before opening the menu.
# pgrep -x matches the exact process name to avoid false positives.
# If the daemon isn't running, we start it in the background and sleep
# briefly to give it time to initialize and load its history file before
# rofi tries to query it. Without this delay, the first launch after boot
# could show an empty history.
if ! pgrep -x greenclip > /dev/null; then
    greenclip daemon &
    sleep 0.5
fi

# Launch rofi with greenclip as a custom modi.
# -modi "clipboard:greenclip print" registers a custom tab called "clipboard"
# that pipes its entries through "greenclip print". When the user selects
# an entry, greenclip copies it back to the active clipboard selection.
# -show clipboard tells rofi to open directly on the clipboard tab.
rofi -modi "clipboard:greenclip print" -show clipboard -theme "$THEME"
