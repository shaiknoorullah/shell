# Time-Tracking Stage 3 (Observe) — Design

Sub-spec of the master design (`2026-07-14-personal-time-tracking-observability-design.md` §5 Stage 3). Stages 1 (Capture) and 2 (Daily driver) are built + pushed; this is the Observe layer.

## 1. Goal
One Python rollup reads the three clocks + session log, writes a single SQLite file with idempotent upserts, and surfaces it two ways: **Datasette** (ad-hoc SQL) and an **Obsidian daily note + 14-day streak** (the motivational payoff). Reconcile the clocks — don't just sum them. Local-first, personal, never-guilt.

## 2. Locked (from master spec + brainstorm 2026-07-18) — do NOT reopen
- SQLite-in-git (NOT Postgres/Grafana/Dolt); Datasette + Obsidian view layer; 4am day boundary; Python + `sqlite-utils` idempotent-upsert rollup; categorization taxonomy Web/Code/Comms/Infra/Salah/breaks; never-lock / streak-positive.
- **taskchampion / taskchampion-sync-server does NOT fit the observe store** (it syncs Taskwarrior task-replicas only, not arbitrary tables). Task sync/backup is a **parked sibling project** (§9), revisit after Stage 3.
- **aw-watcher-web IS in scope** (per-domain web data). **Behavioral SQLite lives in a NEW private repo** on the personal account (never the public shell fork, never work/cluster infra).

## 3. Sources & read paths
| Source | Read path | Notes |
|---|---|---|
| taskwarrior 3.4.2 | `task export` (JSON) | uuid = stable key; carries `salah_status`, project, tags |
| timewarrior | `timew export` (JSON) | `{id,start,end,tags}`; open interval has no `end`; key = `start` |
| ActivityWatch | REST `http://127.0.0.1:5600/api/0/buckets/<b>/events` | `aw-watcher-window` (`{app,title}`) + `aw-watcher-afk`; titles carry tmux `session·window·cmd` |
| aw-watcher-web | AW bucket (browser watcher) | per-domain; **new capture component to install** |
| logind | `~/.local/share/timetrack/events/logind.jsonl` | `{ts,type}` lock/unlock/login boundaries |

## 4. Schema (each table upserts on a stable key — reruns never double-count)
| Table | Source | Key | Holds |
|---|---|---|---|
| `tasks` | `task export` | `uuid` | description, project, status, tags, due, end, `salah_status`, urgency |
| `intervals` | `timew export` | `start` | end, duration_s, tags → task/project |
| `sessions` | logind JSONL | `ts` | login/logout/lock/unlock boundaries |
| `usage` | AW window (aggregated) | `date+category+app+hour` | seconds per category/app — **aggregated, not raw events** (raw stays in aw-server → keeps git lean) |
| `web` | aw-watcher-web (aggregated) | `date+domain+hour` | seconds per domain |
| `breaks` | AW afk + timew + salah | `start` | duration_s, source=`auto`/`manual`/`salah`, label |
| `salah` | tasks (project:salah) | `date+prayer` | status (jamaah/alone/qaza/missed), due, logged_at |
| `daily_summary` | computed | `date` | per-category/project totals, breaks, salah n/5, clock-in/out |
| `adherence` | computed | `date` | clock_in_logged, salah_logged (n/5), breaks_labeled (n/m), coverage_pct (active time with a task running) |
| `reconciliation` | computed | `date` | the 3-clock disagreements (§6) |

Raw ActivityWatch events are **not** copied into the DB — the rollup aggregates them into `usage`/`web` per (date, category/app or domain, hour). aw-server remains the raw-event system of record.

## 5. Categorization
A git-tracked ordered rule file `categories.toml`, **first-match-wins**, matching **app + title regex** (must be title — nearly everything runs inside `kitty`/tmux). Examples:
```
[[rule]] match_title = "ovh|k8s|kubectl|cluster|argo|proxmox"   category = "Infra"
[[rule]] match_title = "dots|caelestia|nvim|\\.py|\\.rs|\\.ts"    category = "Code"
[[rule]] match_app   = "slack|teams|discord|thunderbird"          category = "Comms"
[[rule]] match_domain = "github|gitlab"                            category = "Code"
[[rule]] match_app   = "brave|firefox|zen"                        category = "Web"
```
No match → `Uncategorized` (a review bucket — never dropped). Rules are refined over time; it's just a versioned file.

## 6. Reconciliation (the master spec's "core value" — kept gentle, never-guilt)
Three per-day flags, computed from overlaying the clocks, surfaced only as *optional* review lines (never live nags):
- **active-untracked** — AW `not-afk` but no `timew` interval running ("worked but forgot to start a task").
- **task-AFK** — `timew` running but AW `afk` ("forgot to stop").
- **present-idle** — logged-in session but idle (no not-afk).
Each stored as minutes + a representative time window, for the daily note's "Review (optional)" line.

## 7. Views
### 7a. Obsidian daily note + streak (the payoff)
The rollup writes/updates one markdown note per day in the vault. Layout:
```
## ⏱ 2026-07-18   ·   day 6 of 14   ·   🔥 5-day streak

Clocked  07:12 → 21:40   ·   9h04 tracked   ·   coverage 82%
Where    Infra 3h20 ▓▓▓▓▓▓▓  Code 2h50 ▓▓▓▓▓▓  Comms 1h10 ▓▓  Web 1h05 ▓▓  Other 39m ▓
Web      github 40m · mail 15m · docs 10m
Breaks   5 · 1h05   (4 auto · 1 labeled)
Salah    ✅✅✅◻✅  logged 5/5   (Fajr jamaah · Dhuhr alone · Asr jamaah · Maghrib qaza · Isha jamaah)
Top      ovh-deployment 1h40 · tenant-app 1h10 · slack 55m

Review (optional)  ~35m active with no task ~14:00

14-day habit:  ▰▰▰▰▰▱▱▱▱▱▱▱▱▱   6/14
```
Plus a Dataview week/month rollup page reading the notes' frontmatter.

**Streak-counting rule (engagement, not perfection):** a day *counts* if you engaged with the system — clocked in **and** logged all 5 salah (marking a prayer `missed`/`qaza` still counts — honesty logs the day) **and** tracked ≥1 task. The streak rewards **logging**, never the values. 14-day sprint → graduation countdown.

### 7b. Datasette (ad-hoc SQL)
**On-demand** via an otter-launcher module (`datasette serve timetrack.db`) — matches the launcher hub, no always-on footprint. (Not a systemd service.)

## 8. Sync & cadence — "always fresh, ≤1 hr staleness"
Two jobs, different purposes:
- **Rollup timer — every 30 min:** pull all sources, upsert into the **local** `timetrack.db`, recompute today's `daily_summary`/`adherence`/`reconciliation`, refresh today's Obsidian note. → what you observe is ≤30 min stale (inside the 1-hr tolerance).
- **Git commit+push — hourly:** dump `timetrack.db` → **`sqlite-diffable` text** (one stable-sorted file per table), commit+push to the new private repo (**pull-before-write, single-writer**). Text diffs are tiny, so the repo stays small AND the backup is ≤1 hr behind. The binary `.db` stays local and is regenerable from the dump.
- **4am boundary** = the day-bucketing rule for summaries; independent of timer cadence. Timers use `Persistent=true` to catch up after downtime.

Net: observed data ≤30 min stale, backup ≤1 hr stale, repo stays lean.

## 9. Non-goals / parked
- **Task sync/backup** (taskchampion-sync-server or the S3/GCS/local cloud backends): a worthwhile *sibling* project — closes the "tasks have no proper backup" gap — but out of Observe scope. Revisit after Stage 3.
- Multi-writer / multi-device observe data (single-writer git is fine for one machine).
- Automatic task↔app linking (AW active-window → auto-assign a task): YAGNI.

## 10. Privacy & security
All behavioral telemetry (apps, titles, domains, AFK, session times) is personal, local-first, and pushed **only** to the new private personal-account repo — never work/cluster infra. aw-watcher-web logs browsing per-domain into the local DB; that data follows the same private-only rule.

## 11. Open items to resolve during planning
- Confirm `task export` output under 3.4.2 (the probe returned empty for `limit:1` — verify the rollup's read works before building on it).
- The `timew` interval → `task` linkage: confirm what the `on-modify.timewarrior` hook writes into interval tags (task uuid? description? project?) so `intervals` and `reconciliation` can join back to `tasks`.
- `sqlite-diffable` stable-sort per table so hourly diffs stay minimal (avoid whole-file rewrites).
- Which Obsidian vault path + note folder; Dataview frontmatter keys for the week/month rollup.
- aw-watcher-web: which browser + extension install path (Brave/Firefox/Zen), and its bucket id.
- The new private repo name (e.g. `shaiknoorullah/timetrack-data`) — user creates it; rollup wires to it.
