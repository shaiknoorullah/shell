#!/usr/bin/env bash
#
# rofi-media.sh — Media playback controls via playerctl
#
# Description:
#   Displays a rofi dmenu with 5 media control actions (previous, play/pause,
#   next, shuffle, loop) using Nerd Font icons. The currently playing track's
#   artist and title are shown in rofi's message bar, giving quick "now playing"
#   feedback without needing a full media player window.
#
# Keybinding: $mod+m (defined in i3 config)
#
# Dependencies:
#   - rofi       : menu launcher (dmenu mode)
#   - playerctl  : MPRIS-compatible media player controller (works with
#                  Spotify, Firefox, VLC, mpd via playerctld, etc.)
#
# Usage:
#   ~/.config/rofi/scripts/rofi-media.sh
#
# Notes:
#   playerctl communicates with whichever MPRIS player is currently active.
#   If multiple players are running, playerctld determines priority. Stderr
#   is suppressed in get_track_info() so the menu still works when no
#   player is running — it just shows "Unknown - No Track".

# Path to the dedicated rofi theme for the media controls menu
THEME="$HOME/.config/rofi/themes/clipboard.rasi"

# get_track_info — Retrieves the currently playing track's artist and title.
#
# Queries playerctl for MPRIS metadata. Stderr is redirected to /dev/null
# because playerctl exits non-zero when no player is running, and we want
# graceful fallback strings rather than error messages leaking into the menu.
#
# Parameters: none
#
# Returns (stdout):
#   A string in the format "Artist - Title", or fallback values if no
#   player is available (e.g. "Unknown - No Track").
get_track_info() {
    local artist title
    artist=$(playerctl metadata artist 2>/dev/null || echo "Unknown")
    title=$(playerctl metadata title 2>/dev/null || echo "No Track")
    echo "$artist - $title"
}

# --------------------------------------------------------------------------
# Menu options — Nerd Font icons for each media action.
# --------------------------------------------------------------------------
prev="󰒮"
play_pause="󰐎"
next="󰒭"
shuffle="󰒟"
loop="󰑖"

# Fetch track info before showing the menu so the message bar reflects the
# current state at the moment the menu opens.
track_info=$(get_track_info)
options="$prev\n$play_pause\n$next\n$shuffle\n$loop"

# Launch rofi. -selected-row 1 pre-highlights play/pause since it is the
# most frequently used action, letting the user toggle playback with a
# single Enter press.
chosen=$(echo -e "$options" | rofi -dmenu -theme "$THEME" -p "Media" -mesg "$track_info" -selected-row 1)

# --------------------------------------------------------------------------
# Action dispatch — send the corresponding playerctl command.
# --------------------------------------------------------------------------
case "$chosen" in
    "$prev")        playerctl previous ;;
    "$play_pause")  playerctl play-pause ;;
    "$next")        playerctl next ;;
    "$shuffle")     playerctl shuffle toggle ;;
    "$loop")        playerctl loop ;;
esac
