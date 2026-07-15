# Time-Tracking Stage 1 (Capture) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up always-on automatic capture — ActivityWatch (active window + AFK/breaks) and systemd-logind session/lock/suspend events — as the ground-truth safety net for the personal time-tracking system.

**Architecture:** `aw-server` (HTTP API + web UI on `127.0.0.1:5600`) and a `timetrack-logind` daemon run as enabled `systemd --user` services (neither needs Wayland). `awatcher` (single Rust binary combining the wlr-foreign-toplevel window watcher + ext-idle-notify AFK watcher) runs as a `systemd --user` service **triggered from `hyprland.lua`** so it inherits the Wayland session, mirroring the existing `systemctl --user start hyprpolkitagent.service` autostart. All artifacts are plain files (binaries in `~/.local/bin`, units in `~/.config/systemd/user`, data in `~/.local/share/timetrack`) so the parked nix migration can absorb them later.

**Tech Stack:** aw-server-rust, awatcher (2e3s/awatcher), systemd `--user`, systemd-logind D-Bus (system bus), Python 3.14 + `jeepney` (pure-Python D-Bus) in a dedicated venv, Hyprland (`wlr-foreign-toplevel-management` v3, `ext-idle-notifier-v1` v2 — both verified present).

## Global Constraints

- **Scope = Stage 1 only.** taskwarrior-tui, TUI rebind, salah tasks, nudges, and the rollup/SQLite/Datasette/Obsidian layer are LATER stages — do NOT build them here.
- **Do NOT touch taskwarrior 2.6.0 or timewarrior** — they already work via the `on-modify.timewarrior` hook.
- **AFK threshold = record every idle gap ≥ 180 seconds** (`idle-timeout-seconds = 180`, which is also awatcher's default).
- **Behavioral data stays local** — aw-server binds `127.0.0.1:5600` only; nothing is pushed anywhere in this stage.
- **Wayland-dependent service = awatcher only.** aw-server and timetrack-logind must NOT depend on Wayland.
- **Data home = `~/.local/share/timetrack/`**; event stream = `~/.local/share/timetrack/events/logind.jsonl` (append-only JSONL, one event per line).
- **Event JSONL schema (exact):** `{"ts": "<ISO-8601 with local offset>", "source": "logind", "type": "<type>", "detail": {...}}` where `<type>` ∈ `daemon-start | suspend | resume | lock | unlock | session-new | session-removed`.
- **Dotfiles sync:** binaries and generated data are runtime (not committed); the committed artifacts are the install/daemon scripts + systemd units + the one `hyprland.lua` line. Commit to the chezmoi-backed repo at `~/src/caelestia-shell` (chezmoi source under `~/src/caelestia-shell/dotfiles/`). Use `chezmoi add <live-path>` for new files.
- **`hyprland.lua` is a chezmoi TEMPLATE** (`~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl`) containing `{{ .dracula.* }}` directives. Do NOT `chezmoi add` it (that clobbers the directives). Edit the live file AND the `.tmpl` by hand with the identical one-line addition.
- These are infrastructure/daemon tasks: the "test" in each task is a **verification command** (service active, API returns data, emitted event appears in the log), not a unit test. Run the verification, confirm the expected output, then commit.

---

### Task 1: Project data home + Python venv (jeepney)

Creates the runtime data home and an isolated Python venv holding `jeepney` (used by the logind daemon in Task 4, and reused by Stage 3's rollup later). The committed artifact is an idempotent bootstrap script so the environment is reproducible on another machine.

**Files:**
- Create: `~/.local/bin/timetrack-bootstrap.sh`

**Interfaces:**
- Produces: data home `~/.local/share/timetrack/{events,}` and venv `~/.local/share/timetrack/venv` with `jeepney` importable; consumed by Task 4's unit (`…/venv/bin/python`).

- [ ] **Step 1: Write the bootstrap script**

Create `~/.local/bin/timetrack-bootstrap.sh`:

```bash
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
```

- [ ] **Step 2: Make it executable and run it**

Run:
```bash
chmod +x ~/.local/bin/timetrack-bootstrap.sh
~/.local/bin/timetrack-bootstrap.sh
```
Expected: final line `OK: data=/home/devsupreme/.local/share/timetrack venv=… jeepney=0.x.x`.

- [ ] **Step 3: Verify the venv imports jeepney and the dirs exist**

Run:
```bash
~/.local/share/timetrack/venv/bin/python -c "import jeepney; print('jeepney ok')" && ls -d ~/.local/share/timetrack/events
```
Expected: `jeepney ok` then the events dir path. If `python3 -m venv` fails (linuxbrew Python), retry with `/usr/bin/python3 -m venv` and record which interpreter worked in the script.

- [ ] **Step 4: Commit**

```bash
chezmoi add ~/.local/bin/timetrack-bootstrap.sh
git -C ~/src/caelestia-shell add -A
git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage1 — data home + jeepney venv bootstrap"
```

---

### Task 2: aw-server as an enabled systemd --user service

Installs the ActivityWatch server (Rust) and runs it always-on. It serves the web UI + REST API on `127.0.0.1:5600` that every later stage reads from. No Wayland dependency, so it is enabled at `default.target`.

**Files:**
- Create: `~/.local/bin/timetrack-install-aw-server.sh`
- Create: `~/.config/systemd/user/aw-server.service`

**Interfaces:**
- Produces: `~/.local/bin/aw-server` binary and a running service exposing `http://127.0.0.1:5600`; consumed by Task 3 (awatcher reports to it) and Stage 3 (rollup reads its API).

- [ ] **Step 1: Write the installer script**

Create `~/.local/bin/timetrack-install-aw-server.sh`:

```bash
#!/usr/bin/env bash
# Install the latest aw-server-rust linux binary to ~/.local/bin/aw-server (idempotent).
set -euo pipefail
DEST="$HOME/.local/bin/aw-server"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
url="$(curl -fsSL https://api.github.com/repos/ActivityWatch/aw-server-rust/releases/latest \
  | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 \
  | grep -iE 'x86[_-]64.*linux|linux.*x86[_-]64' | grep -iE '\.zip$|\.tar\.gz$' | head -1)"
[ -n "$url" ] || { echo "ERROR: no linux x86_64 asset found on latest aw-server-rust release"; exit 1; }
echo "Downloading: $url"
cd "$TMP"
curl -fsSL -o pkg "$url"
case "$url" in *.zip) unzip -q pkg ;; *.tar.gz) tar xzf pkg ;; esac
bin="$(find "$TMP" -type f -name 'aw-server*' -perm -u+x ! -name '*.zip' ! -name '*.tar.gz' | head -1)"
[ -n "$bin" ] || bin="$(find "$TMP" -type f -name 'aw-server' | head -1)"
[ -n "$bin" ] || { echo "ERROR: aw-server binary not found in archive"; exit 1; }
install -m 0755 "$bin" "$DEST"
echo "Installed: $DEST"; "$DEST" --version 2>/dev/null || true
```

- [ ] **Step 2: Run the installer and confirm the binary**

Run:
```bash
chmod +x ~/.local/bin/timetrack-install-aw-server.sh
~/.local/bin/timetrack-install-aw-server.sh
~/.local/bin/aw-server --version
```
Expected: `Installed: /home/devsupreme/.local/bin/aw-server` and a version line (e.g. `aw-server-rust 0.13.x`). If the archive layout differs and the binary isn't found, inspect the extracted tree and adjust the `find` in the script.

- [ ] **Step 3: Write the systemd --user unit**

Create `~/.config/systemd/user/aw-server.service`:

```ini
[Unit]
Description=ActivityWatch server (aw-server-rust)
After=default.target

[Service]
Type=simple
ExecStart=%h/.local/bin/aw-server
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

- [ ] **Step 4: Enable + start, then verify the API responds**

Run:
```bash
systemctl --user daemon-reload
systemctl --user enable --now aw-server.service
sleep 2
systemctl --user is-active aw-server.service
curl -fsS http://127.0.0.1:5600/api/0/info
```
Expected: `active`, then a JSON blob from `/api/0/info` (contains `"hostname"` and `"version"`).

- [ ] **Step 5: Commit**

```bash
chezmoi add ~/.local/bin/timetrack-install-aw-server.sh ~/.config/systemd/user/aw-server.service
git -C ~/src/caelestia-shell add -A
git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage1 — aw-server systemd --user service"
```

---

### Task 3: awatcher (window + AFK) triggered from Hyprland

Installs awatcher (single binary: active-window via wlr-foreign-toplevel + AFK via ext-idle-notify), configures the 180-second idle threshold, defines it as a `systemd --user` service that depends on aw-server, and autostarts it from `hyprland.lua` (so it inherits `WAYLAND_DISPLAY`). This is the piece that captures "what I worked on" and "every break".

**Files:**
- Create: `~/.local/bin/timetrack-install-awatcher.sh`
- Create: `~/.config/awatcher/config.toml`
- Create: `~/.config/systemd/user/awatcher.service`
- Modify: `~/.config/hypr/hyprland.lua` (add one autostart line after line 120) AND `~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl` (identical line — edit by hand, do NOT `chezmoi add`)

**Interfaces:**
- Consumes: aw-server on `127.0.0.1:5600` (Task 2).
- Produces: two aw-server buckets — a window-watcher bucket (`aw-watcher-window_<host>`) and an AFK bucket (`aw-watcher-afk_<host>`) — populated live.

- [ ] **Step 1: Write the awatcher installer**

Create `~/.local/bin/timetrack-install-awatcher.sh`:

```bash
#!/usr/bin/env bash
# Install the latest awatcher linux binary to ~/.local/bin/awatcher (idempotent).
set -euo pipefail
DEST="$HOME/.local/bin/awatcher"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
url="$(curl -fsSL https://api.github.com/repos/2e3s/awatcher/releases/latest \
  | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 \
  | grep -iE 'linux|gnu' | grep -viE '\.deb$|\.rpm$|\.sha256$|\.sig$|source' | head -1)"
[ -n "$url" ] || { echo "ERROR: no linux binary asset on latest awatcher release"; exit 1; }
echo "Downloading: $url"
cd "$TMP"; curl -fsSL -o dl "$url"
case "$url" in
  *.zip) unzip -q dl; bin="$(find "$TMP" -type f -name 'awatcher*' ! -name '*.zip' | head -1)";;
  *.tar.gz|*.tgz) tar xzf dl; bin="$(find "$TMP" -type f -name 'awatcher*' | head -1)";;
  *) bin="$TMP/dl";;
esac
[ -n "$bin" ] || { echo "ERROR: awatcher binary not found"; exit 1; }
install -m 0755 "$bin" "$DEST"
echo "Installed: $DEST"; "$DEST" --version 2>/dev/null || true
```

- [ ] **Step 2: Run the installer and confirm the binary**

Run:
```bash
chmod +x ~/.local/bin/timetrack-install-awatcher.sh
~/.local/bin/timetrack-install-awatcher.sh
~/.local/bin/awatcher --version
```
Expected: `Installed: /home/devsupreme/.local/bin/awatcher` and a version line. If the release ships only a `.deb`, extract the binary with `dpkg-deb -x <deb> "$TMP"` and copy `usr/bin/awatcher` — adjust the script accordingly.

- [ ] **Step 3: Generate the config, then pin the idle timeout to 180s**

Run awatcher once (with aw-server up) so it writes its default config, then confirm/set the threshold:
```bash
timeout 4 ~/.local/bin/awatcher || true
grep -n 'idle-timeout-seconds' ~/.config/awatcher/config.toml || true
```
Ensure `~/.config/awatcher/config.toml` contains (edit the value if the generated default differs):
```toml
[awatcher]
idle-timeout-seconds = 180
```
If awatcher could NOT generate the file (e.g. this shell has no `WAYLAND_DISPLAY`, so the run errored before writing config), create it by hand:
```bash
mkdir -p ~/.config/awatcher
printf '[awatcher]\nidle-timeout-seconds = 180\n' > ~/.config/awatcher/config.toml
```
Expected: the file exists and `idle-timeout-seconds = 180` is present. (180 is awatcher's default; set it explicitly so the ≥3-min break threshold is intentional and survives upstream default changes.)

- [ ] **Step 4: Write the awatcher systemd --user unit (NOT enabled; started from Hyprland)**

Create `~/.config/systemd/user/awatcher.service`:

```ini
[Unit]
Description=ActivityWatch awatcher (window + AFK, Wayland)
Requires=aw-server.service
After=aw-server.service

[Service]
Type=simple
ExecStart=%h/.local/bin/awatcher
Restart=on-failure
RestartSec=5
```

Note: no `[Install]`/`WantedBy` — this service is intentionally NOT enabled. It is started from `hyprland.lua` (next step) so it launches after the Wayland session exists. `Requires=aw-server.service` pulls the server in if it isn't already up.

- [ ] **Step 5: Add the Hyprland autostart line (live file + template, by hand)**

In `~/.config/hypr/hyprland.lua`, immediately after the existing line
`hl.exec_cmd("/home/devsupreme/.local/bin/clipse -listen")` (line ~120), add:
```lua
  hl.exec_cmd("systemctl --user start awatcher.service")     -- ActivityWatch window+AFK watcher (needs Wayland env)
```
Then add the **identical** line at the matching location in
`~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl`.
Do NOT run `chezmoi add` on the hypr file (it would overwrite the `{{ .dracula.* }}` directives).

- [ ] **Step 6: Start awatcher now and verify buckets fill**

Run:
```bash
systemctl --user daemon-reload
systemctl --user start awatcher.service
sleep 3
systemctl --user is-active awatcher.service
curl -fsS http://127.0.0.1:5600/api/0/buckets | tr ',' '\n' | grep -iE 'window|afk'
```
Expected: `active`, then bucket ids containing `aw-watcher-window_<host>` and `aw-watcher-afk_<host>`.

- [ ] **Step 7: Verify live window events (user-assisted)**

Focus a couple of different windows, wait ~10s, then run:
```bash
curl -fsS "http://127.0.0.1:5600/api/0/buckets/aw-watcher-window_$(hostname)/events?limit=3"
```
Expected: recent events with `data.app` / `data.title`. (If the window bucket id differs, use the exact id from Step 6.) **User-assisted note:** the ≥3-min AFK event only appears after 3 real minutes of no input — confirm later in Step of Task 5, not here.

- [ ] **Step 8: Commit**

```bash
chezmoi add ~/.local/bin/timetrack-install-awatcher.sh ~/.config/awatcher/config.toml ~/.config/systemd/user/awatcher.service
git -C ~/src/caelestia-shell add -A
git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage1 — awatcher window+AFK watcher (Hyprland-triggered)"
```

---

### Task 4: logind session/lock/suspend capture daemon

A small jeepney daemon subscribes to systemd-logind signals on the **system** bus and appends timestamped JSONL events. This is the authoritative source for presence (session start/stop), lock/unlock, and suspend/resume — the safety net for clock-in/out. No Wayland dependency, so it is enabled at `default.target`.

**Files:**
- Create: `~/.local/bin/timetrack-logind.py`
- Create: `~/.config/systemd/user/timetrack-logind.service`

**Interfaces:**
- Consumes: the venv from Task 1 (`~/.local/share/timetrack/venv/bin/python`).
- Produces: append-only `~/.local/share/timetrack/events/logind.jsonl` with records matching the Global-Constraints schema; consumed by Stage 3's rollup.

- [ ] **Step 1: Write the daemon**

Create `~/.local/bin/timetrack-logind.py`:

```python
#!/usr/bin/env python3
"""timetrack-logind.py — append systemd-logind session/lock/suspend events as JSONL.

Subscribes (system bus) to:
  org.freedesktop.login1.Manager: PrepareForSleep(b), SessionNew, SessionRemoved
  org.freedesktop.login1.Session: Lock, Unlock
Appends one JSON object per line to ~/.local/share/timetrack/events/logind.jsonl.
"""
import json
from datetime import datetime, timezone
from pathlib import Path

from jeepney import HeaderFields, MessageType, MatchRule, message_bus
from jeepney.io.blocking import open_dbus_connection

EVENTS = Path.home() / ".local/share/timetrack/events/logind.jsonl"
EVENTS.parent.mkdir(parents=True, exist_ok=True)


def emit(etype, detail=None):
    rec = {
        "ts": datetime.now(timezone.utc).astimezone().isoformat(),
        "source": "logind",
        "type": etype,
        "detail": detail or {},
    }
    with EVENTS.open("a") as f:
        f.write(json.dumps(rec) + "\n")
        f.flush()


def main():
    conn = open_dbus_connection(bus="SYSTEM")
    rules = [
        MatchRule(type="signal", interface="org.freedesktop.login1.Manager",
                  member="PrepareForSleep", path="/org/freedesktop/login1"),
        MatchRule(type="signal", interface="org.freedesktop.login1.Manager",
                  member="SessionNew", path="/org/freedesktop/login1"),
        MatchRule(type="signal", interface="org.freedesktop.login1.Manager",
                  member="SessionRemoved", path="/org/freedesktop/login1"),
        MatchRule(type="signal", interface="org.freedesktop.login1.Session", member="Lock"),
        MatchRule(type="signal", interface="org.freedesktop.login1.Session", member="Unlock"),
    ]
    for r in rules:
        conn.send_and_get_reply(message_bus.AddMatch(r))

    emit("daemon-start")

    while True:
        msg = conn.receive()
        if msg.header.message_type != MessageType.signal:
            continue
        member = msg.header.fields.get(HeaderFields.member)
        path = str(msg.header.fields.get(HeaderFields.path))
        body = list(msg.body) if msg.body else []
        if member == "PrepareForSleep":
            going = bool(body[0]) if body else None
            emit("suspend" if going else "resume", {"prepare_for_sleep": going})
        elif member == "Lock":
            emit("lock", {"path": path})
        elif member == "Unlock":
            emit("unlock", {"path": path})
        elif member == "SessionNew":
            emit("session-new", {"body": [str(b) for b in body]})
        elif member == "SessionRemoved":
            emit("session-removed", {"body": [str(b) for b in body]})


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Smoke-test the daemon by hand**

Run it in the foreground briefly, then in another shell emit a lock signal:
```bash
chmod +x ~/.local/bin/timetrack-logind.py
~/.local/share/timetrack/venv/bin/python ~/.local/bin/timetrack-logind.py &
DPID=$!
sleep 1
loginctl lock-session; sleep 1; loginctl unlock-session; sleep 1
kill "$DPID" 2>/dev/null || true
tail -n 5 ~/.local/share/timetrack/events/logind.jsonl
```
Expected: a `daemon-start` line, then a `lock` line, then an `unlock` line — each valid JSON with a `ts` carrying a local UTC offset. If `conn.receive()` raises `AttributeError`, consult jeepney's blocking API (the current method may be named differently, e.g. `recv_messages()`), fix the loop, and re-run. If `loginctl lock-session` does not produce a `lock` event, that is expected on setups where the compositor doesn't drive logind's lock hint — the suspend/resume + session events still validate the daemon; note it and continue (lock-hint wiring is resolved in Stage 2).

- [ ] **Step 3: Write the systemd --user unit**

Create `~/.config/systemd/user/timetrack-logind.service`:

```ini
[Unit]
Description=timetrack — systemd-logind session/lock/suspend capture
After=default.target

[Service]
Type=simple
ExecStart=%h/.local/share/timetrack/venv/bin/python %h/.local/bin/timetrack-logind.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

- [ ] **Step 4: Enable + start, then verify it records a live event**

Run:
```bash
systemctl --user daemon-reload
systemctl --user enable --now timetrack-logind.service
sleep 1
systemctl --user is-active timetrack-logind.service
loginctl lock-session; sleep 1; loginctl unlock-session; sleep 1
tail -n 3 ~/.local/share/timetrack/events/logind.jsonl
```
Expected: `active`, then fresh `lock`/`unlock` (or at minimum the periodic events) written by the service. Confirm no duplicate daemon is running: `pgrep -af timetrack-logind.py` shows exactly one (the service).

- [ ] **Step 5: Commit**

```bash
chezmoi add ~/.local/bin/timetrack-logind.py ~/.config/systemd/user/timetrack-logind.service
git -C ~/src/caelestia-shell add -A
git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage1 — logind session/lock/suspend capture daemon"
```

---

### Task 5: End-to-end Stage-1 verification + operator doc

Confirms the spec's Stage-1 done-when criteria and leaves a short operator note so future-you (and later stages) know what's running and how to check it.

**Files:**
- Create: `~/src/caelestia-shell/docs/superpowers/notes/2026-07-15-timetrack-stage1-runbook.md`

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: a committed runbook; a validated capture layer for Stage 2/3 to build on.

- [ ] **Step 1: Confirm all services are healthy**

Run:
```bash
systemctl --user is-active aw-server.service awatcher.service timetrack-logind.service
```
Expected: three lines, all `active`.

- [ ] **Step 2: Confirm the AW web UI shows today's timeline (user-assisted, visual)**

Open `http://127.0.0.1:5600` in the browser. Confirm the Activity view shows today with app/window time. **Then confirm an AFK gap is captured:** leave the machine with no keyboard/mouse input for **just over 3 minutes**, return, and check:
```bash
curl -fsS "http://127.0.0.1:5600/api/0/buckets/aw-watcher-afk_$(hostname)/events?limit=3"
```
Expected: at least one event with `data.status": "afk"` whose `duration` ≥ ~180s. (This step requires real idle time — it is the user's to confirm.)

- [ ] **Step 3: Confirm logind events are recorded**

Run:
```bash
grep -oE '"type": *"[a-z-]+"' ~/.local/share/timetrack/events/logind.jsonl | sort | uniq -c
```
Expected: counts for at least `daemon-start`, `lock`, `unlock` (and `suspend`/`resume`/`session-new` as they occur). Suspend/resume can be confirmed opportunistically on the next real suspend, or — only if safe to suspend now — via `systemctl suspend` then resume and re-checking for `suspend`/`resume` lines.

- [ ] **Step 4: Write the operator runbook**

Create `~/src/caelestia-shell/docs/superpowers/notes/2026-07-15-timetrack-stage1-runbook.md`:

```markdown
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
```

- [ ] **Step 5: Commit**

```bash
git -C ~/src/caelestia-shell add docs/superpowers/notes/2026-07-15-timetrack-stage1-runbook.md
git -C ~/src/caelestia-shell commit -m "docs(timetrack): stage1 capture runbook + done-when verification"
```

---

## Done-When (Stage 1 acceptance)

- `systemctl --user is-active aw-server.service awatcher.service timetrack-logind.service` → all `active`.
- `http://127.0.0.1:5600` shows today's app timeline, and an AFK event ≥180s is captured after 3+ minutes idle.
- `~/.local/share/timetrack/events/logind.jsonl` contains session/lock/suspend event lines matching the schema.
- taskwarrior 2.6.0 + timewarrior untouched and still working (`/usr/bin/task count` unchanged; `timew` still tracks on `task start/stop`).
