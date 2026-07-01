#!/usr/bin/env bash
# adhd-bluetooth.sh - host bluetoothctl status/actions for Quickshell.
set -euo pipefail

cmd="${1:-status}"

run_host() {
  systemd-run --user --quiet --wait --pipe --collect /bin/bash -lc "$1" 2>/dev/null
}

unavailable() {
  printf '{"available":false,"enabled":false,"connectedCount":0,"firstConnectedName":"","status":"Unavailable"}\n'
}

status_json() {
  local show="$1"
  local connected="$2"
  local powered count first status

  powered=false
  if printf '%s\n' "$show" | grep -q 'Powered: yes'; then
    powered=true
  fi

  count="$(printf '%s\n' "$connected" | awk '/^Device / { c++ } END { print c + 0 }')"
  first="$(printf '%s\n' "$connected" | awk '/^Device / { $1=""; $2=""; sub(/^  */, ""); print; exit }')"

  if [ "$powered" != true ]; then
    status="Off"
  elif [ "${count:-0}" -gt 0 ]; then
    status="$first"
  else
    status="Not connected"
  fi

  jq -cn \
    --argjson enabled "$powered" \
    --argjson connectedCount "${count:-0}" \
    --arg firstConnectedName "$first" \
    --arg status "$status" \
    '{
      available: true,
      enabled: $enabled,
      connectedCount: $connectedCount,
      firstConnectedName: $firstConnectedName,
      status: $status
    }'
}

case "$cmd" in
  status)
    show="$(run_host 'bluetoothctl show 2>/dev/null')" || {
      unavailable
      exit 0
    }
    connected="$(run_host 'bluetoothctl devices Connected 2>/dev/null' || true)"
    status_json "$show" "$connected"
    ;;
  toggle)
    show="$(run_host 'bluetoothctl show 2>/dev/null' || true)"
    if printf '%s\n' "$show" | grep -q 'Powered: yes'; then
      run_host 'bluetoothctl power off >/dev/null 2>&1' || true
    else
      run_host 'bluetoothctl power on >/dev/null 2>&1' || true
    fi
    ;;
  *)
    echo "usage: adhd-bluetooth.sh {status|toggle}" >&2
    exit 2
    ;;
esac
