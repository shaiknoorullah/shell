# Time-Tracking Stage 2 (Daily Driver) — Runbook

The keyboard daily driver over the Stage-1 passive capture: taskwarrior-tui for
tasks + time, a break hotkey, and salah tracking (reminder + one-key logger).
All data is local; artifacts are plain files under the `shaiknoorullah/shell`
repo (`~/src/caelestia-shell`), chezmoi-managed.

## Keys
- **Super+Shift+Enter** — taskwarrior-tui (daily driver; also auto-opens at login; otter module `tw`).
- **Super+Shift+P** — break: pause the active task (timew `break` interval) + monitor off + lock. Unlock ends it.
- **Super+Shift+;** — one-key salah logger (fzf: `jamaah` / `alone` / `qaza` / `missed`), marks + completes the prayer.

## Pieces
- `~/.local/bin/tw-tui` — launches taskwarrior-tui with **linuxbrew taskwarrior 3.4.2** (`/home/linuxbrew/.linuxbrew/bin/task`) pinned first in PATH.
- `~/.local/bin/adhd-break.sh` / `adhd-break-end.sh` — break start / unlock handler (hypridle `unlock_cmd`).
- `~/.local/bin/adhd-salah-tasks.sh` (+ `adhd-salah-tasks.timer`) — daily generates 5 salah tasks (tag `salah`, `project:salah`, `due:<iqamah>`) from `~/.config/adhd/prayer-times.conf`.
- `~/.local/bin/adhd-salah-schedule.sh` (+ `adhd-salah-schedule.timer`) — daily arms per-prayer nudge timers as **date-stamped one-shot** transient units (`adhd-salah-nudge-<Prayer>-YYYYMMDD`, `RemainAfterElapse=no`). Re-arms each day so shifting iqamah times take effect.
- `~/.local/bin/adhd-salah-nudge.sh` — the per-prayer reminder (plain `notify-send`).
- `~/.local/bin/adhd-salah-pick.sh` — the one-key fzf logger; hard-filters `+salah +PENDING` on every path (never touches a non-salah task).
- UDA `salah_status` (`jamaah`/`alone`/`qaza`/`missed`) in `~/.taskrc`.
- Salah runway (next-prayer countdown the old panel showed): `~/.local/bin/adhd-focus.sh status`.

## Health
```bash
systemctl --user list-timers 'adhd-salah-*' --no-pager          # daily generators + per-prayer nudges
/home/linuxbrew/.linuxbrew/bin/task rc.verbose=nothing +salah project:salah list
env PATH=/home/linuxbrew/.linuxbrew/bin:$PATH task --version     # must be 3.4.2
~/.local/bin/adhd-focus.sh status                               # e.g. "block … · → Fajr 05:01"
```

## Notes
- **taskwarrior data** lives in `~/.task/taskchampion.sqlite3` (3.x, migrated 2026-07-18). Canonical binary = linuxbrew 3.4.2. `~/.local/bin/task` is **go-task** (a Taskfile runner), NOT taskwarrior — it must never win PATH; `/usr/bin/task` 2.6.2 is retired.
- **Notifier = caelestia** (quickshell; owns `org.freedesktop.Notifications`). It does **not** support `notify-send --wait`/`--action` (the probe hung, exit 124), so the nudge sends a plain non-blocking notification — the **Super+Shift+; keybind is the reliable one-key logging path**, independent of notification actions.
- **`hyprland.lua` is a chezmoi TEMPLATE** (`{{ .dracula.* }}` directives). Edit the live file AND `dotfiles/private_dot_config/hypr/hyprland.lua.tmpl` by hand, identically; NEVER `chezmoi add` the hypr file.
- **quickshell / caelestia is intact** — only the focus panel is unbound (Super+Shift+Enter rebound to the TUI). Full removal is a separate project.
- **Salah picker safety:** `adhd-salah-pick.sh` selects only `+salah +PENDING` tasks; with none pending it notifies "no pending prayer" and exits, touching nothing.

## Acceptance (user-assisted — run once to sign off Stage 2)
1. **Super+Shift+Enter** opens the floating Dracula taskwarrior-tui with the real tasks (not empty).
2. Start a task in the TUI → `/home/linuxbrew/.linuxbrew/bin/timew` (or `timew`) shows the interval (on-modify hook live under 3.4.2).
3. **Super+Shift+P** blanks the monitor + locks; unlocking restores the monitor and ends the `break` interval (`timew summary :today` shows a `break`).
4. **Super+Shift+;** opens the salah picker; one key sets `salah_status` + completes the prayer (`task <id> info` → `Salah` = value, status Completed).
5. Login auto-opens the TUI.
