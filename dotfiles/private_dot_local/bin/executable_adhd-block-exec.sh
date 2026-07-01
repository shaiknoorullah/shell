#!/usr/bin/env bash
# adhd-block-exec.sh — host-side actuator for the quickshell block picker.
# Triggered by the adhd-block.path systemd unit when ~/.cache/adhd/start-request
# appears. The request is either a numeric task id, or "new:<description>" to
# quick-add a task first. Then it opens a deep-focus block on it (host taskwarrior
# 2.6.2 + the timewarrior hook) and refreshes the task snapshot.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
TASK="${TASK_BIN:-/usr/bin/task}"

req_file="$HOME/.cache/adhd/start-request"
[ -f "$req_file" ] || exit 0
req="$(head -n1 "$req_file" | tr -d '\r')"
rm -f "$req_file"
[ -z "$req" ] && exit 0

case "$req" in
    new:*)
        desc="${req#new:}"
        id="$("$TASK" add +today "$desc" 2>&1 | grep -oE 'Created task [0-9]+' | grep -oE '[0-9]+' || true)"
        ;;
    *)
        id="$(printf '%s' "$req" | tr -dc '0-9')"
        ;;
esac

[ -n "$id" ] && adhd-focus.sh start "$id"
adhd-tasks-export.sh   # keep the drawer's list current
