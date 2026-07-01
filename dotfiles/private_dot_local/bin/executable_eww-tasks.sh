#!/usr/bin/env bash
# eww-tasks.sh — "now · next" task list for the summoned left bar.
#
# Surfaces the small set of tasks the user is actually chasing right now:
#   - the ACTIVE task (if any) first, marked active, with live timew elapsed
#   - then +today tasks, then +next tasks, de-duplicated, capped to a few rows
# as a JSON ARRAY of compact rows the leftbar widget renders directly.
#
# Output (JSON array; always valid, possibly empty []):
#   [{"id":1,"desc":"boolgen otel","meta":"1:47","active":true,"icon":""},
#    {"id":2,"desc":"review FR-006 PR","meta":"work","active":false,"icon":"󰄱"}]
#
# - Taskwarrior is invoked via $TASK (TASK_BIN override) because go-task
#   shadows `task` on PATH; default /usr/bin/task.
# - `meta` is the live elapsed (M:SS-ish from timew) for the active row, else
#   the task's primary tag/project so the row reads like the mockup.
# - Robust: any failure / no tasks emits "[]" so the defpoll never breaks.
set -euo pipefail

TASK="${TASK_BIN:-/usr/bin/task}"
JQ="${JQ_BIN:-jq}"

# Max rows to surface (the mockup shows ~3). Keep the bar calm, not a backlog.
MAX_ROWS="${EWW_TASKS_MAX:-3}"

# Collect ids in priority order: active, then +today, then +next.
active_id="$("$TASK" +ACTIVE ids 2>/dev/null | head -n1 | tr -d '[:space:]')"
today_ids="$("$TASK" +today ids 2>/dev/null | tr ' ' '\n' | tr -d '\r' || true)"
next_ids="$("$TASK" +next ids 2>/dev/null | tr ' ' '\n' | tr -d '\r' || true)"

# Live elapsed for the active row (mirrors eww-active.sh). Falls back to a short
# zero clock; the widget shows it as the row's right-hand meta.
elapsed="$(timew get dom.active.duration 2>/dev/null | head -n1 | tr -d '[:space:]')"
[ -z "$elapsed" ] && elapsed="0:00"

# desc_of <id> — task description, trimmed.
desc_of() { "$TASK" _get "${1}.description" 2>/dev/null | head -n1; }

# meta_of <id> — first tag, else project, else "task" so the row never reads
# empty. Tags come back space-separated; project is plain text.
meta_of() {
    local tag proj
    tag="$("$TASK" _get "${1}.tags" 2>/dev/null | head -n1 | awk '{print $1}')"
    if [ -n "$tag" ]; then printf '%s' "$tag"; return; fi
    proj="$("$TASK" _get "${1}.project" 2>/dev/null | head -n1)"
    if [ -n "$proj" ]; then printf '%s' "$proj"; return; fi
    printf 'task'
}

# Ordered, de-duplicated id stream (active first).
ordered=""
seen=" "
add_id() {
    local id="$1"
    [ -z "$id" ] && return 0
    case "$seen" in *" $id "*) return 0 ;; esac
    seen+="$id "
    ordered+="$id"$'\n'
    return 0
}
add_id "$active_id"
while IFS= read -r id; do add_id "$(printf '%s' "$id" | tr -d '[:space:]')"; done <<< "$today_ids"
while IFS= read -r id; do add_id "$(printf '%s' "$id" | tr -d '[:space:]')"; done <<< "$next_ids"

# Assemble compact JSON objects, newline-delimited, then jq -s into an array
# and cap the length. Each row carries its own active flag + icon glyph.
rows=""
count=0
while IFS= read -r id; do
    [ -z "$id" ] && continue
    [ "$count" -ge "$MAX_ROWS" ] && break
    desc="$(desc_of "$id")"
    [ -z "$desc" ] && continue
    if [ -n "$active_id" ] && [ "$id" = "$active_id" ]; then
        active="true"; meta="$elapsed"; icon=""
    else
        active="false"; meta="$(meta_of "$id")"; icon="󰄱"
    fi
    obj="$("$JQ" -cn \
        --argjson id "$id" \
        --arg desc "$desc" \
        --arg meta "$meta" \
        --argjson active "$active" \
        --arg icon "$icon" \
        '{id:$id, desc:$desc, meta:$meta, active:$active, icon:$icon}')"
    rows+="$obj"$'\n'
    count=$((count + 1))
done <<< "$ordered"

printf '%s' "$rows" | "$JQ" -s '.'
