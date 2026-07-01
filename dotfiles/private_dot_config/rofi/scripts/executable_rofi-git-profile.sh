#!/usr/bin/env bash
#
# rofi-git-profile.sh — Git identity switcher
#
# Description:
#   Reads git profiles from a pipe-delimited config file and presents them
#   in a rofi dmenu. Selecting a profile sets the global git user.name and
#   user.email to match. This is useful for developers who work across
#   multiple identities (e.g. personal GitHub, work GitLab, client repos)
#   and need a quick way to switch without manually editing ~/.gitconfig.
#
# Keybinding: $mod+g (defined in i3 config)
#
# Dependencies:
#   - rofi        : menu launcher (dmenu mode)
#   - git         : for setting global config values
#   - notify-send : success/error notifications (typically via dunst)
#
# Usage:
#   ~/.config/rofi/scripts/rofi-git-profile.sh
#
# Profile config format (git-profiles.conf):
#   Each line is:  label|username|email
#   Example:
#     Personal|janedoe|jane@personal.dev
#     Work|Jane Doe|jane.doe@company.com
#   Lines starting with '#' are treated as comments and skipped.
#   Empty lines are also skipped.

# Path to the dedicated rofi theme for the git profile picker
THEME="$HOME/.config/rofi/themes/simple.rasi"

# Path to the profiles config file. Lives alongside this script so all
# rofi script data is co-located in ~/.config/rofi/scripts/.
PROFILES_FILE="$HOME/.config/rofi/scripts/git-profiles.conf"
[[ ! -f "$PROFILES_FILE" ]] && PROFILES_FILE="$HOME/.config/rofi/scripts/git-profiles.example.conf"

# Guard: exit early if the profiles config doesn't exist.
if [[ ! -f "$PROFILES_FILE" ]]; then
    notify-send "Error" "Git profiles config not found: $PROFILES_FILE" -u critical
    exit 1
fi

# --------------------------------------------------------------------------
# Build the menu options from the profiles config file.
#
# IFS='|' splits each line on the pipe delimiter into three fields.
# Lines that are empty or start with '#' are skipped (comment support).
# Each menu entry shows the label followed by the full identity in
# parentheses, e.g.:  "Personal (janedoe <jane@personal.dev>)"
# This format is used both for display AND for matching the selection
# back to the original profile in the dispatch loop below.
# --------------------------------------------------------------------------
options=""
while IFS='|' read -r name user email; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    options+="$name ($user <$email>)\n"
done < "$PROFILES_FILE"

# If no valid profiles were found (e.g. file is empty or all comments),
# notify and exit gracefully.
if [[ -z "$options" ]]; then
    notify-send "Git Profile" "No profiles configured" -u normal
    exit 0
fi

chosen=$(echo -e "$options" | rofi -dmenu -theme "$THEME" -p "Git Profile" -mesg "Select git identity")

if [[ -n "$chosen" ]]; then
    # --------------------------------------------------------------------------
    # Match the selected menu entry back to its profile data.
    #
    # We re-read the profiles file and reconstruct the display string for each
    # entry, comparing it to the user's selection. This approach avoids fragile
    # string parsing (e.g. extracting the email from angle brackets) and ensures
    # an exact match even if usernames or emails contain special characters.
    # Once matched, we set both git config values globally (--global writes to
    # ~/.gitconfig) so all subsequent git operations use the new identity.
    # --------------------------------------------------------------------------
    while IFS='|' read -r name user email; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        if [[ "$chosen" == "$name ($user <$email>)" ]]; then
            git config --global user.name "$user"
            git config --global user.email "$email"
            notify-send "Git Profile" "Switched to: $user <$email>" -t 3000
            break
        fi
    done < "$PROFILES_FILE"
fi
