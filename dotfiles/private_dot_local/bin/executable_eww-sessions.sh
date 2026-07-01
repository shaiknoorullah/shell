#!/usr/bin/env bash
# eww-sessions.sh — tmux sessions grouped by context prefix, as JSON.
#
# Feeds the summoned left "what am I chasing" bar. tmux session names follow a
# "<context>:<name>" convention (e.g. work:pnow-ats, lab:boolgen). We group by
# the part before the first ':'. Sessions with no prefix fall into "misc".
#
# Output: a JSON ARRAY of groups, each:
#   [{"context":"work","sessions":[{"name":"pnow-ats","attached":true}, …]}, …]
# Groups are sorted by context; an empty array is emitted when tmux has no
# sessions / no server running. Never errors out to the widget.
#
# Reads:  tmux list-sessions
# Wired:  defpoll / button list in eww leftbar widget.
set -euo pipefail

JQ="${JQ_BIN:-jq}"

# Each line: "<session_name> <attached_flag>" where attached_flag is 1/0.
# If the tmux server isn't running, list-sessions exits non-zero -> no lines.
raw="$(tmux list-sessions -F '#{session_name} #{session_attached}' 2>/dev/null || true)"

# Build a newline-delimited stream of compact session objects tagged with their
# context, then let jq group + sort. Doing the parse in bash keeps it robust to
# the tmux format quirks; jq only assembles the final shape.
sessions_json=""
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name="${line%% *}"                 # first field = session name
    attached_field="${line##* }"        # last field = attached flag
    [[ -z "$name" ]] && continue

    if [[ "$name" == *:* ]]; then
        context="${name%%:*}"           # before first ':'
        short="${name#*:}"              # after first ':'
    else
        context="misc"
        short="$name"
    fi
    [[ -z "$context" ]] && context="misc"

    if [[ "$attached_field" == "1" ]]; then
        attached="true"
    else
        attached="false"
    fi

    obj="$("$JQ" -cn \
        --arg context "$context" \
        --arg name "$short" \
        --argjson attached "$attached" \
        '{context:$context, name:$name, attached:$attached}')"
    sessions_json+="$obj"$'\n'
done <<< "$raw"

# Group by context, sort groups by context, sessions by name. Empty in -> [].
printf '%s' "$sessions_json" | "$JQ" -s '
    map(select(. != null))
    | group_by(.context)
    | map({
        context: .[0].context,
        sessions: (map({name, attached}) | sort_by(.name))
      })
    | sort_by(.context)
'
