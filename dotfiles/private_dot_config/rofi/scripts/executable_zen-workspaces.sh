#!/usr/bin/env bash
# zen-workspaces.sh — Tab group manager for Zen Browser
#
# Features:
#   - Switch between user-defined tab groups (by domain pattern)
#   - Domain overview (tab count per domain)
#   - Find and close duplicate tabs
#   - Bulk close tabs by domain
#
# Keybinding: $mod+Shift+t

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/zen-utils.sh"

THEME="$HOME/.config/rofi/themes/simple.rasi"
CONFIG="$SCRIPT_DIR/zen-workspaces.conf"
[[ ! -f "$CONFIG" ]] && CONFIG="$SCRIPT_DIR/zen-workspaces.example.conf"

# Parse workspace config
get_groups() {
    grep -v '^#' "$CONFIG" | grep -v '^$' | while IFS='|' read -r name domains; do
        local count=0
        IFS=',' read -ra patterns <<< "$domains"
        for pattern in "${patterns[@]}"; do
            count=$(( count + $(bt list 2>/dev/null | grep -ci "$pattern") ))
        done
        printf "  %s (%d tabs)\n" "$name" "$count"
    done
}

# Show tabs matching a group's domain patterns
show_group_tabs() {
    local group_name="$1"
    local domains
    domains=$(grep -v '^#' "$CONFIG" | grep "^${group_name}|" | cut -d'|' -f2)
    [[ -z "$domains" ]] && return

    local tabs=""
    IFS=',' read -ra patterns <<< "$domains"
    for pattern in "${patterns[@]}"; do
        local matched
        matched=$(bt list 2>/dev/null | grep -i "$pattern")
        [[ -n "$matched" ]] && tabs+="$matched"$'\n'
    done

    local selected
    selected=$(echo "$tabs" | sort -u | grep -v '^$' | \
        awk -F'\t' '{printf "%s\t%s\t%s\n", $1, $2, $3}' | \
        rofi -dmenu -theme "$THEME" -p "  $group_name" -i \
             -mesg "enter:switch | ctrl-d:close")

    [[ -z "$selected" ]] && return
    local tab_id
    tab_id=$(echo "$selected" | awk -F'\t' '{print $1}')
    bt activate "$tab_id" 2>/dev/null
    zen_focus_browser
}

# Domain overview: group tabs by domain and show counts
domain_overview() {
    local selected
    selected=$(bt list 2>/dev/null | \
        awk -F'\t' '{
            url=$3;
            gsub(/https?:\/\//, "", url);
            split(url, p, "/");
            domain=p[1];
            gsub(/^www\./, "", domain);
            count[domain]++
        } END {
            for (d in count) printf "%4d  %s\n", count[d], d
        }' | sort -rn | \
        rofi -dmenu -theme "$THEME" -p "  Domains" -i \
             -mesg "Select domain to see its tabs")

    [[ -z "$selected" ]] && return
    local domain
    domain=$(echo "$selected" | awk '{print $2}')

    # Show tabs for selected domain
    local tab_selected
    tab_selected=$(bt list 2>/dev/null | grep -i "$domain" | \
        awk -F'\t' '{printf "%s\t%s\n", $1, $2}' | \
        rofi -dmenu -theme "$THEME" -p "  $domain" -i \
             -mesg "enter:switch")

    [[ -z "$tab_selected" ]] && return
    local tab_id
    tab_id=$(echo "$tab_selected" | awk -F'\t' '{print $1}')
    bt activate "$tab_id" 2>/dev/null
    zen_focus_browser
}

# Find duplicate tabs (same URL open multiple times)
find_duplicates() {
    local dupes
    dupes=$(bt list 2>/dev/null | awk -F'\t' '{
        url=$3; count[url]++; tabs[url]=tabs[url] $1 "," ; titles[url]=$2
    } END {
        for (url in count) if (count[url] > 1)
            printf "%dx  %s\t%s\t%s\n", count[url], titles[url], url, tabs[url]
    }' | sort -rn)

    if [[ -z "$dupes" ]]; then
        zen_notify "No duplicate tabs found"
        return
    fi

    local selected
    selected=$(echo "$dupes" | rofi -dmenu -theme "$THEME" -p "  Duplicates" -i \
         -mesg "Select to close all duplicates (keeps one)")

    [[ -z "$selected" ]] && return

    # Close all but the first duplicate
    local url tab_ids first=true
    url=$(echo "$selected" | awk -F'\t' '{print $2}')
    tab_ids=$(echo "$selected" | awk -F'\t' '{print $3}' | tr ',' '\n' | grep -v '^$')

    while IFS= read -r tid; do
        if [[ "$first" == true ]]; then
            first=false
            continue  # Keep the first one
        fi
        bt close "$tid" 2>/dev/null
    done <<< "$tab_ids"

    zen_notify "Closed duplicate tabs"
}

# Main menu
main_menu() {
    local actions="  Switch Group\n  Domain Overview\n  Find Duplicates"
    local action
    action=$(echo -e "$actions" | rofi -dmenu -theme "$THEME" -p "  Tabs" -i)

    case "$action" in
        *"Switch Group"*)
            local group
            group=$(get_groups | rofi -dmenu -theme "$THEME" -p "  Groups" -i)
            [[ -z "$group" ]] && return
            local group_name
            group_name=$(echo "$group" | sed 's/^.*  //' | sed 's/ (.*//')
            show_group_tabs "$group_name"
            ;;
        *"Domain Overview"*)
            domain_overview
            ;;
        *"Find Duplicates"*)
            find_duplicates
            ;;
    esac
}

main_menu
