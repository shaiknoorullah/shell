# Personal Capture-and-Observe Time-Tracking System — Design

**Date:** 2026-07-14
**Status:** Approved (design); ready for per-stage implementation planning
**Author:** devsupreme (with Claude)

## 1. Goal

Capture **everything I work on and every break** — automatically as ground truth, manually as the habit — store it durably and portably, and make it **observable later** where I already look. Secondary: retire the flaky quickshell/caelestia task panel, and use a 2-week sprint to build the manual-logging habit.

Success = at the end I can answer, for any day/week: what I worked on and for how long, when I logged in/out, every break (including which salah and its quality), and how consistently I logged it myself vs. the system catching it for me.

## 2. Current state (ground truth, verified 2026-07-13/14)

- **taskwarrior 2.6.0** holds the real task data (`~/.task/*.data`, 7 tasks; `news.version=2.6.0`). The `~/.local/bin/task` 3.51.1 binary is a *different, empty* SQLite backend — a PATH-shadowing footgun.
- **timewarrior 1.7.1** with real data, driven automatically by the **`on-modify.timewarrior` hook** in `~/.task/hooks` on every `task start/stop`. This is the existing, working task↔time integration and is kept.
- **ActivityWatch: not installed** — no server, watchers, config, or units. Net-new.
- **quickshell/caelestia = the entire desktop shell** (bar, notifications, wallpaper, lock, OSD, dashboard, launcher, … + the `modules/tasks/` focus panel). Runs from a read-only nix-store path (`quickshell -p /nix/store/…-caelestia-shell/share/caelestia-shell`), not from `~/src/caelestia-shell`.
- The current focus panel is bound to **Super+Shift+Enter** → `adhd-start.sh` → `caelestia-shell ipc call panel focus`. Its "stop" ran `adhd-focus.sh stop` (`task stop` + delete state). Bug-2 ("timer resets on stop") is a **display artifact**: every block was already saved as a timewarrior interval; the panel only displayed the *open* interval's duration. The data was never lost.
- **ytm** = `ytm-player` v1.9.4, a YouTube-Music TUI with full headless subcommands (`play/pause/next/prev/like/now/status/…`). Parked as a separate music menu, out of scope here.
- Machine is a **Code42-monitored work laptop** used as the personal daily driver. Wayland/Hyprland.

## 3. Locked decisions

1. **Task TUI = `taskwarrior-tui`** (kdheepak, Rust), NOT Tuxedo. Tuxedo is a todo.txt tool with zero taskwarrior/timewarrior/time-tracking support — structurally incompatible with the tracking goal.
2. **Keep taskwarrior 2.6.0 + timewarrior + the hook.** No 2.x→3.x migration (separate, riskier, unneeded here).
3. **Observe store = one SQLite file in git**, viewed with **Datasette** (power) + **Obsidian** (glance). NOT Postgres+Grafana (too heavy), NOT Obsidian-as-DB (can't hold/aggregate the AW firehose), NOT Dolt (MySQL server; solves multi-writer merge, a problem we don't have).
4. **Day boundary = fixed 04:00 local cutoff** (salah-anchored day; avoids midnight splits of late sessions).
5. **Salah status enum = `jamaah / alone / qaza / missed`** (adds "on-time but solo/munfarid" to the user's original three).
6. **Lock policy = break-hotkey + long backstop, NO short idle-lock.** A "break" hotkey does monitor-off **+ session lock + break-marker** in one action; a single **~30-min continuous-AFK backstop** locks a truly-abandoned machine. No flow-breaking idle timer. (Rationale: monitor-off alone does not lock → open work session; AFK tracking is independent of lock state.)
7. **Manual-primary, auto-fallback.** Manual logging (clock-in/out, salah, breaks) is the *habit*; logind + AFK capture is the *safety net* AND the ruler that measures adherence.
8. **Habit scaffold is streak-positive, never guilt.** Misses are silently auto-captured; the system celebrates hits and never shames a gap. Time-boxed **14-day sprint** with graduation ramp-down.

## 4. Architecture

```
CAPTURE (manual habit + auto safety-net)     RAW STORES (stay put)     ROLLUP                 OBSERVE
────────────────────────────────────────     ─────────────────────     ──────                 ───────
taskwarrior (what)          ──hook──▶  ~/.task (2.6.0)           ┐
timewarrior (time on task)  ◀────────  ~/.timewarrior            │
ActivityWatch: window+AFK   ─────────▶  aw-server SQLite          ├─▶ rollup script ─▶ one SQLite ─┬─▶ Datasette (ad-hoc SQL/API)
systemd-logind: session/    ─────────▶  journald / logind        │   (python +        file, git-   └─▶ Obsidian daily note
  lock/suspend                                                    ┘   sqlite-utils)    synced           (+ Dataview, 14-day streak)
manual actions (clock-in/out, salah, break-label) ──▶ taskwarrior / a small event log ┘
```

Three capture tools keep their own stores; **no database server runs**. A scheduled, **idempotent** rollup reads their JSON exports plus the manual event log, writes one SQLite file, and commits it to a private personal git repo. Two views read that one file.

A cross-cutting **nudge + adherence layer** fires cue-based prompts (login, 5 salah, return-from-gap, leaving) and measures manual-vs-fallback adherence.

## 5. Components by stage

Each stage is independently installable/testable and gets its own implementation plan. Build order: **1 → 2 → 3**; the habit sprint activates once 1–2 land.

### Stage 1 — Capture (ActivityWatch + logind)

- Install **aw-server** (local `:5600`, stores its own SQLite) + a **Wayland-capable watcher** for active-window + AFK. *Exact pick (`awatcher` vs `aw-watcher-window-wayland`) verified in the Stage-1 plan against Hyprland's `wlr-foreign-toplevel-management`.*
- Run watchers + server as **systemd user services** (always-on, restart-on-login).
- **AFK config:** record every gap ≥ **3 min** as data; this is the automatic break/break-fallback signal (independent of screen-lock state).
- **logind capture:** a small user service records session start/stop, lock/unlock, suspend/resume with timestamps (from logind D-Bus signals / journald) into the event stream — the authoritative presence/session source and the safety net for clock-in/out.
- **Done when:** `localhost:5600` shows today's app timeline + AFK gaps, and session/lock/suspend events are being recorded.

### Stage 2 — Daily driver + manual actions + nudges

- Install **taskwarrior-tui** (supports taskwarrior ≥ 2.6.0).
- **Fix the version-split footgun:** pin the TUI and all scripts to `/usr/bin/task` (2.6.0, where data lives) so the empty 3.51.1 binary cannot shadow it.
- **Rebind Super+Shift+Enter** from the caelestia IPC call → a **floating Dracula kitty window running taskwarrior-tui** (same window-rule pattern as bluetuith/clipse). Add an otter module too. On **login**, auto-open it as the "start the day / clock-in" flow (resume backlog or create new).
- **quickshell panel goes dormant** — we stop *calling* `panel focus`; the QML is untouched and fully reversible. Full removal of `modules/tasks/` belongs to the separate minimal-rebuild (project C), not here.
- Retire the `~/.cache/adhd` command-actuator layer (the TUI talks to `task` directly).
- **Break hotkey** (e.g. Super+Shift+B): monitor-off (DPMS) **+ lock + break-marker** in one keystroke. Plus a **~30-min continuous-AFK backstop lock**. *(Whether physical-monitor-button DPMS-off is reliably detectable on this Hyprland setup is a Stage-2 investigation; the hotkey is the robust path.)*
- **Salah model:** 5 daily **recurring taskwarrior tasks** (tag `salah`, one per prayer, `due` = time from `~/.config/adhd/prayer-times.conf`) with a **`salah_status` UDA** (`jamaah/alone/qaza/missed`). Marking a prayer records quality; duration comes free from the AFK gap. These due-times regenerate the **prayer-runway** lost from quickshell.
- **Nudge service (cue → tiny prompt → one key):**
  - login → TUI clock-in flow.
  - each salah time → distinct nudge "🕌 <Prayer> — [j/a/q/m]", one key logs prayer+quality.
  - return from a gap → label-after "away N min — [salah/lunch/break/rabbit-hole]?".
  - leaving → the break hotkey *is* the log.
- **Anti-fatigue:** capture every ≥3-min gap as data, but only *prompt* on large gaps (≥ ~10–15 min); batch-label the small ones in one end-of-session pass. No per-gap interruption.
- **Feature-deltas acknowledged:** salah-runway must be re-provided (nudge service / thin status line); the actuator layer is retired, not maintained.

### Stage 3 — Observe (SQLite-in-git + Datasette + Obsidian)

- **Rollup script** (Python + `sqlite-utils`, dogsheep-style), on a systemd timer + on-demand: pulls `timew export` + ActivityWatch API + `task export` + the logind/manual event log; writes tables into one SQLite file with **idempotent upserts** keyed on stable event IDs.
- **Data model (sketch):** `sessions` (login→logout, lock/suspend), `intervals` (timew: start/end/task/project/tags/duration), `events` (AW: ts/duration/app/title/afk), `tasks` (task export), `salah` (date/prayer/status/duration), `breaks` (start/end/duration/label/source=auto|manual), `daily_summary`, `adherence` (per-day: clock-in/out logged?, salah logged n/5, breaks labeled n/m, manual-vs-fallback).
- **Reconciliation (the core value):** flag the three clocks disagreeing — active-but-untracked ("worked but no task running"), task-active-but-AFK ("forgot to stop"), present-but-idle. AW is the safety net that surfaces untracked work.
- **Git sync:** commit the SQLite file (optional `sqlite-diffable` dump for readable history) to a **private repo on the personal GitHub account** (never work/cluster infra). **Single-writer discipline:** pull-before-write, push-after.
- **Views:** **Datasette** locally (ad-hoc SQL + JSON API) and an **Obsidian daily note** the script writes (time-per-project, breaks, salah, top apps) with a **Dataview** week/month rollup and a **14-day streak tracker / graduation countdown**.

## 6. Loopholes & mitigations

- **monitor-off ≠ lock** → break hotkey locks; 30-min AFK backstop catches forgets. (Decision 6)
- **Prompt fatigue** kills ADHD systems → capture-all-as-data, prompt only on big gaps, batch the rest. (Stage 2)
- **Three clocks disagree** → rollup reconciles + flags, doesn't just sum. (Stage 3)
- **Rollup double-counting** → idempotent upserts on stable IDs.
- **SQLite-in-git can't merge** → single-writer discipline (one machine writes at a time).
- **AFK false-positives** (long reading/watching with no input reads as "break") → threshold + manual reclassification; accepted limitation.
- **Version-split** (`~/.local/bin/task` 3.51.1 empty) → pin `/usr/bin/task` everywhere.
- **Guilt backfires** → streak-positive scoreboard, misses silently auto-captured.

## 7. Non-goals / out of scope

- Full quickshell removal / minimal-desktop rebuild (**project C**, separate).
- taskwarrior 2.x→3.x migration.
- Multi-writer data / Dolt.
- Automatic task↔app linking (AW active-window → auto-assign task): possible later, YAGNI now.
- **ytm music menu** (parked, small, separate) and **quickshell arrow-nav fix** (skipped — panel is being retired).

## 8. Privacy & security

Behavioral telemetry (apps used, AFK, session times) is **personal, local-first, and stored only on the personal GitHub account** — never the work/cluster observability stack. The 30-min lock backstop keeps the work machine from sitting unlocked. This is a design guardrail, not optional.

## 9. Forward-compatibility

New scripts/configs are authored as plain files (systemd user units, shell/python scripts, kitty/hypr config, Obsidian notes) so the **parked nix-dotfiles migration** can absorb them later without special handling.

## 10. Open items to resolve during implementation

- Exact Wayland AW watcher for Hyprland (`awatcher` vs `aw-watcher-window-wayland`).
- Whether physical-monitor-button DPMS-off is reliably detectable (else hotkey-only).
- How taskwarrior-tui surfaces cumulative timew time per task (display detail).
- Final nudge delivery mechanism (notifications vs a thin always-visible status line) and one-key answer path (otter module vs dedicated script).
- Where manual break-labels and manual clock-in/out are recorded (timewarrior `break` intervals/tags vs a lightweight append-only JSONL event log), given logind is the auto source of truth for sessions.
