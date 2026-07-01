#!/usr/bin/env bash
# eww-media.sh — now-playing metadata as JSON for the eww Dynamic Island.
#
# Emits a single JSON object {"title","artist","status"} describing the active
# MPRIS player (via playerctl). When no player is present, emits an empty object
# `{}` so the island can collapse calmly.
#
# Usage:
#   eww-media.sh             print the current media object once
#
# Output (stdout), e.g.:
#   {"title":"Comfortably Numb","artist":"Pink Floyd","status":"Playing"}
#   {}                       (no player running)
set -euo pipefail

PLAYERCTL="${PLAYERCTL_BIN:-playerctl}"

status="$("$PLAYERCTL" status 2>/dev/null || true)"

# No active player → playerctl prints nothing (or "No players found" on stderr).
if [ -z "$status" ]; then
    echo "{}"
    exit 0
fi

title="$("$PLAYERCTL" metadata title 2>/dev/null || true)"
artist="$("$PLAYERCTL" metadata artist 2>/dev/null || true)"

# Build the object with jq so titles/artists with quotes or backslashes stay
# valid JSON. --arg keeps every value a string.
jq -nc \
    --arg title "$title" \
    --arg artist "$artist" \
    --arg status "$status" \
    '{title: $title, artist: $artist, status: $status}'
