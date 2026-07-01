#!/usr/bin/env bash
# qs-task-ui-config.sh - normalize Quickshell task UI YAML profiles to JSON.
set -euo pipefail

active="${1:-$HOME/.config/quickshell/task-ui.yaml}"
loader="$HOME/.local/lib/qs-task-ui-config-loader.py"

if python3 - <<'PY' >/dev/null 2>&1; then
import yaml
PY
  exec python3 "$loader" "$active"
fi

exec systemd-run --user --quiet --wait --pipe --collect \
  /usr/bin/python3 "$loader" "$active" 2>/dev/null
