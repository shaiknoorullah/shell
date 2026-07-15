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
    ss -ltnp | grep 5600        # privacy invariant: aw-server must bind 127.0.0.1 ONLY

If a service shows `failed` (not merely `inactive`), a crash-loop exhausted systemd's
default restart burst (5 in 10s) and it will NOT auto-recover — clear and restart:
    systemctl --user reset-failed <svc> && systemctl --user restart <svc>
    journalctl --user -u <svc> -n 50     # see why it looped

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

## Assumptions this depends on (check these if window capture ever silently stops)
- awatcher runs under the **systemd --user** manager, so it needs `WAYLAND_DISPLAY`
  (and `HYPRLAND_INSTANCE_SIGNATURE`, `XDG_CURRENT_DESKTOP`) imported into that manager
  BEFORE it starts. Hyprland/uwsm imports them today (`systemctl --user show-environment
  | grep WAYLAND_DISPLAY`). If a future session-launch change stops importing them,
  awatcher starts but records nothing — window/AFK buckets go empty with no error.
- The AFK/break threshold lives in `~/.config/awatcher/config.toml`
  (`idle-timeout-seconds = 180`). Changing it changes what counts as a break.
