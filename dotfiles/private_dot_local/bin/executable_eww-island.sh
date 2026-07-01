#!/usr/bin/env bash
# eww-island.sh — Dynamic-Island media + live-activity payload (JSON).
#
# Fuses the now-playing media object (from eww-media.sh / playerctl) with the
# focus engine's live-activity line (`adhd-focus.sh status`) into one object the
# island widget polls. The live-activity row is the "deep block · 1:47 → ʿAsr"
# pill in the mockup's expanded player.
#
# Routes taskwarrior-backed tooling via TASK so go-task's `task` shim never
# shadows taskwarrior inside the focus daemon.
#
# Usage:
#   eww-island.sh            print the island payload once
#
# Output (stdout), e.g.:
#   {"title":"Let It Happen","artist":"Tame Impala","status":"Playing",
#    "playing":true,"hasmedia":true,"activity":"block 47m · → ʿAsr 16:30"}
#   {"title":"","artist":"","status":"","playing":false,"hasmedia":false,
#    "activity":"idle · → Fajr (tmrw)"}
set -euo pipefail

# taskwarrior binary (go-task shadows `task` in PATH); honored by adhd-focus.sh.
export TASK_BIN="${TASK_BIN:-/usr/bin/task}"

# Resolve sibling backends from this script's own directory so the island works
# regardless of cwd.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_SH="${EWW_MEDIA_BIN:-$SELF_DIR/executable_eww-media.sh}"
FOCUS_SH="${ADHD_FOCUS_BIN:-$HOME/.local/bin/adhd-focus.sh}"

# ── media ────────────────────────────────────────────────────
# eww-media emits {"title","artist","status"} or {} (no player). Default to {}.
media="$(bash "$MEDIA_SH" 2>/dev/null || echo '{}')"
[ -z "$media" ] && media='{}'
echo "$media" | jq -e 'type == "object"' >/dev/null 2>&1 || media='{}'

# ── live activity ────────────────────────────────────────────
# adhd-focus.sh status prints one line: "block Nm · → <salah>" or "idle · → …".
if [ -x "$FOCUS_SH" ]; then
    activity="$("$FOCUS_SH" status 2>/dev/null || true)"
else
    activity="$(adhd-focus.sh status 2>/dev/null || true)"
fi
[ -z "$activity" ] && activity="idle"

# ── merge ────────────────────────────────────────────────────
# `hasmedia` lets the widget choose the calm empty state; `playing` toggles the
# play/pause glyph without string-matching inside yuck.
jq -nc \
    --argjson media "$media" \
    --arg activity "$activity" \
    '{
        title:    ($media.title    // ""),
        artist:   ($media.artist   // ""),
        status:   ($media.status   // ""),
        playing:  (($media.status // "") == "Playing"),
        hasmedia: (($media.status // "") != ""),
        activity: $activity
    }'
