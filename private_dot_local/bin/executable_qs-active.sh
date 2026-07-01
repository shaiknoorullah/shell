#!/usr/bin/env bash
# qs-active.sh — the currently-active taskwarrior task + live timewarrior
# elapsed, as JSON for the bar's center / left-drawer BIG timer:
#
#   {"task":"boolgen otel","elapsed":"0:42:11"}
#
# - Taskwarrior via $TASK (TASK_BIN override; go-task shadows `task` on PATH).
# - Active task = first id in `task +ACTIVE ids`; desc via `task _get <id>.description`.
# - Live elapsed = timew's open interval. `timew get dom.active.duration` returns
#   an ISO-8601 duration (e.g. PT42M11S) and is INVALID when nothing tracks, so we
#   guard on dom.active.start and convert PT#H#M#S → H:MM:SS.
# - NOTE: no `set -e` — the `[ -z x ] && y` idiom returns non-zero when x is set,
#   which under `set -e` would kill the script exactly when a task IS active.
set -uo pipefail

TASK="${TASK_BIN:-/usr/bin/task}"

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s" | tr -d '\000-\037'
}

# ISO-8601 duration (PT#H#M#S) → H:MM:SS
fmt_dur() {
    local d="$1" h=0 m=0 s=0
    [[ $d =~ ([0-9]+)H ]] && h=${BASH_REMATCH[1]}
    [[ $d =~ ([0-9]+)M ]] && m=${BASH_REMATCH[1]}
    [[ $d =~ ([0-9]+)S ]] && s=${BASH_REMATCH[1]}
    printf '%d:%02d:%02d' "$h" "$m" "$s"
}

# Prefer timew for BOTH elapsed and the label: it works cross-version (the Arch
# container has taskwarrior 3.x which can't read the host's 2.6.2 ~/.task, but
# timew's data IS shared/compatible). The on-modify hook tags the active interval
# with [project, description], so the LAST tag is the task description.
elapsed="0:00:00"
desc="—"
if timew get dom.active.start >/dev/null 2>&1; then
    raw="$(timew get dom.active.duration 2>/dev/null | head -n1 | tr -d '[:space:]')"
    [ -n "$raw" ] && elapsed="$(fmt_dur "$raw")"
    n="$(timew get dom.active.tag.count 2>/dev/null | tr -dc '0-9')"
    if [ -n "$n" ] && [ "$n" -ge 1 ]; then
        t="$(timew get "dom.active.tag.$n" 2>/dev/null | head -n1)"
        [ -n "$t" ] && desc="$t"
    fi
fi
# Fallback to taskwarrior for the label (host with no timew tags).
if [ "$desc" = "—" ]; then
    id="$("$TASK" +ACTIVE ids 2>/dev/null | head -n1 | tr -d '[:space:]')"
    if [ -n "$id" ]; then
        d="$("$TASK" _get "${id}.description" 2>/dev/null | head -n1)"
        [ -n "$d" ] && desc="$d"
    fi
fi

printf '{"task":"%s","elapsed":"%s"}\n' "$(json_escape "$desc")" "$(json_escape "$elapsed")"
