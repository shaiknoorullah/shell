#!/usr/bin/env bash
# eww-salah.sh — today's five-prayer strip for the summoned left bar.
#
# Reads the operator-editable schedule at ~/.config/adhd/prayer-times.conf
# (Format: "<Name> <HH:MM>", 24h) and tags each prayer with a state for the
# leftbar pill strip:
#   - "done" : its time is in the past (already prayed / passed)
#   - "next" : the first prayer still ahead today (the one we're chasing)
#   - ""     : a later prayer (neutral)
# When every prayer for today has passed, none is "next" (tomorrow's Fajr is
# the next, but we keep the strip honest and just show all done).
#
# Output (JSON array, in schedule order; always valid):
#   [{"name":"Fajr","time":"04:55","state":"done"},
#    {"name":"Asr","time":"16:42","state":"next"}, …]
#
# Reads:  ~/.config/adhd/prayer-times.conf  (optional → [] if absent)
# Wired:  defpoll in the eww leftbar salah strip.
set -euo pipefail

CONF="${PRAYER_TIMES_CONF:-$HOME/.config/adhd/prayer-times.conf}"
JQ="${JQ_BIN:-jq}"

# Allow tests to pin "now" (HHMM); default to the wall clock.
now="${EWW_SALAH_NOW:-$(date +%H%M)}"

[ -f "$CONF" ] && [ -r "$CONF" ] || { printf '[]\n'; exit 0; }

# First pass: find the next upcoming prayer (earliest time strictly after now).
# A separate pass keeps the state logic simple and order-independent.
next_name=""
while read -r name time _; do
    case "$name" in ''|'#'*) continue ;; esac
    [ -z "$time" ] && continue
    hm="${time/:/}"
    [[ "$hm" =~ ^[0-9]+$ ]] || continue
    if [ "$hm" -gt "$now" ]; then
        next_name="$name"
        break
    fi
done < "$CONF"

# Second pass: emit a compact object per prayer with its computed state.
rows=""
while read -r name time _; do
    case "$name" in ''|'#'*) continue ;; esac
    [ -z "$time" ] && continue
    hm="${time/:/}"
    [[ "$hm" =~ ^[0-9]+$ ]] || continue
    if [ "$name" = "$next_name" ]; then
        state="next"
    elif [ "$hm" -le "$now" ]; then
        state="done"
    else
        state=""
    fi
    obj="$("$JQ" -cn \
        --arg name "$name" \
        --arg time "$time" \
        --arg state "$state" \
        '{name:$name, time:$time, state:$state}')"
    rows+="$obj"$'\n'
done < "$CONF"

printf '%s' "$rows" | "$JQ" -s '.'
