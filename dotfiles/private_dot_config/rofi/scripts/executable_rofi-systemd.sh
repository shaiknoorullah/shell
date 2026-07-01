#!/usr/bin/env bash
#
# rofi-systemd.sh -- Systemd Service Manager
#
# Description:
#   Lists all loaded systemd services in a rofi menu with color-coded status
#   indicators using Pango markup. Active services show a green dot, inactive
#   show red, and any other state (activating, deactivating, failed, etc.)
#   shows yellow. After selecting a service, a sub-menu offers four actions:
#   start, stop, restart (all via pkexec for privilege elevation), or view
#   live logs in a new kitty terminal window.
#
# Keybinding: $mod+Shift+p
#
# Dependencies:
#   - rofi        : menu/prompt interface (must support -markup-rows for Pango)
#   - systemctl   : queries and controls systemd services
#   - pkexec      : PolicyKit privilege escalation (prompts for password)
#   - kitty       : terminal emulator (for viewing live logs)
#   - journalctl  : reads systemd journal logs
#   - notify-send : desktop notifications
#
# Usage:
#   ~/.config/rofi/scripts/rofi-systemd.sh
#
# Notes:
#   - Colors follow the Catppuccin Mocha palette.
#   - pkexec is used instead of sudo because this script runs from a
#     graphical context (rofi) where there is no terminal for sudo's
#     password prompt.
#

THEME="$HOME/.config/rofi/themes/simple.rasi"

# list_services()
#   Queries systemd for all loaded service units and formats each one as a
#   Pango-marked-up string for rofi's -markup-rows mode.
#
#   Output format per line:
#     <colored dot> <bold service name> <dimmed [sub-state]>
#
#   The sub-state (e.g., "running", "exited", "dead") provides more detail
#   than just the active/inactive distinction.
#
#   Parameters: none
#   Output:     Pango markup lines to stdout
list_services() {
    # --no-pager  : do not pipe through less
    # --no-legend : suppress the summary footer line
    # --plain     : disable tree/hierarchy formatting
    systemctl list-units --type=service --no-pager --no-legend --plain | \
    while read -r unit load active sub _; do
        [[ -z "$unit" ]] && continue
        # Strip the ".service" suffix for a cleaner display name
        local name="${unit%.service}"
        # Color-code the status dot (Catppuccin Mocha palette):
        #   Green  (#A6E3A1) = active
        #   Red    (#F38BA8) = inactive
        #   Yellow (#F9E2AF) = any transitional or error state
        local color
        case "$active" in
            active)   color="#A6E3A1" ;;
            inactive) color="#F38BA8" ;;
            *)        color="#F9E2AF" ;;
        esac
        echo "<span color='$color'>●</span> <b>$name</b> <span color='#6C7086'>[$sub]</span>"
    done
}

services=$(list_services)

# -markup-rows tells rofi to interpret Pango markup in each line
chosen=$(echo -e "$services" | rofi -dmenu -theme "$THEME" -p "Services" -markup-rows -mesg "Systemd Services")

[[ -z "$chosen" ]] && exit 0

# Extract the plain service name from the Pango markup.
# First strip all XML/Pango tags, then pick the second whitespace-delimited
# field (field 1 is the status dot character "●").
service_name=$(echo "$chosen" | sed 's/<[^>]*>//g' | awk '{print $2}')

# Sub-menu: choose an action for the selected service
action=$(echo -e "  Start\n  Stop\n󰜉  Restart\n  View Logs" | \
    rofi -dmenu -theme "$THEME" -p "$service_name" -mesg "Service: $service_name")

[[ -z "$action" ]] && exit 0

# Dispatch the chosen action.
# Start/stop/restart use pkexec because system services require root
# privileges. pkexec shows a graphical password dialog via PolicyKit.
case "$action" in
    *"Start"*)
        pkexec systemctl start "${service_name}.service"
        notify-send "Systemd" "Started: $service_name" -t 3000
        ;;
    *"Stop"*)
        pkexec systemctl stop "${service_name}.service"
        notify-send "Systemd" "Stopped: $service_name" -t 3000
        ;;
    *"Restart"*)
        pkexec systemctl restart "${service_name}.service"
        notify-send "Systemd" "Restarted: $service_name" -t 3000
        ;;
    *"Logs"*)
        # Open a new kitty window streaming live logs for this service.
        # -f (follow) keeps the log stream open; --no-pager avoids less.
        # Backgrounded so this script exits immediately.
        kitty -e journalctl -u "${service_name}.service" -f --no-pager &
        ;;
esac
