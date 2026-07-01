#!/usr/bin/env bash
# adhd-task-cmd.sh — host-side actuator for the quickshell task panel. Runs the
# queued taskwarrior commands the panel can't run itself (container's task 3.x
# can't read the host's 2.6.2 data). Triggered by adhd-task-cmd.path when the
# panel appends to ~/.cache/adhd/task-cmd.
#
# Queue format: one request per line, each a JSON ARRAY of taskwarrior args, e.g.
#   ["modify","5","project:work","+urgent"]
#   ["done","3"]
#   ["add","reply to Slack","project:work","priority:H","due:tomorrow"]
# Args are passed positionally to `task` (never re-parsed by a shell), so task
# descriptions/values can contain spaces and special characters safely.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
TASK="${TASK_BIN:-/usr/bin/task}"

q="$HOME/.cache/adhd/task-cmd"
[ -f "$q" ] || exit 0

# Take the whole queue atomically, then process it (new appends go to a fresh file).
tmp="$(mktemp "${q}.XXXXXX")" || exit 0
mv "$q" "$tmp" 2>/dev/null || { rm -f "$tmp"; exit 0; }

while IFS= read -r line; do
    [ -z "$line" ] && continue
    mapfile -t args < <(printf '%s' "$line" \
        | python3 -c "import json,sys;[print(a) for a in json.load(sys.stdin)]" 2>/dev/null)
    [ "${#args[@]}" -eq 0 ] && continue
    "$TASK" rc.confirmation=off rc.recurrence.confirmation=off "${args[@]}" >/dev/null 2>&1 || true
done < "$tmp"
rm -f "$tmp"

# Refresh the panel's snapshot so the UI reflects the change.
adhd-tasks-export.sh
