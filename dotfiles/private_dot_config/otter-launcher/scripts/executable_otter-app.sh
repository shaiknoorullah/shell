#!/usr/bin/env bash
# otter-app.sh — desktop application launcher (fzf-based otter-launcher module)
#
# Scans the standard XDG + flatpak application directories for .desktop
# files, shows their Name= (falling back to the filename) in fzf, and
# gtk-launches whichever one is chosen. Reference: rofilaunch.sh mode 'd'
# (rofi -show drun), ported to fzf for the otter aesthetic.
set -uo pipefail
source "$HOME/.config/otter-launcher/scripts/_otter-fzf.sh"

app_dirs=(
    "/usr/share/applications"
    "/usr/local/share/applications"
    "$HOME/.local/share/applications"
    "/var/lib/flatpak/exports/share/applications"
    "$HOME/.local/share/flatpak/exports/share/applications"
)

# list_apps — emits "<desktop-id>\t<display-name>" for every visible .desktop
# entry across app_dirs. User-level dirs are scanned last so they win the
# de-dup pass below (an app re-installed/overridden locally shadows the
# system-wide one, same precedence XDG data dirs use).
list_apps() {
    local dir file base name nodisplay hidden
    declare -A seen

    for dir in "${app_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' file; do
            base="$(basename "$file" .desktop)"
            nodisplay="$(grep -m1 '^NoDisplay=' "$file" 2>/dev/null | cut -d= -f2-)"
            hidden="$(grep -m1 '^Hidden=' "$file" 2>/dev/null | cut -d= -f2-)"
            [[ "$nodisplay" == "true" || "$hidden" == "true" ]] && continue
            name="$(grep -m1 '^Name=' "$file" 2>/dev/null | cut -d= -f2-)"
            seen["$base"]="${name:-$base}"
        done < <(find "$dir" -maxdepth 1 -name '*.desktop' -print0 2>/dev/null)
    done

    for base in "${!seen[@]}"; do
        printf '%s\t%s\n' "$base" "${seen[$base]}"
    done | sort -t $'\t' -k2,2f
}

# Debug/verification hook: print the raw list and exit, skipping the
# interactive fzf picker entirely — used to smoke-test the pipeline.
if [[ "${1:-}" == "--list" ]]; then
    list_apps
    exit 0
fi

selection="$(list_apps | fzf --delimiter=$'\t' --with-nth=2 --header=$' apps')"
[[ -z "$selection" ]] && exit 0

app_id="$(cut -f1 <<<"$selection")"
setsid -f gtk-launch "$app_id" >/dev/null 2>&1
