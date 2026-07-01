#!/usr/bin/env bash
# eww-window.sh — focused window title (i3) as plain text for the eww top bar.
#
# Prints the title of the currently-focused i3 window, trimmed to a sane width
# so it never blows out the top-bar pill. Designed to back an eww `defpoll`
# (or a `deflisten` wrapper that re-runs it on `i3-msg -t subscribe window`).
#
# Usage:
#   eww-window.sh            print the focused window title once
#
# Output (stdout), e.g.:
#   nvim — boolgen-otel.ts
#
# When nothing is focused (empty desktop) or i3 is unreachable, prints an
# em-dash so the bar shows a calm placeholder instead of going blank.
set -euo pipefail

I3MSG="${I3MSG_BIN:-i3-msg}"
MAXLEN="${EWW_WINDOW_MAXLEN:-48}"

raw="$("$I3MSG" -t get_tree 2>/dev/null || true)"

if [ -z "$raw" ]; then
    printf '%s\n' "—"
    exit 0
fi

# Walk the tree for the focused leaf and take its name. `// empty` guards the
# no-focus case; the surrounding `|| true` guards malformed JSON.
title="$(
    printf '%s' "$raw" | jq -r '
        [ .. | select(type == "object" and .focused? == true) ] | .[0].name // empty
    ' 2>/dev/null || true
)"

if [ -z "$title" ] || [ "$title" = "null" ]; then
    title="—"
fi

# Trim to MAXLEN, appending an ellipsis when we cut.
if [ "${#title}" -gt "$MAXLEN" ]; then
    title="${title:0:MAXLEN}…"
fi

printf '%s\n' "$title"
