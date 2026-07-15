# Time-Tracking Stage 1 (Capture) — Runbook

## What's running
- `aw-server.service` (enabled) — ActivityWatch server + web UI/API at http://127.0.0.1:5600
- `awatcher.service` (started from hyprland.lua) — active-window + AFK (idle ≥180s) watcher
- `timetrack-logind.service` (enabled) — appends session/lock/suspend events to
  `~/.local/share/timetrack/events/logind.jsonl`

## Health check
    systemctl --user is-active aw-server.service awatcher.service timetrack-logind.service
    curl -fsS http://127.0.0.1:5600/api/0/info
    tail ~/.local/share/timetrack/events/logind.jsonl

## Restart / reinstall
    ~/.local/bin/timetrack-bootstrap.sh              # data home + venv
    ~/.local/bin/timetrack-install-aw-server.sh      # aw-server binary
    ~/.local/bin/timetrack-install-awatcher.sh       # awatcher binary
    systemctl --user restart aw-server.service awatcher.service timetrack-logind.service

## Data locations
- ActivityWatch DB: ~/.local/share/activitywatch/aw-server-rust/
- logind events:    ~/.local/share/timetrack/events/logind.jsonl

## Notes
- awatcher is triggered from hyprland.lua (`systemctl --user start awatcher.service`) because it
  needs the Wayland session; aw-server + logind capture are enabled at default.target.
- Nothing leaves the machine in Stage 1 (aw-server binds 127.0.0.1 only).
