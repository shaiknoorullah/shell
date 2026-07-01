#!/usr/bin/env bash
# qs-stats.sh — shame-free daily consistency stats for the bottom context bar.
#
# Surfaces focus-score / streak / coffee / walks / encouragement from a small
# JSON log at ~/.local/share/adhd/stats.json. Every value is framed positively:
# we NEVER emit a "broken streak", a negative number, or red/scolding copy.
# Missing or malformed input falls back to calm, encouraging defaults — a fresh
# day is a clean slate, not a failure.
#
# Output (single JSON object, all keys always present):
#   {"focus_score":84,"streak":12,"coffee":2,"walks":3,"encourage":"…"}
#
# Reads:  ~/.local/share/adhd/stats.json  (optional)
# Wired:  defpoll in eww bottombar widget.
set -euo pipefail

STATS_FILE="${ADHD_STATS_FILE:-$HOME/.local/share/adhd/stats.json}"
JQ="${JQ_BIN:-jq}"

# ── Shame-free defaults ───────────────────────────────────────
# Used when the file is absent OR unreadable OR a field is missing/invalid.
# Numbers default to 0 (a calm baseline, never negative); encouragement is
# always present so the bar never shows an empty or scolding right-hand side.
DEF_FOCUS=0
DEF_STREAK=0
DEF_COFFEE=0
DEF_WALKS=0

# clamp_nonneg <value> <default> — coerce to a non-negative integer.
# Anything that isn't a clean integer >= 0 (negatives, floats, text, null)
# collapses to the default. This is the hard guarantee: no negative framing
# ever reaches the widget.
clamp_nonneg() {
    local v="$1" def="$2"
    if [[ "$v" =~ ^[0-9]+$ ]]; then
        printf '%s' "$v"
    else
        printf '%s' "$def"
    fi
}

# Pull raw fields from the log if it exists and parses; otherwise defaults.
focus="$DEF_FOCUS"; streak="$DEF_STREAK"; coffee="$DEF_COFFEE"; walks="$DEF_WALKS"
encourage=""

if [[ -f "$STATS_FILE" ]] && "$JQ" -e . "$STATS_FILE" >/dev/null 2>&1; then
    focus="$("$JQ" -r '.focus_score // empty'  "$STATS_FILE" 2>/dev/null || true)"
    streak="$("$JQ" -r '.streak // empty'       "$STATS_FILE" 2>/dev/null || true)"
    coffee="$("$JQ" -r '.coffee // empty'       "$STATS_FILE" 2>/dev/null || true)"
    walks="$("$JQ" -r '.walks // empty'         "$STATS_FILE" 2>/dev/null || true)"
    encourage="$("$JQ" -r '.encourage // empty' "$STATS_FILE" 2>/dev/null || true)"
fi

focus="$(clamp_nonneg "$focus" "$DEF_FOCUS")"
streak="$(clamp_nonneg "$streak" "$DEF_STREAK")"
coffee="$(clamp_nonneg "$coffee" "$DEF_COFFEE")"
walks="$(clamp_nonneg "$walks" "$DEF_WALKS")"

# ── Encouragement: never negative, never scolding ─────────────
# If the log supplies its own line, honour it. Otherwise pick a warm,
# consistency-affirming phrase. A streak of 0 is "a fresh start", not "broken".
if [[ -z "$encourage" || "$encourage" == "null" ]]; then
    if (( streak >= 7 )); then
        encourage="✦ best focus this week"
    elif (( streak >= 1 )); then
        encourage="✦ keeping the rhythm"
    else
        encourage="✦ a fresh start today"
    fi
fi

# Emit compact JSON. Use jq for safe string escaping of the encouragement.
"$JQ" -cn \
    --argjson focus_score "$focus" \
    --argjson streak "$streak" \
    --argjson coffee "$coffee" \
    --argjson walks "$walks" \
    --arg encourage "$encourage" \
    '{focus_score:$focus_score, streak:$streak, coffee:$coffee, walks:$walks, encourage:$encourage}'
