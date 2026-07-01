#!/usr/bin/env bash
# qs-vol.sh — system output volume as JSON for the eww top bar.
#
# Reads the default sink volume + mute state from PipeWire (wpctl) and emits:
#
#   {"vol":62,"muted":false}
#
# `vol` is an integer percentage (0–100, rounded). When the sink is muted,
# `muted` is true and the widget can swap the glyph. Designed to back an eww
# `defpoll`.
#
# Usage:
#   qs-vol.sh               print the current volume object once
#
# When wpctl is unavailable or errors, emits {"vol":0,"muted":true} so the bar
# degrades calmly rather than erroring.
set -euo pipefail

WPCTL="${WPCTL_BIN:-wpctl}"
SINK="${EWW_VOL_SINK:-@DEFAULT_AUDIO_SINK@}"

# wpctl get-volume prints e.g. "Volume: 0.62" or "Volume: 0.62 [MUTED]".
raw="$("$WPCTL" get-volume "$SINK" 2>/dev/null || true)"

if [ -z "$raw" ]; then
    echo '{"vol":0,"muted":true}'
    exit 0
fi

# Extract the float and the optional [MUTED] flag.
fraction="$(printf '%s' "$raw" | awk '{print $2}')"
muted=false
case "$raw" in
    *MUTED*) muted=true ;;
esac

# Convert 0.62 -> 62 (rounded). Fall back to 0 if parsing fails.
vol="$(awk -v f="$fraction" 'BEGIN { if (f == "") f = 0; printf "%d", (f * 100) + 0.5 }' 2>/dev/null || echo 0)"
[ -z "$vol" ] && vol=0

printf '{"vol":%d,"muted":%s}\n' "$vol" "$muted"
