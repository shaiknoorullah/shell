#!/usr/bin/env bash
#
# rofi-power.sh — Power menu for i3wm
#
# Description:
#   Presents a rofi dmenu with 5 power actions (shutdown, reboot, lock,
#   suspend, logout) using Nerd Font icons. Destructive actions (shutdown,
#   reboot, logout) require a Yes/No confirmation prompt to prevent
#   accidental triggers.
#
# Keybinding: $mod+Shift+e (defined in i3 config)
#
# Dependencies:
#   - rofi       : menu launcher (dmenu mode)
#   - systemctl  : shutdown, reboot, suspend (systemd)
#   - i3lock     : screen locking
#   - i3-msg     : logout from i3 session
#
# Usage:
#   ~/.config/rofi/scripts/rofi-power.sh
#
# Theme:
#   Uses the option-menu style power.rasi theme, which renders a small
#   centered grid of icon-only buttons rather than a full-width list.

# Path to the dedicated rofi theme for the power menu
THEME="$HOME/.config/rofi/themes/clipboard.rasi"

# --------------------------------------------------------------------------
# Menu options — each variable holds a single Nerd Font icon.
# Using variables rather than inline strings so the case statement can
# match the user's selection against the exact icon shown in the menu.
# --------------------------------------------------------------------------
shutdown="⏻"
reboot=$'\uf0e2'
lock=$'\uf023'
suspend="⏾"
logout="󰍃"

# Build the newline-separated list of options for rofi
options="$shutdown\n$reboot\n$lock\n$suspend\n$logout"

# Launch rofi in dmenu mode. -selected-row 2 pre-highlights "lock" (the
# safest/most common action) so that pressing Enter without navigating
# won't accidentally trigger shutdown or reboot.
chosen=$(echo -e "$options" | rofi -dmenu -theme "$THEME" -p "Power" -mesg "Power Menu" -selected-row 2)

# confirm_action — Prompts the user with a Yes/No confirmation dialog.
#
# This exists to guard destructive operations (shutdown, reboot, logout)
# against accidental selection. A second rofi dmenu appears asking the
# user to explicitly choose "Yes" before proceeding.
#
# Parameters:
#   $1 — The confirmation message to display (e.g. "Shutdown?")
#
# Returns:
#   0 (true)  if the user selected "Yes"
#   1 (false) otherwise (including dismissing the dialog)
confirm_action() {
    local answer
    answer=$(echo -e "Yes\nNo" | rofi -dmenu -theme "$THEME" -p "Confirm" -mesg "$1")
    [[ "$answer" == "Yes" ]]
}

# --------------------------------------------------------------------------
# Action dispatch — match the selected icon to its corresponding action.
# Lock and suspend are considered safe enough to execute immediately;
# shutdown, reboot, and logout go through confirm_action first.
# --------------------------------------------------------------------------
case "$chosen" in
    "$shutdown")
        confirm_action "Shutdown?" && systemctl poweroff
        ;;
    "$reboot")
        confirm_action "Reboot?" && systemctl reboot
        ;;
    "$lock")
        # Lock the screen with a solid color matching the Catppuccin Mocha
        # base color (#1E1E2E) so the lock screen blends with the theme.
        hyprlock
        ;;
    "$suspend")
        systemctl suspend
        ;;
    "$logout")
        confirm_action "Logout?" && hyprctl dispatch exit
        ;;
esac
