#!/usr/bin/env bash
# adhd-notifs.sh - dunst status/actions for the Quickshell right panel.
set -euo pipefail

cmd="${1:-status}"

run_host() {
  systemd-run --user --quiet --wait --pipe --collect /bin/bash -lc "$1" 2>/dev/null
}

unavailable() {
  printf '{"available":false,"paused":false,"count":0,"items":[]}\n'
}

has_live_swaync() {
  run_host 'command -v swaync-client >/dev/null 2>&1 && swaync-client --count >/dev/null 2>&1'
}

has_live_dunst() {
  run_host 'command -v dunstctl >/dev/null 2>&1 && dunstctl is-paused >/dev/null 2>&1'
}

case "$cmd" in
  status)
    if has_live_swaync; then
      paused="$(run_host 'swaync-client --get-dnd 2>/dev/null' || echo false)"
      count="$(run_host 'swaync-client --count 2>/dev/null' || echo 0)"
      jq -cn \
        --arg backend "swaync" \
        --arg paused "$paused" \
        --argjson count "${count:-0}" '
        {
          available: true,
          backend: $backend,
          paused: ($paused == "true"),
          count: $count,
          items: (
            if $count > 0 then [{
              id: -1,
              app: "SwayNC",
              summary: "\($count) notifications",
              body: "SwayNC owns notification history on this machine.",
              time: ""
            }] else [] end
          )
        }'
      exit 0
    fi

    if ! has_live_dunst; then
      unavailable
      exit 0
    fi

    paused="$(run_host 'dunstctl is-paused 2>/dev/null' || echo false)"
    count="$(run_host 'dunstctl count history 2>/dev/null' || echo 0)"

    run_host 'dunstctl history 2>/dev/null' | jq -c \
      --arg paused "$paused" \
      --argjson count "${count:-0}" '
      def rel_time:
        . / 1000000000 |
        if . < 60 then "now"
        elif . < 3600 then "\(. / 60 | floor)m"
        elif . < 86400 then "\(. / 3600 | floor)h"
        else "\(. / 86400 | floor)d"
        end;

      {
        available: true,
        backend: "dunst",
        paused: ($paused == "true"),
        count: $count,
        items: ([
          .data[0][]? | {
            id: .id.data,
            app: (.appname.data // "Notification"),
            summary: (.summary.data // ""),
            body: ((.body.data // "") | gsub("\n"; " ") | if length > 160 then .[:160] + "..." else . end),
            time: (.timestamp.data | rel_time)
          }
        ] | reverse | .[0:12])
      }'
    ;;
  toggle-dnd)
    if has_live_swaync; then
      run_host 'swaync-client --toggle-dnd >/dev/null 2>&1' || true
    else
      has_live_dunst && run_host 'dunstctl set-paused toggle >/dev/null 2>&1' || true
    fi
    ;;
  clear)
    if has_live_swaync; then
      run_host 'swaync-client --close-all >/dev/null 2>&1' || true
    else
      has_live_dunst && run_host 'dunstctl history-clear >/dev/null 2>&1' || true
    fi
    ;;
  dismiss)
    id="${2:-}"
    if [ "$id" = "-1" ] && has_live_swaync; then
      run_host 'swaync-client --close-latest >/dev/null 2>&1' || true
    elif [ -n "$id" ] && has_live_dunst; then
      run_host "dunstctl history-rm '$id' >/dev/null 2>&1" || true
    fi
    ;;
  *)
    echo "usage: adhd-notifs.sh {status|toggle-dnd|clear|dismiss <id>}" >&2
    exit 2
    ;;
esac
