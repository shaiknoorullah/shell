#!/usr/bin/env bash
#
# rofi-tmux.sh -- Tmux Session Manager
#
# Description:
#   Rofi-based interface for managing tmux sessions. Provides three core
#   actions: list/attach to existing sessions, create new named sessions,
#   and kill running sessions. Intelligently detects whether it is being
#   invoked from inside an existing tmux session and adjusts its behavior
#   accordingly (switch-client vs attach, and whether to spawn a new
#   terminal window).
#
# Keybinding: $mod+t
#
# Dependencies:
#   - rofi        : menu/prompt interface
#   - tmux        : terminal multiplexer (the managed application)
#   - kitty       : terminal emulator (used to open tmux when not already inside tmux)
#   - notify-send : desktop notifications for user feedback
#
# Usage:
#   ~/.config/rofi/scripts/rofi-tmux.sh
#
# Flow:
#   1. Display all current tmux sessions (with window count and attached status)
#      plus two special actions: "+ New Session" and "Kill Session".
#   2. Based on user selection:
#      a. New Session  -> prompt for a name, then create and attach/switch.
#      b. Kill Session -> show a sub-menu of sessions to kill.
#      c. Existing     -> attach or switch to that session.
#

THEME="$HOME/.config/rofi/themes/simple.rasi"

# get_sessions()
#   Builds the list of items to display in the rofi menu.
#   - Queries tmux for running sessions, formatting each as:
#       "<name> (<N> windows) [attached]"
#     The "[attached]" tag only appears if someone is already attached.
#   - Appends two fixed action entries at the bottom: create and kill.
#   Outputs one line per menu entry to stdout.
get_sessions() {
    local sessions
    sessions=$(tmux list-sessions -F "#{session_name} (#{session_windows} windows) #{?session_attached,[attached],}" 2>/dev/null)

    if [[ -n "$sessions" ]]; then
        echo "$sessions"
    fi
    echo "+ New Session"
    echo " Kill Session"
}

# Present the main rofi menu populated by get_sessions()
chosen=$(get_sessions | rofi -dmenu -theme "$THEME" -p "Tmux" -mesg "Tmux Sessions")

# Exit silently if the user dismissed the menu without choosing
[[ -z "$chosen" ]] && exit 0

if [[ "$chosen" == "+ New Session" ]]; then
    # --- Create a new session ---
    # Prompt the user for a session name (-lines 0 hides the list area,
    # turning rofi into a pure text-input dialog).
    session_name=$(rofi -dmenu -theme "$THEME" -p "Name" -mesg "Enter session name" -lines 0)
    if [[ -n "$session_name" ]]; then
        # If we are already inside tmux ($TMUX is set), we cannot nest
        # "tmux new-session" directly -- it would fail with "sessions should
        # be nested with care". Instead, create the session detached (-d)
        # and then switch the current client to it.
        if [[ -n "$TMUX" ]]; then
            tmux new-session -d -s "$session_name" && tmux switch-client -t "$session_name"
        else
            # Not inside tmux: spawn a new kitty terminal running the new
            # tmux session. Backgrounded so this script exits immediately.
            kitty -e tmux new-session -s "$session_name" &
        fi
        notify-send "Tmux" "Created session: $session_name" -t 3000
    fi
elif [[ "$chosen" == " Kill Session" ]]; then
    # --- Kill an existing session ---
    # Fetch bare session names (no window counts or status) for a clean
    # selection list.
    sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    if [[ -z "$sessions" ]]; then
        notify-send "Tmux" "No sessions to kill" -t 3000
        exit 0
    fi
    target=$(echo "$sessions" | rofi -dmenu -theme "$THEME" -p "Kill" -mesg "Select session to kill")
    if [[ -n "$target" ]]; then
        tmux kill-session -t "$target"
        notify-send "Tmux" "Killed session: $target" -t 3000
    fi
else
    # --- Attach to an existing session ---
    # The chosen string starts with the session name, followed by metadata
    # in parentheses. Extract just the first word (the name).
    session_name=$(echo "$chosen" | awk '{print $1}')
    # Same inside-tmux logic as the create path: switch-client if nested,
    # otherwise open a new kitty terminal and attach.
    if [[ -n "$TMUX" ]]; then
        tmux switch-client -t "$session_name"
    else
        kitty -e tmux attach-session -t "$session_name" &
    fi
fi
