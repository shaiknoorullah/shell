#!/usr/bin/env bash
# wall.sh — wallpaper manager (swww + persistence + transitions).
#
#   wall.sh set <path>      set a wallpaper and remember it
#   wall.sh random [coll]   random wallpaper (optionally from a collection dir)
#   wall.sh next | prev     cycle through every wallpaper
#   wall.sh restore         re-apply the saved wallpaper (autostart); random if none
#   wall.sh list            print all wallpaper paths
#
# Wallpapers live in ~/walls (its own git repo, 6 collections). The current
# choice is persisted to ~/.cache/wall so it survives restarts/reboots.
set -uo pipefail

WALLS="${WALLDIR:-$HOME/walls}"
STATE="$HOME/.cache/wall"

ensure_daemon() {
    pgrep -x swww-daemon >/dev/null 2>&1 || { swww-daemon >/dev/null 2>&1 & sleep 0.7; }
}

list_all() {
    find "$WALLS" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        2>/dev/null | sort
}

set_wall() {
    local img="$1"
    [ -n "$img" ] && [ -f "$img" ] || { echo "wall.sh: no such image: $img" >&2; return 1; }
    ensure_daemon
    swww img "$img" \
        --transition-type grow --transition-pos center \
        --transition-duration 1.0 --transition-fps 60 >/dev/null 2>&1
    mkdir -p "$(dirname "$STATE")"
    printf '%s\n' "$img" > "$STATE"
}

case "${1:-restore}" in
    set)
        set_wall "${2:?usage: wall.sh set <path>}"
        ;;
    random)
        set_wall "$(list_all | { c="${2:-}"; [ -n "$c" ] && grep "/$c/" || cat; } | shuf -n1)"
        ;;
    next|prev)
        cur="$(cat "$STATE" 2>/dev/null)"
        mapfile -t all < <(list_all)
        [ "${#all[@]}" -eq 0 ] && exit 0
        idx=0
        for i in "${!all[@]}"; do
            [ "${all[$i]}" = "$cur" ] && { idx=$i; break; }
        done
        n=${#all[@]}
        if [ "$1" = next ]; then idx=$(( (idx + 1) % n )); else idx=$(( (idx - 1 + n) % n )); fi
        set_wall "${all[$idx]}"
        ;;
    restore)
        cur="$(cat "$STATE" 2>/dev/null)"
        if [ -n "$cur" ] && [ -f "$cur" ]; then
            set_wall "$cur"
        else
            set_wall "$(list_all | shuf -n1)"
        fi
        ;;
    list)
        list_all
        ;;
    *)
        echo "usage: wall.sh {set <path>|random [collection]|next|prev|restore|list}" >&2
        exit 1
        ;;
esac
