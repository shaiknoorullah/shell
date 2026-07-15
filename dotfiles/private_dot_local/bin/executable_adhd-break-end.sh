#!/usr/bin/env bash
# adhd-break-end.sh — run by hypridle unlock_cmd. Ends a deliberate break ONLY if a
# `break` interval is currently active (so a plain idle-lock unlock never stops a task).
set -uo pipefail
export PATH="/usr/bin:$HOME/.local/bin:$PATH"
TIMEW=/usr/bin/timew
STATE="$HOME/.cache/adhd/break-active"
HIS=$(find /run/user/1001/hypr -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | head -1)
HYPRLAND_INSTANCE_SIGNATURE="$HIS" hyprctl dispatch dpms on >/dev/null 2>&1 || true
# Only stop if the active interval is the break.
if "$TIMEW" get dom.active >/dev/null 2>&1; then
    tags="$("$TIMEW" get dom.active.tag.1 2>/dev/null; "$TIMEW" get dom.active.json 2>/dev/null)"
    if printf '%s' "$tags" | grep -qiw break; then
        "$TIMEW" stop >/dev/null 2>&1 || true
    fi
fi
rm -f "$STATE"
