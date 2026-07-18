# Time-Tracking Stage 3 (Observe) — Runbook

The observe layer over Stages 1 (Capture) and 2 (Daily driver): one Python
rollup reads taskwarrior + timewarrior + ActivityWatch (window/AFK/web) +
logind, writes idempotent upserts into a single local SQLite file, and
surfaces it two ways — Datasette (ad-hoc SQL) and an Obsidian daily note with
a never-guilt streak. All data is local-first; the only thing that leaves the
machine is a text dump pushed to a private personal-account git repo.

## Pipeline
```
task export ─┐
timew export ─┤
AW window/afk/web (REST) ─┼──▶ rollup (categorize.py) ──▶ timetrack.db (SQLite) ──┬──▶ Obsidian daily note (note.py)
logind.jsonl ─┘                                                                    └──▶ sqlite-diffable dump ──▶ private timetrack-data repo (sync.py)
```
- `rollup_raw` — reads sources for the current 4am-logical day, aggregates AW
  window events into `usage` (date+category+app+hour), AW afk spans ≥180s into
  `breaks`, and upserts `tasks`/`intervals`/`sessions` verbatim.
- `rollup_web` — same aggregation shape for the aw-watcher-web bucket into
  `web` (date+domain+hour), domain = `urlparse(url).hostname`, categorized via
  `categorize(domain=host)`. Guarded: only runs when a web bucket is resolved
  (see below) — a no-op until aw-watcher-web is installed (Step 2, pending).
- `rollup_derived` — computes `salah`, `daily_summary`, `adherence`,
  `reconciliation` (the 3-clock disagreements: active-untracked, task-AFK,
  present-idle) and the engagement-based `streak`.
- `note.write` — renders/overwrites `~/powerhouse/timetrack/daily/<date>.md`
  with per-category time bars, salah ticks, streak, and an optional
  never-guilt review line.
- `sync.push` — dumps every non-`_`-prefixed table to a stable-sorted
  `sqlite-diffable` text format (`tables/<table>.ndjson` + `.metadata.json`)
  and commits+pushes to the private data repo, pull-before-write.

## Paths
| What | Path |
|---|---|
| Package (chezmoi-managed) | `~/.local/share/timetrack/lib/timetrack/` (`config.py`, `db.py`, `categorize.py`, `sources.py`, `rollup.py`, `note.py`, `sync.py`, `__main__.py`) |
| Tests | `~/.local/share/timetrack/lib/tests/` |
| venv | `~/.local/share/timetrack/venv/` (python + `sqlite-utils` + `datasette` + `requests`) |
| DB | `~/.local/share/timetrack/timetrack.db` (local only, never committed as binary) |
| Data repo (git backup target) | `~/.local/share/timetrack/data-repo/` — clone of the **private** `timetrack-data` repo (Step 3, pending — not yet created) |
| Categorization rules | `~/.config/timetrack/categories.toml` (versioned, chezmoi-managed) |
| Obsidian vault notes | `~/powerhouse/timetrack/daily/<YYYY-MM-DD>.md` (PERSONAL vault, NOT chezmoi-managed) |
| CLI entrypoint | `~/.local/bin/timetrack` (execs `venv/bin/python -m timetrack` with `PYTHONPATH` set to the lib dir) |
| Datasette launcher | `~/.local/bin/timetrack-datasette` |
| systemd user units | `~/.config/systemd/user/timetrack-{rollup,sync}.{service,timer}`, `timetrack-logind.service` |

## Timers
| Timer | Cadence | What it does | Freshness contract |
|---|---|---|---|
| `timetrack-rollup.timer` | `OnCalendar=*:0/30` (every 30 min) | `timetrack rollup` then `timetrack note` | local DB ≤30 min stale |
| `timetrack-sync.timer` | `OnCalendar=*:05` (hourly, :05 past) | `timetrack sync` | private-repo backup ≤1 h stale |

Both are `Persistent=true` (catch up after sleep/suspend) with an
`OnStartupSec` stagger so they don't collide with each other or with Stage-1
services on login.

## CLI
```
timetrack rollup   # rollup_raw + web (if bucket resolved) + rollup_derived only
timetrack note     # (re)render today's Obsidian note from the current DB state
timetrack sync     # dump + commit + push to the private data repo
timetrack all      # rollup -> note -> sync, in that order (what the timers effectively do)
```
`rollup`/`note`/`sync` are each idempotent — safe to run out-of-band by hand
(e.g. right after installing aw-watcher-web, or after editing
`categories.toml`). Every table upserts on its stable key (`db.PKS`), EXCEPT
`usage`/`web`: `rollup_raw`/`rollup_web` each delete the day's existing
`usage`/`web` rows before inserting the freshly-aggregated ones (replace-the-
day), because `usage`'s pk (`date,category,app,hour`) includes `category` —
an upsert alone can't remove the old-category row when an app is
re-categorized, so re-running rollup after editing `categories.toml` cleanly
recategorizes with no orphaned/double-counted rows.

## The `web` bucket (aw-watcher-web wiring)
`rollup_web(db, day, web_events, rules)` is wired into `__main__._do_rollup`
behind a resolver: use `config.WEB_BUCKET` if explicitly set, otherwise
auto-detect via `sources.list_aw_buckets()` — the first bucket whose name
contains `"web"` (case-insensitive). If neither resolves, the web rollup is
skipped entirely (no AW call, no `web` rows) — this is the current state
until Step 2 (installing the browser extension) is done. Once installed,
either leave `WEB_BUCKET = None` (auto-detect) or pin the exact bucket id in
`config.py` for determinism, then `chezmoi add` the change.

## categories.toml refine-loop
`categorize.py` is first-match-wins over `[[rule]]` blocks (`match_app` /
`match_title` / `match_domain`, regex, case-insensitive); anything matching
nothing lands in `Uncategorized` — a review bucket, never dropped or hidden.
The loop:
1. Let the rollup run for a while (days–weeks).
2. Query Datasette (`tt` in otter) or `sqlite3 timetrack.db` for
   `Uncategorized` rows in `usage`/`web` — see which apps/titles/domains keep
   showing up unclassified.
3. Add/adjust a `[[rule]]` in `~/.config/timetrack/categories.toml` (ordered —
   put more specific rules before broader catch-alls, since first match
   wins).
4. Re-run `timetrack rollup` (safe — `rollup_raw`/`rollup_web` REPLACE the
   day's `usage`/`web` rows outright — delete-then-insert — before
   `rollup_derived` recomputes `daily_summary`/etc. from them, so an app that
   moved categories doesn't leave an orphaned old-category row behind; no
   double count).
5. `chezmoi add ~/.config/timetrack/categories.toml`, commit — the rule file
   is versioned like code.

## Private-repo / single-writer rule
The behavioral SQLite data is personal and sensitive (window titles, URLs,
salah adherence) — it goes to a **NEW PRIVATE** repo on the **personal**
GitHub account (suggested `shaiknoorullah/timetrack-data`), **never** the
public `shaiknoorullah/shell` fork and **never** any work/cluster repo.
`sync.push()` is pull-before-write (`git pull --quiet --no-rebase` before
dumping+committing) to stay correct even if pushed from more than one place,
but the design assumes a **single writer** (this one machine) — it is not a
multi-device sync protocol. The dump format (`sqlite-diffable`: one
stable-sorted `.ndjson` + `.metadata.json` per table) is chosen so identical
data produces byte-identical output — hourly diffs stay minimal and the
repo's history stays lean even though it syncs hourly forever.

## Health checks
```bash
systemctl --user list-timers 'timetrack-*' --no-pager      # both timers armed + last/next run
sqlite3 ~/.local/share/timetrack/timetrack.db '.tables'     # all 10 tables present
sqlite3 ~/.local/share/timetrack/timetrack.db \
  'select date,tracked_seconds,salah_logged from daily_summary order by date desc limit 5'
git -C ~/.local/share/timetrack/data-repo log --oneline -5  # backup is landing (once Step 3 is done)
curl -s http://127.0.0.1:5600/api/0/buckets/ | grep -i web  # confirms the web bucket id, if installed
cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest -q   # full test suite, offline
```
If `timetrack-rollup.service` or `timetrack-sync.service` shows `failed` (not
just an old `inactive`), the systemd default restart burst was exhausted —
clear and retry the same way as Stage 1:
```bash
systemctl --user reset-failed timetrack-rollup.service timetrack-sync.service
journalctl --user -u timetrack-rollup.service -n 50
```

## Datasette (`tt` in otter)
`~/.local/bin/timetrack-datasette` execs
`~/.local/share/timetrack/venv/bin/datasette serve
~/.local/share/timetrack/timetrack.db --open`. The `tt` otter-launcher module
(prefix `tt` in `~/.config/otter-launcher/config.toml`) opens it in a
dedicated `kitty --class datasette` window using the same floating
`otter.conf` surface as the other on-demand tools (`wp`, `bt`, `cl`, `tw`).
On-demand only — nothing runs Datasette as a background service.

## Vault / note location
`~/powerhouse/timetrack/daily/<YYYY-MM-DD>.md` — one file per logical day
(4am boundary), overwritten idempotently on every rollup. Frontmatter is
Dataview-ready (`tracked_seconds`, `salah_logged`, `streak`, `counts`
booleans) so `~/powerhouse` queries can roll it up further. This is the
PERSONAL `powerhouse` vault, not chezmoi-managed and not this repo.

## Notes
- Stage-1 capture (`aw-server`, `awatcher`, `timetrack-logind`) and Stage-2
  daily driver (taskwarrior-tui, break hotkey, salah picker) are untouched by
  Stage 3 — the rollup is strictly **read-only** against all of them.
- `rollup_web` ships inert: `config.WEB_BUCKET = None` by default and the
  auto-detect resolver returns `None` when no bucket exists, so `timetrack
  rollup` today runs exactly as it did before this change until Step 2 is
  done by hand.
- The `web` table's primary key is `(date, domain, hour)` — it does not key
  on category, since a domain's category is deterministic from
  `categories.toml`; re-categorizing only changes future rollups' output
  (rerun `timetrack rollup` after editing rules to refresh it for today).

## Pending (user-assisted — not done by this change)
1. **Install aw-watcher-web** in Brave or Firefox, verify the bucket via
   `curl -s http://127.0.0.1:5600/api/0/buckets/ | grep -i web`, optionally
   pin it in `config.py`'s `WEB_BUCKET`, `chezmoi add` + commit.
2. **Create the private `timetrack-data` repo** on the personal GitHub
   account, clone it to `~/.local/share/timetrack/data-repo`, run `timetrack
   sync` once and confirm a commit landed and the repo shows **Private** on
   GitHub.
3. **End-to-end acceptance**: `timetrack all` runs clean; today's note
   renders with categories + salah ticks + streak; `tt` opens Datasette with
   rows in the tables; the private repo has a commit and is Private; both
   timers are armed; Stage-1/2 timers/services are still present and
   untouched.
