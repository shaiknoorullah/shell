#!/usr/bin/env bash
# clip-prune.sh — expire UNPINNED caelestia clipboard entries older than TTL.
# Driven by clip-prune.timer (systemd user, every 4h). Pinned entries
# (clip-pins.json) are exempt. Entries with no recorded metadata get their ts
# backfilled to now (so they age out one TTL later — no surprise bulk deletion on
# the first run). Set DRY_RUN=1 to preview without deleting or writing anything.
#
# Selection logic mirrors modules/clipboard/logic.js `prunable` (node-tested).
set -uo pipefail
export PATH="$HOME/.nix-profile/bin:$PATH"

TTL="${CLIP_TTL_SECONDS:-86400}"        # 24h
state="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
meta="$state/clip-meta.json"
pins="$state/clip-pins.json"
dry="${DRY_RUN:-0}"
now=$(date +%s)

command -v cliphist >/dev/null 2>&1 || { echo "cliphist not found"; exit 0; }
command -v jq       >/dev/null 2>&1 || { echo "jq not found"; exit 0; }
[ -s "$meta" ] || echo '{}' > "$meta"

# Pinned raws. If the pins file exists but can't be parsed, ABORT — never risk
# deleting a pinned entry.
pinned=""
if [ -f "$pins" ]; then
    pinned=$(jq -r '.[].raw' "$pins" 2>/dev/null) || { echo "pins file unreadable — aborting"; exit 1; }
fi

deleted=0 pinned_kept=0 backfilled=0 fresh=0
while IFS= read -r raw; do
    [ -n "$raw" ] || continue
    # exempt pinned (exact raw match, mirrors ClipPins.isPinned)
    if [ -n "$pinned" ] && printf '%s\n' "$pinned" | grep -qxF -- "$raw"; then
        pinned_kept=$((pinned_kept + 1)); continue
    fi
    md5=$(printf '%s' "$raw" | cliphist decode 2>/dev/null | md5sum | awk '{print $1}')
    [ -n "$md5" ] || continue
    ts=$(jq -r --arg k "$md5" '.[$k].ts // empty' "$meta" 2>/dev/null)
    if [ -z "$ts" ]; then
        # no metadata: backfill ts=now so it ages from first sighting
        if [ "$dry" != "1" ]; then
            tmp=$(mktemp "$meta.XXXXXX")
            if jq --arg k "$md5" --argjson t "$now" '.[$k] = ((.[$k] // {}) + {ts:$t})' "$meta" >"$tmp" 2>/dev/null; then
                mv "$tmp" "$meta"
            else rm -f "$tmp"; fi
        fi
        backfilled=$((backfilled + 1)); continue
    fi
    age=$((now - ts))
    if [ "$age" -gt "$TTL" ]; then
        if [ "$dry" = "1" ]; then
            echo "WOULD DELETE ($((age / 3600))h old): $(printf '%s' "$raw" | cut -c1-70)"
        else
            printf '%s' "$raw" | cliphist delete 2>/dev/null && deleted=$((deleted + 1))
        fi
    else
        fresh=$((fresh + 1))
    fi
done < <(cliphist list 2>/dev/null)

echo "clip-prune: deleted=$deleted pinned_kept=$pinned_kept backfilled=$backfilled fresh=$fresh ttl=${TTL}s dry=$dry"
