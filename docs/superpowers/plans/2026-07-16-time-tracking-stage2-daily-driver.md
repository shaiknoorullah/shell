# Time-Tracking Stage 2 (Daily Driver) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the quickshell task panel with taskwarrior-tui as the keyboard daily driver, add the break hotkey, salah tracking, and salah nudges — turning the Stage-1 passive capture into intentional, labeled work + break + prayer tracking.

**Architecture:** taskwarrior-tui (launched in a floating Dracula kitty on Super+Shift+Enter + an otter module + at login) drives taskwarrior 2.6.2 → timewarrior via the existing on-modify hook. A Super+Shift+P break hotkey pauses the active task (`timew start break`), turns the monitor off, and locks (via `loginctl lock-session`, which hypridle→hyprlock handles and the Stage-1 daemon records); hypridle's `unlock_cmd` ends the break. Salah is 5 daily-generated taskwarrior tasks (from `prayer-times.conf`) with a `salah_status` UDA; a per-prayer nudge reminds you and a one-key fzf picker records `jamaah/alone/qaza/missed`.

**Tech Stack:** taskwarrior 2.6.2 (`/usr/bin/task`), timewarrior + the `on-modify.timewarrior` hook, taskwarrior-tui 0.27 (cargo), kitty (Dracula floating window), Hyprland (`hyprland.lua` binds + window rules, `hypridle`, `hyprlock`), systemd `--user` transient timers (`systemd-run --on-calendar`), fzf, notify-send, otter-launcher.

## Global Constraints

- **Scope = Stage 2 only.** Do NOT touch the Stage-1 capture services (`aw-server`, `awatcher`, `timetrack-logind`). Do NOT build the Stage-3 SQLite/Datasette/Obsidian rollup.
- **taskwarrior binary MUST be `/usr/bin/task` (2.6.2)** everywhere taskwarrior-tui or a script runs `task` — the empty `~/.local/bin/task` (3.51.1) must never win PATH. Real data is in `~/.task` (11 tasks); the `on-modify.timewarrior` hook + timewarrior already work with 2.6.2. NO 2.x→3.x migration.
- **quickshell stays intact** — only stop *calling* the focus panel (rebind `Super+Shift+Enter` off `~/.local/bin/adhd-start.sh`). Fully reversible. Full removal is a separate project.
- **`hyprland.lua` is a chezmoi TEMPLATE** with `{{ .dracula.* }}` directives (`~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl`). Edit the live file AND the `.tmpl` by hand with identical changes; NEVER `chezmoi add` the hypr file.
- **Break hotkey = `Super+Shift+P`** (free): monitor-off + lock + break-marker. Lock via `loginctl lock-session` only (do NOT call hyprlock directly — hypridle already maps the logind Lock signal → hyprlock, and the Stage-1 daemon records the Lock/Unlock).
- **Salah status UDA values = exactly `jamaah`, `alone`, `qaza`, `missed`.** Salah tasks carry tag `salah` and `project:salah`, generated daily from `~/.config/adhd/prayer-times.conf` (`Name HH:MM` iqamah lines).
- **Nudges: streak-positive, never guilt.** Salah → a per-prayer reminder + a one-key fzf picker. Breaks → NO live nudge (auto-captured; labeled later).
- **All data stays local**; all artifacts are plain files (scripts in `~/.local/bin`, units in `~/.config/systemd/user`, configs in `~/.config`) so the parked nix migration can absorb them.
- **Dotfiles sync:** the committed artifacts are the scripts + units + config edits; commit to the chezmoi-backed repo `~/src/caelestia-shell` via `chezmoi add` of the live files (except the hypr template, edited by hand). `.superpowers/` is gitignored.
- These are infrastructure/config tasks: "tests" are verification commands (run it, observe output). Steps needing the live desktop (visual TUI, an actual prayer-time nudge, a real screen lock) are marked **[user-assisted]**.

---

### Task 1: taskwarrior-tui install + `/usr/bin/task` pin (wrapper)

Installs the TUI and guarantees it drives the real 2.6.2 database, not the empty 3.51.1 binary. The wrapper is the single launch entry point reused by the keybind, otter, and login autostart.

**Files:**
- Create: `~/.local/bin/tw-tui`

**Interfaces:**
- Produces: `~/.cargo/bin/taskwarrior-tui` (binary) and `~/.local/bin/tw-tui` (wrapper that runs it with `/usr/bin` ahead in PATH). Consumed by Tasks 2 (keybind/otter/login).

- [ ] **Step 1: Install taskwarrior-tui via cargo**

Run:
```bash
cargo install taskwarrior-tui
~/.cargo/bin/taskwarrior-tui --version
```
Expected: build succeeds; `taskwarrior-tui 0.27.0` (or newer). If the build fails on this toolchain, capture the error and report BLOCKED (do not silently fall back to a distro package).

- [ ] **Step 2: Write the pinning wrapper**

Create `~/.local/bin/tw-tui`:
```bash
#!/usr/bin/env bash
# tw-tui — launch taskwarrior-tui against the REAL taskwarrior 2.6.2 (/usr/bin/task).
# ~/.local/bin/task is an empty 3.51.1 SQLite build; putting /usr/bin first in PATH
# makes every `task` subprocess taskwarrior-tui spawns resolve to 2.6.2 (data in ~/.task).
exec env PATH="/usr/bin:$HOME/.cargo/bin:$PATH" "$HOME/.cargo/bin/taskwarrior-tui" "$@"
```

- [ ] **Step 3: Verify the wrapper resolves the right `task` and sees the real data**

Run:
```bash
chmod +x ~/.local/bin/tw-tui
env PATH="/usr/bin:$HOME/.cargo/bin:$PATH" bash -c 'command -v task; task --version; task rc.verbose=nothing count'
```
Expected: `/usr/bin/task`, `2.6.2`, and a task count matching `/usr/bin/task rc.verbose=nothing count` (11 at plan time). This proves that inside the wrapper's PATH, `task` is 2.6.2 with the real DB. (The interactive TUI itself is verified visually in Task 6 — **[user-assisted]**.)

- [ ] **Step 4: Commit**
```bash
chezmoi add ~/.local/bin/tw-tui
git -C ~/src/caelestia-shell add -A
git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage2 — taskwarrior-tui + /usr/bin/task pinning wrapper"
```

---

### Task 2: Floating Dracula TUI window — Super+Shift+Enter rebind + otter module + login auto-open

Makes `tw-tui` the daily driver: a floating Dracula kitty window bound to Super+Shift+Enter (rebound off the caelestia panel), reachable from otter, and auto-opened at login as the clock-in/resume flow.

**Files:**
- Modify: `~/.config/hypr/hyprland.lua` (live) AND `~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl` (by hand, identical)
- Modify: the otter generator `build_otter.py` (scratchpad) and regenerate `~/.config/otter-launcher/config.toml` — OR add the module directly if `build_otter.py` is unavailable (see step)

**Interfaces:**
- Consumes: `~/.local/bin/tw-tui` (Task 1).
- Produces: window class `tasktui` with a floating/centered Dracula rule; Super+Shift+Enter, otter `tw`, and login all launch `kitty --class tasktui --config ~/.config/kitty/otter.conf -e ~/.local/bin/tw-tui`.

- [ ] **Step 1: Rebind Super+Shift+Enter (live + template, by hand)**

In BOTH `~/.config/hypr/hyprland.lua` and `…/hyprland.lua.tmpl`, replace the line
`hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd("~/.local/bin/adhd-start.sh"))`
with:
```lua
hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd("kitty --class tasktui --config ~/.config/kitty/otter.conf -e ~/.local/bin/tw-tui"))  -- taskwarrior-tui daily driver (was caelestia focus panel)
```

- [ ] **Step 2: Add the floating Dracula window rule (live + template)**

Find the existing `clipse` window rules block (search `class = "^(clipse)$"`). After it, add the identical-shape rules for `tasktui` in BOTH files:
```lua
-- taskwarrior-tui: floating Dracula daily-driver panel (Super+Shift+Return / otter `tw`)
hl.window_rule({ match = { class = "^(tasktui)$" }, float = true })
hl.window_rule({ match = { class = "^(tasktui)$" }, center = true })
hl.window_rule({ match = { class = "^(tasktui)$" }, size = "1100 720" })
hl.window_rule({ match = { class = "^(tasktui)$" }, rounding = 5 })
```

- [ ] **Step 3: Auto-open at login (live + template)**

In the autostart block (near the `hl.exec_cmd(...)` lines around the clipse/awatcher lines), add in BOTH files:
```lua
  hl.exec_cmd("[workspace special:tasks silent] kitty --class tasktui --config ~/.config/kitty/otter.conf -e ~/.local/bin/tw-tui")  -- open the daily driver at login (clock-in / resume)
```
(If the `special:tasks` workspace syntax misbehaves on this Hyprland, drop the `[workspace …]` prefix so it opens on the current workspace — verify it doesn't steal focus disruptively; the floating rule keeps it contained.)

- [ ] **Step 4: Add the otter `tw` module**

If the scratchpad `build_otter.py` generator is present, add a module entry (mirroring the `cl`/`bt` unbind_proc modules) and regenerate:
```
[[modules]]
description = "  tasks"
prefix = "tw"
cmd = "kitty --class tasktui --config /home/devsupreme/.config/kitty/otter.conf -e /home/devsupreme/.local/bin/tw-tui"
unbind_proc = true
```
Regenerate with the generator, then verify the config parses: `otter-launcher </dev/null` exits cleanly. If `build_otter.py` is unavailable, append the same `[[modules]]` block to `~/.config/otter-launcher/config.toml` by hand and parse-check the same way.

- [ ] **Step 5: Reload Hyprland config and verify the bind/rule are registered (NON-disruptive)**

Run:
```bash
HIS=$(find /run/user/1001/hypr -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | head -1)
HYPRLAND_INSTANCE_SIGNATURE="$HIS" hyprctl reload 2>&1 | head
HYPRLAND_INSTANCE_SIGNATURE="$HIS" hyprctl binds -j 2>/dev/null | grep -c tasktui
```
Expected: `hyprctl reload` returns `ok`; the bind count for `tasktui` is ≥1. Confirm the `.tmpl` still has its `{{ .dracula.* }}` directives: `grep -c '{{ .dracula' …/hyprland.lua.tmpl` ≥ 2. **[user-assisted]** actually pressing Super+Shift+Enter and seeing the floating TUI is confirmed in Task 6.

- [ ] **Step 6: Commit**
```bash
# NOTE: do NOT chezmoi-add the hypr files. chezmoi-add only the otter config.
chezmoi add ~/.config/otter-launcher/config.toml
git -C ~/src/caelestia-shell add -A
git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage2 — tw-tui floating panel (Super+Shift+Enter, otter tw, login)"
```

---

### Task 3: Break hotkey (Super+Shift+P) + unlock handler

One press pauses the active task as a `break` interval, blanks the monitor, and locks; unlocking ends the break. Deliberate breaks become first-class timewarrior intervals; the idle-timeout lock is left alone (Stage-3 reconciles idle-during-task).

**Files:**
- Create: `~/.local/bin/adhd-break.sh`
- Create: `~/.local/bin/adhd-break-end.sh`
- Modify: `~/.config/hypr/hypridle.conf`
- Modify: `~/.config/hypr/hyprland.lua` (live) + `.tmpl` (by hand)

**Interfaces:**
- Consumes: `hypridle` (already runs hyprlock on `loginctl lock-session`), the Stage-1 `timetrack-logind` daemon (records Lock/Unlock), `/usr/bin/timew`.
- Produces: `adhd-break.sh` (start break + lock) and `adhd-break-end.sh` (stop break if active). A `break` interval in timewarrior tagged `break`.

- [ ] **Step 1: Write the break-start script**

Create `~/.local/bin/adhd-break.sh`:
```bash
#!/usr/bin/env bash
# adhd-break.sh (Super+Shift+P) — deliberate break: pause the active task as a `break`
# interval, blank the monitor, and lock. Unlock ends it (see adhd-break-end.sh).
set -uo pipefail
export PATH="/usr/bin:$HOME/.local/bin:$PATH"
TIMEW=/usr/bin/timew
STATE="$HOME/.cache/adhd/break-active"
mkdir -p "$(dirname "$STATE")"

# Record whether a task interval is currently active (so we know a break interrupted work).
if "$TIMEW" get dom.active >/dev/null 2>&1; then
    "$TIMEW" get dom.active.json 2>/dev/null > "$STATE" || echo '{}' > "$STATE"
else
    echo '{}' > "$STATE"
fi
# Start the break interval (timew tracks one interval at a time — this pauses any task).
"$TIMEW" start break >/dev/null 2>&1 || true
# Blank the monitor, then lock via logind (hypridle -> hyprlock; Stage-1 daemon logs Lock).
HIS=$(find /run/user/1001/hypr -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | head -1)
HYPRLAND_INSTANCE_SIGNATURE="$HIS" hyprctl dispatch dpms off >/dev/null 2>&1 || true
loginctl lock-session >/dev/null 2>&1 || true
```

- [ ] **Step 2: Write the unlock handler**

Create `~/.local/bin/adhd-break-end.sh`:
```bash
#!/usr/bin/env bash
# adhd-break-end.sh — run by hypridle unlock_cmd. Ends a deliberate break ONLY if a
# `break` interval is currently active (so a plain idle-lock unlock never stops a task).
set -uo pipefail
export PATH="/usr/bin:$HOME/.local/bin:$PATH"
TIMEW=/usr/bin/timew
STATE="$HOME/.cache/adhd/break-active"
HIS=$(find /run/user/1001/hypr -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | head -1)
HYPRLAND_INSTANCE_SIGNATURE="$HIS" hyprctl dispatch dpms on >/dev/null 2>&1 || true
# Only stop if the active interval is the break.
if "$TIMEW" get dom.active >/dev/null 2>&1; then
    tags="$("$TIMEW" get dom.active.tag.1 2>/dev/null; "$TIMEW" get dom.active.json 2>/dev/null)"
    if printf '%s' "$tags" | grep -qiw break; then
        "$TIMEW" stop >/dev/null 2>&1 || true
    fi
fi
rm -f "$STATE"
```

- [ ] **Step 3: Wire hypridle `unlock_cmd`**

In `~/.config/hypr/hypridle.conf`, inside the `general { … }` block (which already has `lock_cmd` and `before_sleep_cmd`), add:
```
    unlock_cmd = ~/.local/bin/adhd-break-end.sh    # end a deliberate break on unlock; turn monitor back on
```

- [ ] **Step 4: Bind Super+Shift+P (live + template)**

Add to BOTH `hyprland.lua` files, near the other `mod + SHIFT + …` binds:
```lua
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("~/.local/bin/adhd-break.sh"))  -- pause + monitor-off + lock (break)
```

- [ ] **Step 5: Verify the break interval logic WITHOUT locking the screen (headless test)**

Make both scripts executable and test the timew logic directly (do NOT run the full script — it would lock your screen):
```bash
chmod +x ~/.local/bin/adhd-break.sh ~/.local/bin/adhd-break-end.sh
/usr/bin/timew start break >/dev/null 2>&1; sleep 1
/usr/bin/timew get dom.active.tag.1        # expect: break
~/.local/bin/adhd-break-end.sh              # should stop the break (no task was active)
/usr/bin/timew get dom.active >/dev/null 2>&1 && echo "STILL ACTIVE (bad)" || echo "break stopped ✓"
```
Expected: `break`, then `break stopped ✓`. Reload hypridle so `unlock_cmd` takes effect: `HYPRLAND_INSTANCE_SIGNATURE=$(find /run/user/1001/hypr -mindepth 1 -maxdepth 1 -type d -printf '%f\n'|head -1) hyprctl reload` then restart hypridle: `systemctl --user restart hypridle 2>/dev/null || (pkill hypridle; setsid -f hypridle)`. **[user-assisted]** the full lock→unlock round-trip is confirmed in Task 6.

- [ ] **Step 6: Commit**
```bash
chezmoi add ~/.local/bin/adhd-break.sh ~/.local/bin/adhd-break-end.sh ~/.config/hypr/hypridle.conf
git -C ~/src/caelestia-shell add -A
git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage2 — Super+Shift+P break hotkey + hypridle unlock handler"
```

---

### Task 4: salah_status UDA + daily salah-task generation

Adds the `salah_status` UDA and a script (run daily via a systemd timer) that creates the day's 5 salah tasks from `prayer-times.conf` with the correct iqamah due times. Idempotent (never duplicates a day's tasks).

**Files:**
- Modify: `~/.taskrc`
- Create: `~/.local/bin/adhd-salah-tasks.sh`
- Create: `~/.config/systemd/user/adhd-salah-tasks.service`
- Create: `~/.config/systemd/user/adhd-salah-tasks.timer`

**Interfaces:**
- Consumes: `/usr/bin/task` (2.6.2), `~/.config/adhd/prayer-times.conf`.
- Produces: 5 tasks/day tagged `salah`, `project:salah`, with `due:<iqamah>` and an empty `salah_status`. Consumed by Task 5's picker (marks status + done).

- [ ] **Step 1: Declare the UDA in taskrc**

Append to `~/.taskrc`:
```
# Salah quality tracking (Stage-2 time-tracking system)
uda.salah_status.type=string
uda.salah_status.label=Salah
uda.salah_status.values=jamaah,alone,qaza,missed
```
Verify: `/usr/bin/task _get rc.uda.salah_status.values` → `jamaah,alone,qaza,missed`.

- [ ] **Step 2: Write the daily salah-task generator (idempotent)**

Create `~/.local/bin/adhd-salah-tasks.sh`:
```bash
#!/usr/bin/env bash
# adhd-salah-tasks.sh — create today's 5 salah tasks (tag salah, project:salah, due=iqamah)
# from ~/.config/adhd/prayer-times.conf. Idempotent: skips a prayer already created today.
set -uo pipefail
export PATH="/usr/bin:$PATH"
TASK=/usr/bin/task
CONF="$HOME/.config/adhd/prayer-times.conf"
[ -f "$CONF" ] || { echo "no prayer-times.conf"; exit 0; }
today="$(date +%Y-%m-%d)"
while read -r name t _rest; do
    case "$name" in ''|'#'*) continue ;; esac
    [ -z "${t:-}" ] && continue
    # Already have this prayer for today? (match tag salah + description + due date)
    existing="$($TASK rc.verbose=nothing +salah description:"$name" due.after:"${today}T00:00" due.before:"${today}T23:59" ids 2>/dev/null | tr -d '[:space:]')"
    [ -n "$existing" ] && continue
    $TASK add "$name" +salah project:salah due:"${today}T${t}" >/dev/null 2>&1 || true
done < "$CONF"
echo "salah tasks ensured for $today"
```

- [ ] **Step 3: Run it and verify the 5 tasks exist with due times**

Run:
```bash
chmod +x ~/.local/bin/adhd-salah-tasks.sh
~/.local/bin/adhd-salah-tasks.sh
/usr/bin/task rc.verbose=nothing +salah project:salah list 2>/dev/null
~/.local/bin/adhd-salah-tasks.sh   # second run must NOT create duplicates
echo "count: $(/usr/bin/task rc.verbose=nothing +salah project:salah count)"
```
Expected: 5 salah tasks (Fajr/Dhuhr/Asr/Maghrib/Isha) with today's due times; the re-run keeps count at 5 (idempotent).

- [ ] **Step 4: Daily systemd timer (regenerates each day, after prayer-times refresh)**

Create `~/.config/systemd/user/adhd-salah-tasks.service`:
```ini
[Unit]
Description=Generate today's salah tasks from prayer-times.conf

[Service]
Type=oneshot
ExecStart=%h/.local/bin/adhd-salah-tasks.sh
```
Create `~/.config/systemd/user/adhd-salah-tasks.timer`:
```ini
[Unit]
Description=Daily salah-task generation (+ at login)

[Timer]
OnCalendar=*-*-* 00:10:00
OnStartupSec=30
Persistent=true

[Install]
WantedBy=timers.target
```
Enable + verify:
```bash
systemctl --user daemon-reload
systemctl --user enable --now adhd-salah-tasks.timer
systemctl --user list-timers adhd-salah-tasks.timer --no-pager | head
```
Expected: the timer is listed with a next-elapse time.

- [ ] **Step 5: Commit**
```bash
chezmoi add ~/.taskrc ~/.local/bin/adhd-salah-tasks.sh ~/.config/systemd/user/adhd-salah-tasks.service ~/.config/systemd/user/adhd-salah-tasks.timer
git -C ~/src/caelestia-shell add -A
git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage2 — salah_status UDA + daily salah-task generation"
```

---

### Task 5: Salah nudge + one-key picker + per-prayer scheduling

At each prayer's iqamah time, a reminder fires; you answer with a one-key fzf picker that marks that prayer's `salah_status` and completes it. Scheduling re-arms daily because iqamah times change.

**Files:**
- Create: `~/.local/bin/adhd-salah-pick.sh`
- Create: `~/.local/bin/adhd-salah-nudge.sh`
- Create: `~/.local/bin/adhd-salah-schedule.sh`
- Create: `~/.config/systemd/user/adhd-salah-schedule.service` + `.timer`
- Modify: `~/.config/hypr/hyprland.lua` (live) + `.tmpl` — a keybind to open the picker on demand

**Interfaces:**
- Consumes: Task 4's salah tasks, `~/.config/adhd/prayer-times.conf`, fzf, notify-send, `~/.config/kitty/otter.conf`.
- Produces: a floating one-key picker that sets `salah_status:<value>` and `done`s the prayer; per-prayer transient timers created daily.

- [ ] **Step 1: Write the one-key picker (fzf, reliable — no notification-action dependency)**

Create `~/.local/bin/adhd-salah-pick.sh`:
```bash
#!/usr/bin/env bash
# adhd-salah-pick.sh [PrayerName] — mark a salah's status with ONE key and complete it.
# Picks the target task: the named prayer's pending task today, else the nearest-due pending salah.
set -uo pipefail
export PATH="/usr/bin:$HOME/.local/bin:$PATH"
TASK=/usr/bin/task
today="$(date +%Y-%m-%d)"
want="${1:-}"
sel_id() { $TASK rc.verbose=nothing +salah +PENDING "$@" ids 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+$' | head -1; }
id=""
[ -n "$want" ] && id="$(sel_id description:"$want" due.after:"${today}T00:00" due.before:"${today}T23:59")"
[ -z "$id" ] && id="$(sel_id due.before:"${today}T23:59")"
[ -z "$id" ] && { notify-send "🕌 Salah" "No pending prayer to log." 2>/dev/null; exit 0; }
desc="$($TASK _get "${id}.description" 2>/dev/null)"
choice="$(printf 'jamaah\nalone\nqaza\nmissed\n' | fzf --prompt="  $desc → " --height=100% --reverse --no-info \
    --color='bg:-1,bg+:-1,fg:-1,fg+:15,hl:5,hl+:13,pointer:5,prompt:5,marker:5,header:8' \
    2>/dev/null || true)"
[ -z "$choice" ] && exit 0
if [ "$choice" = "missed" ]; then
    $TASK "$id" modify salah_status:missed >/dev/null 2>&1
    $TASK "$id" done >/dev/null 2>&1
else
    $TASK "$id" modify salah_status:"$choice" >/dev/null 2>&1
    $TASK "$id" done >/dev/null 2>&1
fi
notify-send "🕌 $desc" "logged: $choice" 2>/dev/null || true
```
(The picker is launched inside a floating kitty in Step 4 so it's one-key from a keybind; `jamaah/alone/qaza/missed` are chosen by typing the first letter + Enter, or arrow+Enter.)

- [ ] **Step 2: Write the per-prayer nudge**

Create `~/.local/bin/adhd-salah-nudge.sh`:
```bash
#!/usr/bin/env bash
# adhd-salah-nudge.sh PrayerName — fire the prayer reminder. Sends a notification; the
# one-key answer is the picker (opened via the keybind or, if the notifier supports
# actions, the notification's default action). Streak-positive wording, never guilt.
set -uo pipefail
export PATH="/usr/bin:$HOME/.local/bin:$PATH"
name="${1:-Salah}"
# notify-send with a default action; if the notifier (caelestia) supports actions, activating
# it opens the picker. Harmless if actions are unsupported — it's still a reminder.
act="$(notify-send --wait --action=log="Log now" "🕌 $name" "Iqamah time — log when you're back. (Super+Shift+; to log)" 2>/dev/null || true)"
[ "$act" = "log" ] && setsid -f kitty --class salahpick --config "$HOME/.config/kitty/otter.conf" -e "$HOME/.local/bin/adhd-salah-pick.sh" "$name"
```

- [ ] **Step 3: Verify notifier action support (records reality; picker works regardless)**

Run:
```bash
timeout 6 notify-send --wait --action=log="Log now" "🕌 test" "action support probe" 2>&1; echo "[exit=$?]"
```
Note in the report whether the notifier returns an action or ignores `--action` (caelestia may not support `--wait`/actions). Either way the picker keybind (Step 4) is the reliable path — do NOT block on action support.

- [ ] **Step 4: Bind the picker + add its floating window rule (live + template)**

Add to BOTH `hyprland.lua` files:
```lua
hl.bind(mod .. " + SHIFT + semicolon", hl.dsp.exec_cmd("kitty --class salahpick --config ~/.config/kitty/otter.conf -e ~/.local/bin/adhd-salah-pick.sh"))  -- one-key salah logger
-- salahpick: floating one-key salah picker
hl.window_rule({ match = { class = "^(salahpick)$" }, float = true })
hl.window_rule({ match = { class = "^(salahpick)$" }, center = true })
hl.window_rule({ match = { class = "^(salahpick)$" }, size = "560 320" })
hl.window_rule({ match = { class = "^(salahpick)$" }, rounding = 5 })
```

- [ ] **Step 5: Write the daily scheduler (re-arms per-prayer nudges from prayer-times.conf)**

Create `~/.local/bin/adhd-salah-schedule.sh`:
```bash
#!/usr/bin/env bash
# adhd-salah-schedule.sh — schedule today's 5 salah nudges as transient user timers at each
# iqamah time. Re-run daily (times change). Skips prayer times already past for today.
set -uo pipefail
export PATH="/usr/bin:$PATH"
CONF="$HOME/.config/adhd/prayer-times.conf"
[ -f "$CONF" ] || exit 0
now="$(date +%H%M)"
while read -r name t _rest; do
    case "$name" in ''|'#'*) continue ;; esac
    [ -z "${t:-}" ] && continue
    hhmm="${t/:/}"
    [ "$hhmm" -le "$now" ] 2>/dev/null && continue   # already passed today
    systemd-run --user --quiet \
        --on-calendar="*-*-* ${t}:00" \
        --timer-property=AccuracySec=30s \
        --unit="adhd-salah-nudge-${name}" \
        "$HOME/.local/bin/adhd-salah-nudge.sh" "$name" 2>/dev/null || true
done < "$CONF"
echo "salah nudges scheduled"
```

- [ ] **Step 6: Daily scheduler timer + verify a nudge end-to-end**

Create `~/.config/systemd/user/adhd-salah-schedule.service`:
```ini
[Unit]
Description=Schedule today's salah nudges

[Service]
Type=oneshot
ExecStart=%h/.local/bin/adhd-salah-schedule.sh
```
Create `~/.config/systemd/user/adhd-salah-schedule.timer`:
```ini
[Unit]
Description=Daily salah-nudge scheduling (+ at login)

[Timer]
OnCalendar=*-*-* 00:12:00
OnStartupSec=45
Persistent=true

[Install]
WantedBy=timers.target
```
Enable + smoke-test the nudge path without waiting for a real prayer time:
```bash
chmod +x ~/.local/bin/adhd-salah-pick.sh ~/.local/bin/adhd-salah-nudge.sh ~/.local/bin/adhd-salah-schedule.sh
systemctl --user daemon-reload
systemctl --user enable --now adhd-salah-schedule.timer
~/.local/bin/adhd-salah-schedule.sh
systemctl --user list-timers 'adhd-salah-nudge-*' --no-pager | head
```
Expected: transient `adhd-salah-nudge-<Prayer>` timers listed for upcoming prayers. **[user-assisted]** firing a real nudge + one-keying a status in the picker, and confirming the salah task flips to `done` with `salah_status`, is confirmed in Task 6.

- [ ] **Step 7: Commit**
```bash
chezmoi add ~/.local/bin/adhd-salah-pick.sh ~/.local/bin/adhd-salah-nudge.sh ~/.local/bin/adhd-salah-schedule.sh ~/.config/systemd/user/adhd-salah-schedule.service ~/.config/systemd/user/adhd-salah-schedule.timer
git -C ~/src/caelestia-shell add -A
git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage2 — salah nudge + one-key picker + daily scheduling"
```

---

### Task 6: Retire the .cache/adhd actuator + salah-runway + end-to-end verification & runbook

Disables the old quickshell command-actuator, keeps the prayer-runway available, runs the user-assisted acceptance checks, and documents the daily driver.

**Files:**
- Create: `~/src/caelestia-shell/docs/superpowers/notes/2026-07-16-timetrack-stage2-runbook.md`

**Interfaces:**
- Consumes: everything from Tasks 1–5.

- [ ] **Step 1: Retire the old actuator (if present) — reversible**

The quickshell panel used a `~/.cache/adhd/task-cmd` actuator wired via systemd path units. Disable them if they exist (do not delete the scripts — reversible):
```bash
for u in adhd-task-cmd.path adhd-task-cmd.service; do
  systemctl --user disable --now "$u" 2>/dev/null && echo "disabled $u" || echo "$u not present"
done
```

- [ ] **Step 2: Confirm the salah-runway is still reachable**

The existing `~/.local/bin/adhd-focus.sh status` computes the next prayer from `prayer-times.conf`. Confirm it still works (it's the runway the panel showed):
```bash
~/.local/bin/adhd-focus.sh status 2>/dev/null || echo "adhd-focus.sh status unavailable — note for runbook"
```
Expected: a line like `idle · → Asr 17:15` (or similar). If unavailable, note it; a one-line `printf` runway from `prayer-times.conf` is an acceptable substitute (record in the runbook).

- [ ] **Step 3: [user-assisted] End-to-end acceptance (the human drives these)**

Confirm with the user:
1. **Super+Shift+Enter** opens the floating Dracula taskwarrior-tui showing the **real 11 tasks** (not empty).
2. Starting/stopping a task in the TUI drives timewarrior (`/usr/bin/timew` shows the interval).
3. **Super+Shift+P** blanks the monitor + locks; unlocking turns the monitor back on and (if a break was active) stops the `break` interval — `/usr/bin/timew summary :today` shows a `break`.
4. **Super+Shift+;** opens the salah picker; one key sets `salah_status` and completes the prayer (`/usr/bin/task <id> info` shows `Salah` = the value, status Completed).
5. Login auto-opens the TUI.

- [ ] **Step 4: Write the runbook**

Create `~/src/caelestia-shell/docs/superpowers/notes/2026-07-16-timetrack-stage2-runbook.md`:
```markdown
# Time-Tracking Stage 2 (Daily Driver) — Runbook

## Keys
- Super+Shift+Enter — taskwarrior-tui (daily driver; auto-opens at login). otter: `tw`.
- Super+Shift+P — break: pause active task (timew `break`) + monitor off + lock. Unlock ends it.
- Super+Shift+; — one-key salah logger (jamaah/alone/qaza/missed).

## Pieces
- `~/.local/bin/tw-tui` — launches taskwarrior-tui with /usr/bin/task (2.6.2) pinned in PATH.
- `~/.local/bin/adhd-break.sh` / `adhd-break-end.sh` — break start / unlock handler (hypridle unlock_cmd).
- `~/.local/bin/adhd-salah-tasks.sh` (+ .timer) — daily generates 5 salah tasks from prayer-times.conf.
- `~/.local/bin/adhd-salah-schedule.sh` (+ .timer) — daily arms per-prayer nudge timers.
- `~/.local/bin/adhd-salah-nudge.sh` / `adhd-salah-pick.sh` — reminder + one-key logger.
- UDA `salah_status` (jamaah/alone/qaza/missed) in ~/.taskrc.

## Health
    systemctl --user list-timers 'adhd-salah-*' --no-pager
    /usr/bin/task rc.verbose=nothing +salah project:salah list
    env PATH=/usr/bin:$PATH task --version   # must be 2.6.2

## Notes
- taskwarrior data lives in ~/.task (2.6.2). NEVER let ~/.local/bin/task (3.51.1) win PATH.
- Notifications route through caelestia; the salah picker keybind is the reliable one-key path
  regardless of notification-action support.
- quickshell focus panel is only unbound (Super+Shift+Enter rebound), not removed — reversible.
```

- [ ] **Step 5: Commit**
```bash
git -C ~/src/caelestia-shell add docs/superpowers/notes/2026-07-16-timetrack-stage2-runbook.md
git -C ~/src/caelestia-shell commit -m "docs(timetrack): stage2 daily-driver runbook + acceptance"
```

---

## Done-When (Stage 2 acceptance)
- Super+Shift+Enter (and login, and otter `tw`) open a floating Dracula taskwarrior-tui showing the real 2.6.2 tasks; start/stop drives timewarrior.
- Super+Shift+P → monitor off + lock + `break` interval; unlock ends it (verified via `timew summary :today`).
- 5 salah tasks generated daily with iqamah due times; Super+Shift+; logs `salah_status` (jamaah/alone/qaza/missed) + completes the prayer; per-prayer nudge timers arm daily.
- The `~/.cache/adhd` actuator is disabled; quickshell otherwise intact (only the key rebound).
- Stage-1 capture services untouched; taskwarrior 2.6.2 + timewarrior + hook still working.
