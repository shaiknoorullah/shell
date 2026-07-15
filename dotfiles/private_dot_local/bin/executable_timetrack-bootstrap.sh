#!/usr/bin/env bash
# timetrack-bootstrap.sh — create the time-tracking data home + Python venv (idempotent).
set -euo pipefail
DATA="$HOME/.local/share/timetrack"
VENV="$DATA/venv"
mkdir -p "$DATA/events"
if [ ! -x "$VENV/bin/python" ]; then
    python3 -m venv "$VENV"
fi
"$VENV/bin/python" -m pip install --quiet --upgrade pip
"$VENV/bin/python" -m pip install --quiet jeepney
echo "OK: data=$DATA venv=$VENV jeepney=$("$VENV/bin/python" -c 'import jeepney; print(jeepney.__version__)')"
