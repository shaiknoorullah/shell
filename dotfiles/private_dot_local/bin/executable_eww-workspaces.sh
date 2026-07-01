#!/usr/bin/env bash
# eww-workspaces.sh — i3 workspaces as a compact JSON array for the eww top bar.
#
# Emits a JSON array of {num, focused, name} objects, one per i3 workspace,
# preserving i3's ordering. Designed to back an eww `deflisten`/`defpoll`.
#
# Usage:
#   eww-workspaces.sh         print the current workspace array once
#
# Output (stdout), e.g.:
#   [{"num":1,"focused":true,"name":"1"},{"num":2,"focused":false,"name":"2:web"}]
#
# When i3 is unreachable or returns nothing, prints an empty array `[]` so the
# widget degrades calmly instead of erroring.
set -euo pipefail

I3MSG="${I3MSG_BIN:-i3-msg}"

raw="$("$I3MSG" -t get_workspaces 2>/dev/null || true)"

if [ -z "$raw" ]; then
    echo "[]"
    exit 0
fi

# Map i3's verbose workspace objects down to {num, focused, name}.
# `// empty` + the surrounding `try`/default guards malformed input.
printf '%s' "$raw" | jq -c '
    if type == "array" then
        [ .[] | {num: .num, focused: .focused, name: .name} ]
    else
        []
    end
' 2>/dev/null || echo "[]"
