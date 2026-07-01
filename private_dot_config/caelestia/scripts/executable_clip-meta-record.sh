#!/usr/bin/env bash
# clip-meta-record.sh — clipboard metadata sidecar for the caelestia clipboard
# overlay. Reads the new clipboard content on stdin (driven by
# `wl-paste --watch`) and records { ts, app } keyed by md5(content) into the
# JSON file read by services/ClipMeta.qml.
#
# Hyprland autostart (added next to the existing cliphist store watchers):
#   wl-paste --type text  --watch ~/.config/caelestia/scripts/clip-meta-record.sh
#   wl-paste --type image --watch ~/.config/caelestia/scripts/clip-meta-record.sh
#
# The md5 key matches Qt.md5(decodedText) computed in QML (ClipPreview.qml), so
# the overlay can join source-app + capture-time onto each cliphist entry.
set -euo pipefail

# Hyprland's exec PATH lacks ~/.nix-profile/bin, so ensure jq/hyprctl/wl-* resolve.
export PATH="$HOME/.nix-profile/bin:$PATH"

# Must match Paths.state in the shell: ${XDG_STATE_HOME:-$HOME/.local/state}/caelestia
state="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
mkdir -p "$state"
db="$state/clip-meta.json"
[ -s "$db" ] || printf '%s\n' '{}' >"$db"

# Hash the clipboard content arriving on stdin.
md5=$(md5sum | awk '{ print $1 }')
[ -n "$md5" ] || exit 0

ts=$(date +%s)
# Source application (Hyprland active window class); degrade gracefully.
app=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // "unknown"' 2>/dev/null || echo "unknown")
[ -n "$app" ] || app="unknown"

# Upsert the entry. Use jq --arg/--argjson so the app string is escaped safely.
tmp=$(mktemp "${db}.XXXXXX")
if jq --arg k "$md5" --arg app "$app" --argjson ts "$ts" '.[$k] = { ts: $ts, app: $app }' "$db" >"$tmp" 2>/dev/null; then
    mv "$tmp" "$db"
else
    # Corrupt/unreadable db: reset to just this entry rather than wedging forever.
    rm -f "$tmp"
    jq -n --arg k "$md5" --arg app "$app" --argjson ts "$ts" '{ ($k): { ts: $ts, app: $app } }' >"$db"
fi
