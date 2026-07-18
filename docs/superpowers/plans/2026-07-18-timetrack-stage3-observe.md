# Time-Tracking Stage 3 (Observe) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Python rollup reads taskwarrior 3.x + timewarrior + ActivityWatch + logind into one SQLite-in-git file (idempotent upserts), surfaced as an Obsidian daily note + 14-day streak and an on-demand Datasette.

**Architecture:** A small importable package `timetrack` (pure-function source readers → sqlite-utils schema/upserts → aggregation + 3-clock reconciliation → Obsidian-note renderer → sqlite-diffable git sync), driven by a CLI (`timetrack rollup|note|sync|all`) on two `systemd --user` timers (rollup 30 min, sync hourly). All logic is TDD'd against JSON fixtures; only live-desktop/browser/Obsidian steps are user-assisted.

**Tech Stack:** Python 3.14 (linuxbrew venv), `sqlite-utils`, `datasette`, `sqlite-diffable`, `requests`, `tomllib` (stdlib), `pytest`; systemd user timers; git.

## Global Constraints

- **Scope = Stage 3 (Observe) only.** Do NOT touch Stage-1 capture services (`aw-server`, `awatcher`, `timetrack-logind`) or Stage-2 (taskwarrior-tui, salah, break hotkey). The rollup is READ-ONLY against all sources.
- **taskwarrior binary = linuxbrew 3.4.2** (`/home/linuxbrew/.linuxbrew/bin/task`); timew = `/home/linuxbrew/.linuxbrew/bin/timew`. NEVER `/usr/bin/task` (2.6.2, retired) or `~/.local/bin/task` (that is go-task, NOT taskwarrior). Read tasks via `task export` (JSON, key `uuid`; `salah_status` present only when set).
- **timew interval tags = `[project, description]`** (from the `on-modify.timewarrior` hook). No uuid — join intervals→tasks best-effort by `(description, project)`; categorize intervals directly from these tags.
- **One SQLite file** `~/.local/share/timetrack/timetrack.db` (local, NOT committed as binary). Git backup = a **`sqlite-diffable` stable-sorted text dump** committed hourly to a NEW PRIVATE personal-account repo (never the public `shaiknoorullah/shell` fork, never work/cluster infra). Single-writer: pull-before-write.
- **4am day boundary**: `logical_date(dt) = (dt - 4h).date()`. Timers use `Persistent=true`.
- **Categorization taxonomy** = Web / Code / Comms / Infra / Salah / Break / Other(Uncategorized). Rule file first-match-wins on app+title(+domain).
- **Never-guilt / streak-positive**: reconciliation flags surface as optional review lines, never live nags. A day "counts" for the streak on ENGAGEMENT (clock-in logged AND salah 5/5 logged incl. `missed`/`qaza` AND ≥1 task tracked), never on the values.
- **aw-watcher-web IS in scope** (per-domain Web data); its bucket must be added by installing the browser extension (user-assisted).
- **Obsidian vault = `~/powerhouse`** (personal). NEVER write to `~/work/fleet-home/vault` (work).
- **Plain files** so the parked nix migration absorbs them: package under `~/.local/share/timetrack/lib/`, config in `~/.config/timetrack/`, wrapper in `~/.local/bin`, units in `~/.config/systemd/user`. Commit via `chezmoi add` of the live files; `docs/` committed directly. The venv, `timetrack.db`, and the data-repo clone are runtime state — NOT chezmoi-managed.
- **Tests**: these are data-transform modules — TDD against JSON fixtures. `pytest` run via the venv: `~/.local/share/timetrack/venv/bin/python -m pytest`. Steps needing the live desktop/browser/Obsidian (aw-watcher-web install, the rendered note, a real Datasette session, the real git push) are marked **[user-assisted]**.

**Paths (canonical — use verbatim):**
- Venv: `~/.local/share/timetrack/venv` (exists from Stage 1; extend it)
- Package: `~/.local/share/timetrack/lib/timetrack/` (modules) + `~/.local/share/timetrack/lib/tests/`
- Config: `~/.config/timetrack/categories.toml`
- Wrapper: `~/.local/bin/timetrack`
- DB (local): `~/.local/share/timetrack/timetrack.db`
- Data-repo clone (git): `~/.local/share/timetrack/data-repo/` (the private repo; dump into `data-repo/tables/`)
- Daily notes: `~/powerhouse/timetrack/daily/YYYY-MM-DD.md`
- Units: `~/.config/systemd/user/timetrack-{rollup,sync}.{service,timer}`

---

### Task 1: Environment + read-path verification + package skeleton

Extend the Stage-1 venv with the rollup deps, verify the three read paths return data under 3.4.2, and scaffold the importable package with `config.py`.

**Files:**
- Create: `~/.local/share/timetrack/lib/timetrack/__init__.py`
- Create: `~/.local/share/timetrack/lib/timetrack/config.py`
- Create: `~/.local/share/timetrack/lib/tests/conftest.py`
- Create: `~/.local/share/timetrack/lib/tests/test_config.py`

**Interfaces:**
- Produces: `config.py` with `TASK`, `TIMEW`, `AW_BASE`, `LOGIND_JSONL`, `DB_PATH`, `DATA_REPO`, `VAULT_DAILY`, `CATEGORIES_TOML`, `DAY_BOUNDARY_HOUR=4`, and `logical_date(dt: datetime) -> date`. Consumed by every later task.

- [ ] **Step 1: Install rollup deps into the existing venv + verify read paths**

Run:
```bash
V=~/.local/share/timetrack/venv
"$V/bin/pip" install --quiet sqlite-utils datasette sqlite-diffable requests pytest
"$V/bin/python" -c "import sqlite_utils, requests, tomllib; print('deps OK', sqlite_utils.__version__)"
# read paths (all must print non-empty):
/home/linuxbrew/.linuxbrew/bin/task export | "$V/bin/python" -c "import sys,json;print('tasks',len(json.load(sys.stdin)))"
/home/linuxbrew/.linuxbrew/bin/timew export | "$V/bin/python" -c "import sys,json;print('intervals',len(json.load(sys.stdin)))"
curl -s http://127.0.0.1:5600/api/0/buckets/ | "$V/bin/python" -c "import sys,json;print('aw buckets',list(json.load(sys.stdin)))"
```
Expected: `deps OK <ver>`, `tasks 29` (±), `intervals 16` (±), and the aw buckets list including `aw-watcher-window_devsupreme` + `aw-watcher-afk_devsupreme`. If any is empty, STOP and report — the rollup depends on these.

- [ ] **Step 2: Write the failing test for `logical_date` (4am boundary)**

Create `~/.local/share/timetrack/lib/tests/conftest.py`:
```python
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))  # make `timetrack` importable
```
Create `~/.local/share/timetrack/lib/tests/test_config.py`:
```python
from datetime import datetime, date
from timetrack.config import logical_date

def test_before_4am_belongs_to_previous_day():
    assert logical_date(datetime(2026, 7, 18, 3, 59)) == date(2026, 7, 17)

def test_at_or_after_4am_is_same_day():
    assert logical_date(datetime(2026, 7, 18, 4, 0)) == date(2026, 7, 18)
    assert logical_date(datetime(2026, 7, 18, 23, 30)) == date(2026, 7, 18)
```

- [ ] **Step 3: Run it — must fail (no module yet)**

Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_config.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'timetrack'`.

- [ ] **Step 4: Create the package + config**

Create `~/.local/share/timetrack/lib/timetrack/__init__.py`:
```python
```
Create `~/.local/share/timetrack/lib/timetrack/config.py`:
```python
"""Canonical paths + the 4am logical-day boundary for the timetrack rollup."""
import os
from datetime import datetime, date, timedelta
from pathlib import Path

HOME = Path.home()

TASK = "/home/linuxbrew/.linuxbrew/bin/task"      # taskwarrior 3.4.2 (NOT /usr/bin, NOT go-task)
TIMEW = "/home/linuxbrew/.linuxbrew/bin/timew"
AW_BASE = "http://127.0.0.1:5600"
LOGIND_JSONL = HOME / ".local/share/timetrack/events/logind.jsonl"

DB_PATH = HOME / ".local/share/timetrack/timetrack.db"
DATA_REPO = HOME / ".local/share/timetrack/data-repo"      # private git clone; dump into DATA_REPO/tables/
VAULT_DAILY = HOME / "powerhouse/timetrack/daily"          # PERSONAL vault only
CATEGORIES_TOML = HOME / ".config/timetrack/categories.toml"

DAY_BOUNDARY_HOUR = 4

def logical_date(dt: datetime) -> date:
    """The 'day' a timestamp belongs to, with the day starting at 04:00 local."""
    return (dt - timedelta(hours=DAY_BOUNDARY_HOUR)).date()
```

- [ ] **Step 5: Run tests — must pass**

Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_config.py -q`
Expected: PASS (2 passed).

- [ ] **Step 6: Commit**

```bash
chezmoi add ~/.local/share/timetrack/lib/timetrack/__init__.py ~/.local/share/timetrack/lib/timetrack/config.py ~/.local/share/timetrack/lib/tests/conftest.py ~/.local/share/timetrack/lib/tests/test_config.py
git -C ~/src/caelestia-shell add -A
git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage3 — venv deps + package skeleton + 4am logical_date"
```

---

### Task 2: Source readers (`sources.py`)

Pure functions that read each source and return normalized `list[dict]`. No DB, no side effects — trivially testable.

**Files:**
- Create: `~/.local/share/timetrack/lib/timetrack/sources.py`
- Create: `~/.local/share/timetrack/lib/tests/fixtures/` (sample JSON)
- Create: `~/.local/share/timetrack/lib/tests/test_sources.py`

**Interfaces:**
- Produces:
  - `read_tasks() -> list[dict]` — from `task export`; each dict has `uuid, description, project, status, tags, entry, modified, due, end, urgency, salah_status` (missing keys → `None`).
  - `read_intervals() -> list[dict]` — from `timew export`; each `{start, end, tags}` with `start`/`end` as ISO strings (`end=None` if open).
  - `read_aw_events(bucket, start_iso, end_iso) -> list[dict]` — GET AW events; each `{id, timestamp, duration, data}`.
  - `list_aw_buckets() -> list[str]`.
  - `read_logind() -> list[dict]` — parse the JSONL; each `{ts, type, detail}`.
  - Constants `WINDOW_BUCKET="aw-watcher-window_devsupreme"`, `AFK_BUCKET="aw-watcher-afk_devsupreme"`.
- Consumes: `config.TASK/TIMEW/AW_BASE/LOGIND_JSONL`.

- [ ] **Step 1: Write fixtures + failing tests**

Create `~/.local/share/timetrack/lib/tests/fixtures/task_export.json`:
```json
[{"uuid":"aaaa","description":"cluster bootstrap + wave 1 deployment","project":"work","status":"pending","tags":["today"],"entry":"20260718T000000Z","modified":"20260718T000000Z","urgency":19.8},
 {"uuid":"bbbb","description":"Asr","project":"salah","status":"completed","tags":["salah"],"salah_status":"jamaah","end":"20260718T120000Z","entry":"20260718T000000Z","modified":"20260718T120000Z","urgency":10.3}]
```
Create `~/.local/share/timetrack/lib/tests/fixtures/timew_export.json`:
```json
[{"id":2,"start":"20260718T083000Z","end":"20260718T093000Z","tags":["work","cluster bootstrap + wave 1 deployment"]},
 {"id":1,"start":"20260718T100000Z","tags":["work","tenant-app fix"]}]
```
Create `~/.local/share/timetrack/lib/tests/test_sources.py`:
```python
import json, pathlib, subprocess
from timetrack import sources
FIX = pathlib.Path(__file__).parent / "fixtures"

def test_read_tasks_normalizes_missing_keys(monkeypatch):
    raw = (FIX / "task_export.json").read_text()
    monkeypatch.setattr(sources, "_run", lambda *a, **k: raw)
    tasks = sources.read_tasks()
    assert tasks[0]["uuid"] == "aaaa"
    assert tasks[0]["salah_status"] is None          # missing → None
    assert tasks[1]["salah_status"] == "jamaah"

def test_read_intervals_open_interval_has_none_end(monkeypatch):
    raw = (FIX / "timew_export.json").read_text()
    monkeypatch.setattr(sources, "_run", lambda *a, **k: raw)
    iv = sources.read_intervals()
    assert iv[0]["end"] == "20260718T093000Z"
    assert iv[1]["end"] is None
    assert iv[1]["tags"] == ["work", "tenant-app fix"]

def test_read_logind_parses_jsonl(tmp_path, monkeypatch):
    f = tmp_path / "logind.jsonl"
    f.write_text('{"ts":"2026-07-18T00:39:46+05:30","type":"lock","detail":{}}\n')
    monkeypatch.setattr(sources.config, "LOGIND_JSONL", f)
    ev = sources.read_logind()
    assert ev[0]["type"] == "lock"
```

- [ ] **Step 2: Run — must fail**

Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_sources.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'timetrack.sources'`.

- [ ] **Step 3: Implement `sources.py`**

Create `~/.local/share/timetrack/lib/timetrack/sources.py`:
```python
"""Read-only normalized readers for taskwarrior / timewarrior / ActivityWatch / logind."""
import json, subprocess
import requests
from . import config

WINDOW_BUCKET = "aw-watcher-window_devsupreme"
AFK_BUCKET = "aw-watcher-afk_devsupreme"

_TASK_KEYS = ["uuid","description","project","status","tags","entry","modified","due","end","urgency","salah_status"]

def _run(cmd: list[str]) -> str:
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout

def read_tasks() -> list[dict]:
    data = json.loads(_run([config.TASK, "export"]) or "[]")
    return [{k: t.get(k) for k in _TASK_KEYS} for t in data]

def read_intervals() -> list[dict]:
    data = json.loads(_run([config.TIMEW, "export"]) or "[]")
    return [{"start": i.get("start"), "end": i.get("end"), "tags": i.get("tags", [])} for i in data]

def list_aw_buckets() -> list[str]:
    return list(requests.get(f"{config.AW_BASE}/api/0/buckets/", timeout=10).json())

def read_aw_events(bucket: str, start_iso: str, end_iso: str) -> list[dict]:
    r = requests.get(f"{config.AW_BASE}/api/0/buckets/{bucket}/events",
                     params={"start": start_iso, "end": end_iso, "limit": -1}, timeout=30)
    if r.status_code == 404:
        return []
    r.raise_for_status()
    return r.json()

def read_logind() -> list[dict]:
    if not config.LOGIND_JSONL.exists():
        return []
    out = []
    for line in config.LOGIND_JSONL.read_text().splitlines():
        line = line.strip()
        if line:
            out.append(json.loads(line))
    return out
```

- [ ] **Step 4: Run — must pass**

Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_sources.py -q`
Expected: PASS (3 passed).

- [ ] **Step 5: Commit**

```bash
chezmoi add ~/.local/share/timetrack/lib/timetrack/sources.py ~/.local/share/timetrack/lib/tests/test_sources.py ~/.local/share/timetrack/lib/tests/fixtures/task_export.json ~/.local/share/timetrack/lib/tests/fixtures/timew_export.json
git -C ~/src/caelestia-shell add -A && git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage3 — normalized source readers (task/timew/AW/logind)"
```

---

### Task 3: Categorization (`categorize.py` + `categories.toml`)

First-match-wins rules over `app` + `title` + `domain`; anything unmatched → `Uncategorized`.

**Files:**
- Create: `~/.config/timetrack/categories.toml`
- Create: `~/.local/share/timetrack/lib/timetrack/categorize.py`
- Create: `~/.local/share/timetrack/lib/tests/test_categorize.py`

**Interfaces:**
- Produces: `load_rules(path=config.CATEGORIES_TOML) -> list[dict]`; `categorize(app, title, domain=None, rules=None) -> str`. Consumed by the rollup's aggregation (Task 5).

- [ ] **Step 1: Write the rule file**

Create `~/.config/timetrack/categories.toml`:
```toml
# First match wins. Each rule matches ANY of the provided fields (regex, case-insensitive).
# Fields: match_app, match_title, match_domain. Unmatched -> "Uncategorized".
[[rule]]
category = "Salah"
match_title = "salah|fajr|dhuhr|asr|maghrib|isha"

[[rule]]
category = "Infra"
match_title = "ovh|k8s|kubectl|cluster|argo|proxmox|ansible|terraform|kube"

[[rule]]
category = "Code"
match_title = "dots|caelestia|nvim|vim |\\.py\\b|\\.rs\\b|\\.ts\\b|git |cargo|pnpm"
match_domain = "github|gitlab|stackoverflow"

[[rule]]
category = "Comms"
match_app = "slack|teams|discord|thunderbird|evolution"
match_domain = "mail\\.google|outlook|slack"

[[rule]]
category = "Web"
match_app = "brave|firefox|zen|chromium|chrome"
```

- [ ] **Step 2: Write failing tests**

Create `~/.local/share/timetrack/lib/tests/test_categorize.py`:
```python
from timetrack import categorize

RULES = [
    {"category": "Salah", "match_title": "salah|asr"},
    {"category": "Infra", "match_title": "ovh|k8s|kubectl|cluster"},
    {"category": "Code", "match_title": "dots|nvim", "match_domain": "github"},
    {"category": "Comms", "match_app": "slack|teams"},
    {"category": "Web", "match_app": "brave|firefox"},
]

def test_first_match_wins_title():
    assert categorize.categorize("kitty", "ovh-deployment cluster", rules=RULES) == "Infra"

def test_app_rule():
    assert categorize.categorize("slack", "anything", rules=RULES) == "Comms"

def test_domain_rule_beats_generic_web():
    # a github domain in Brave -> Code (rule order), not Web
    assert categorize.categorize("brave", "PR #12", domain="github.com", rules=RULES) == "Code"

def test_unmatched_is_uncategorized():
    assert categorize.categorize("kitty", " random musing", rules=RULES) == "Uncategorized"
```

- [ ] **Step 3: Run — must fail**

Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_categorize.py -q`
Expected: FAIL — no module `timetrack.categorize`.

- [ ] **Step 4: Implement**

Create `~/.local/share/timetrack/lib/timetrack/categorize.py`:
```python
"""Rule-based categorization of activity into the fixed taxonomy."""
import re, tomllib
from . import config

UNCATEGORIZED = "Uncategorized"

def load_rules(path=None) -> list[dict]:
    path = path or config.CATEGORIES_TOML
    with open(path, "rb") as f:
        return tomllib.load(f).get("rule", [])

def _hit(pattern, value) -> bool:
    return bool(value) and re.search(pattern, value, re.IGNORECASE) is not None

def categorize(app: str, title: str, domain: str | None = None, rules: list[dict] | None = None) -> str:
    if rules is None:
        rules = load_rules()
    for r in rules:
        if (("match_app" in r and _hit(r["match_app"], app)) or
            ("match_title" in r and _hit(r["match_title"], title)) or
            ("match_domain" in r and _hit(r["match_domain"], domain))):
            return r["category"]
    return UNCATEGORIZED
```

- [ ] **Step 5: Run — must pass**

Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_categorize.py -q`
Expected: PASS (4 passed).

- [ ] **Step 6: Commit**

```bash
chezmoi add ~/.config/timetrack/categories.toml ~/.local/share/timetrack/lib/timetrack/categorize.py ~/.local/share/timetrack/lib/tests/test_categorize.py
git -C ~/src/caelestia-shell add -A && git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage3 — rule-based categorization + starter categories.toml"
```

---

### Task 4: DB schema + idempotent upserts (`db.py`)

sqlite-utils tables with the spec's stable keys; upserting the same record twice must not duplicate.

**Files:**
- Create: `~/.local/share/timetrack/lib/timetrack/db.py`
- Create: `~/.local/share/timetrack/lib/tests/test_db.py`

**Interfaces:**
- Produces: `open_db(path=config.DB_PATH) -> sqlite_utils.Database`; and `upsert(db, table, records)` wrappers with the pks below. Consumed by Task 5.
- Table pks: `tasks`→`uuid`; `intervals`→`start`; `sessions`→`ts`; `usage`→`("date","category","app","hour")`; `web`→`("date","domain","hour")`; `breaks`→`start`; `salah`→`("date","prayer")`; `daily_summary`→`date`; `adherence`→`date`; `reconciliation`→`date`.

- [ ] **Step 1: Failing test — upsert idempotency**

Create `~/.local/share/timetrack/lib/tests/test_db.py`:
```python
from timetrack import db

def test_upsert_is_idempotent(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    rec = {"uuid": "x1", "description": "hello", "project": "p"}
    db.upsert(d, "tasks", [rec])
    db.upsert(d, "tasks", [rec])          # again — must not duplicate
    assert d["tasks"].count == 1

def test_compound_key_usage(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    row = {"date": "2026-07-18", "category": "Infra", "app": "kitty", "hour": 14, "seconds": 600}
    db.upsert(d, "usage", [row])
    row2 = {**row, "seconds": 900}         # same key, new value → update in place
    db.upsert(d, "usage", [row2])
    assert d["usage"].count == 1
    assert list(d["usage"].rows)[0]["seconds"] == 900
```

- [ ] **Step 2: Run — must fail**

Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_db.py -q`
Expected: FAIL — no module `timetrack.db`.

- [ ] **Step 3: Implement**

Create `~/.local/share/timetrack/lib/timetrack/db.py`:
```python
"""SQLite schema + idempotent upserts (sqlite-utils)."""
import sqlite_utils
from . import config

PKS = {
    "tasks": "uuid",
    "intervals": "start",
    "sessions": "ts",
    "usage": ("date", "category", "app", "hour"),
    "web": ("date", "domain", "hour"),
    "breaks": "start",
    "salah": ("date", "prayer"),
    "daily_summary": "date",
    "adherence": "date",
    "reconciliation": "date",
}

def open_db(path=None) -> sqlite_utils.Database:
    return sqlite_utils.Database(path or config.DB_PATH)

def upsert(db: sqlite_utils.Database, table: str, records: list[dict]) -> None:
    if not records:
        return
    # store list/dict fields (e.g. tags) as JSON automatically
    db[table].upsert_all(records, pk=PKS[table], alter=True)
```

- [ ] **Step 4: Run — must pass**

Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_db.py -q`
Expected: PASS (2 passed).

- [ ] **Step 5: Commit**

```bash
chezmoi add ~/.local/share/timetrack/lib/timetrack/db.py ~/.local/share/timetrack/lib/tests/test_db.py
git -C ~/src/caelestia-shell add -A && git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage3 — sqlite schema + idempotent upserts"
```

---

### Task 5: Interval math + raw upserts + AW aggregation (`intervals.py`, rollup part A)

A reusable interval-overlap helper (needed by aggregation AND reconciliation), plus the "raw" rollup: upsert tasks/intervals/sessions and aggregate AW window/afk into `usage` + `breaks` for one logical day.

**Files:**
- Create: `~/.local/share/timetrack/lib/timetrack/intervals.py`
- Create: `~/.local/share/timetrack/lib/timetrack/rollup.py`
- Create: `~/.local/share/timetrack/lib/tests/test_intervals.py`
- Create: `~/.local/share/timetrack/lib/tests/test_rollup_raw.py`

**Interfaces:**
- Produces (`intervals.py`): `merge(spans) -> list[tuple]` (union of `(start,end)` datetime spans); `overlap(a_spans, b_spans) -> float` seconds of intersection; `subtract(a_spans, b_spans) -> list[tuple]` (a minus b). Times are aware `datetime`.
- Produces (`rollup.py`, this task): `rollup_raw(db, day, tasks, intervals_, window_events, afk_events, logind, rules) -> None` — upserts `tasks`, `intervals`, `sessions`, and aggregated `usage` (per date+category+app+hour) + auto `breaks` (afk spans ≥ `BREAK_MIN_SECONDS=180`). `BREAK_MIN_SECONDS = 180`.

- [ ] **Step 1: Failing tests for interval math**

Create `~/.local/share/timetrack/lib/tests/test_intervals.py`:
```python
from datetime import datetime as dt
from timetrack import intervals as I

def S(h1,m1,h2,m2): return (dt(2026,7,18,h1,m1), dt(2026,7,18,h2,m2))

def test_merge_overlapping():
    assert I.merge([S(9,0,10,0), S(9,30,11,0)]) == [ (dt(2026,7,18,9,0), dt(2026,7,18,11,0)) ]

def test_overlap_seconds():
    assert I.overlap([S(9,0,10,0)], [S(9,30,10,30)]) == 30*60

def test_subtract():
    assert I.subtract([S(9,0,11,0)], [S(9,30,10,0)]) == [ S(9,0,9,30), S(10,0,11,0) ]
```

- [ ] **Step 2: Run — fail; then implement `intervals.py`**

Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_intervals.py -q` → FAIL.

Create `~/.local/share/timetrack/lib/timetrack/intervals.py`:
```python
"""Half-open [start,end) datetime-span set algebra used by aggregation + reconciliation."""

def merge(spans):
    spans = sorted((s for s in spans if s[0] < s[1]))
    out = []
    for s, e in spans:
        if out and s <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], e))
        else:
            out.append((s, e))
    return out

def overlap(a, b):
    a, b = merge(a), merge(b)
    total, j = 0.0, 0
    for s, e in a:
        for bs, be in b:
            lo, hi = max(s, bs), min(e, be)
            if lo < hi:
                total += (hi - lo).total_seconds()
    return total

def subtract(a, b):
    b = merge(b)
    out = []
    for s, e in merge(a):
        cur = s
        for bs, be in b:
            if be <= cur or bs >= e:
                continue
            if bs > cur:
                out.append((cur, bs))
            cur = max(cur, be)
            if cur >= e:
                break
        if cur < e:
            out.append((cur, e))
    return out
```
Run the test again → PASS (3 passed).

- [ ] **Step 3: Failing test for `rollup_raw` aggregation**

Create `~/.local/share/timetrack/lib/tests/test_rollup_raw.py`:
```python
from datetime import date
from timetrack import db, rollup

RULES = [{"category":"Infra","match_title":"cluster"},{"category":"Web","match_app":"brave"}]

def _win(ts, dur, app, title):
    return {"id":ts, "timestamp": ts, "duration": dur, "data": {"app": app, "title": title}}

def test_rollup_raw_aggregates_usage_and_breaks(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026,7,18)
    # two window events same hour+category → summed; one afk span of 10min → a break
    window = [
        _win("2026-07-18T14:05:00+00:00", 300, "kitty", "cluster deploy"),
        _win("2026-07-18T14:20:00+00:00", 120, "kitty", "cluster deploy"),
    ]
    afk = [{"id":1,"timestamp":"2026-07-18T15:00:00+00:00","duration":600,"data":{"status":"afk"}}]
    rollup.rollup_raw(d, day, tasks=[], intervals_=[], window_events=window,
                      afk_events=afk, logind=[], rules=RULES)
    rows = {(r["category"], r["hour"]): r["seconds"] for r in d["usage"].rows}
    assert rows[("Infra", 14)] == 420
    assert d["breaks"].count == 1
    assert list(d["breaks"].rows)[0]["source"] == "auto"
    assert d["_afk_raw"].count == 1        # afk span persisted for part-B reconciliation
```

- [ ] **Step 4: Run — fail; then implement `rollup_raw` in `rollup.py`**

Create `~/.local/share/timetrack/lib/timetrack/rollup.py`:
```python
"""Rollup: read sources into the DB for one 4am-logical day (part A: raw + aggregation)."""
from collections import defaultdict
from datetime import datetime, date, timedelta
from . import db as dbmod, categorize
from .config import logical_date

BREAK_MIN_SECONDS = 180

def _parse(ts: str) -> datetime:
    """Parse ISO8601, tolerating AW's nanosecond precision (datetime handles ≤ microseconds)."""
    import re
    ts = re.sub(r"(\.\d{6})\d+", r"\1", ts.replace("Z", "+00:00"))
    return datetime.fromisoformat(ts)

def rollup_raw(db, day: date, tasks, intervals_, window_events, afk_events, logind, rules) -> None:
    dbmod.upsert(db, "tasks", tasks)
    dbmod.upsert(db, "intervals", [
        {"start": i["start"], "end": i.get("end"),
         "tags": i.get("tags", []),
         "project": (i.get("tags") or [None])[0],
         "description": (i.get("tags") or [None, None])[1] if len(i.get("tags") or []) > 1 else None}
        for i in intervals_
    ])
    dbmod.upsert(db, "sessions", [
        {"ts": e["ts"], "type": e.get("type"), "detail": e.get("detail")} for e in logind
    ])
    # aggregate window events → usage (date,category,app,hour → seconds)
    agg = defaultdict(float)
    for ev in window_events:
        d = ev.get("data", {})
        cat = categorize.categorize(d.get("app", ""), d.get("title", ""), rules=rules)
        hour = _parse(ev["timestamp"]).astimezone().hour
        agg[(str(day), cat, d.get("app", ""), hour)] += ev.get("duration", 0)
    dbmod.upsert(db, "usage", [
        {"date": k[0], "category": k[1], "app": k[2], "hour": k[3], "seconds": round(v)}
        for k, v in agg.items()
    ])
    # afk spans ≥ threshold → auto breaks
    breaks = []
    for ev in afk_events:
        if ev.get("data", {}).get("status") == "afk" and ev.get("duration", 0) >= BREAK_MIN_SECONDS:
            breaks.append({"start": ev["timestamp"], "duration": round(ev["duration"]),
                           "source": "auto", "label": None})
    dbmod.upsert(db, "breaks", breaks)
    # persist afk spans to a local scratch table (NOT synced — sync.dump skips '_' tables) so
    # part B's reconciliation can read them. Idempotent on start.
    afk_rows = [{"start": ev["timestamp"],
                 "end": (_parse(ev["timestamp"]) + timedelta(seconds=ev.get("duration", 0))).isoformat(),
                 "status": ev.get("data", {}).get("status")}
                for ev in afk_events if ev.get("timestamp")]
    if afk_rows:
        db["_afk_raw"].upsert_all(afk_rows, pk="start")
```
Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_rollup_raw.py -q` → PASS.

- [ ] **Step 5: Commit**

```bash
chezmoi add ~/.local/share/timetrack/lib/timetrack/intervals.py ~/.local/share/timetrack/lib/timetrack/rollup.py ~/.local/share/timetrack/lib/tests/test_intervals.py ~/.local/share/timetrack/lib/tests/test_rollup_raw.py
git -C ~/src/caelestia-shell add -A && git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage3 — interval algebra + raw upserts + AW usage/break aggregation"
```

---

### Task 6: Salah, reconciliation, daily summary, adherence + streak (rollup part B)

Derive `salah` from tasks, compute the three reconciliation flags, and the per-day `daily_summary`/`adherence`, plus the engagement-based streak.

**Files:**
- Modify: `~/.local/share/timetrack/lib/timetrack/rollup.py` (add `rollup_derived` + `streak`)
- Create: `~/.local/share/timetrack/lib/tests/test_rollup_derived.py`

**Interfaces:**
- Produces:
  - `rollup_derived(db, day, rules) -> None` — reads the raw tables already in `db`, writes `salah`, `reconciliation`, `daily_summary`, `adherence` for `day`.
  - `PRAYERS = ["Fajr","Dhuhr","Asr","Maghrib","Isha"]`.
  - `streak(db, day) -> int` — consecutive counting days ending at `day` (a day counts iff `adherence` row has `clock_in_logged AND salah_logged==5 AND tasks_tracked>=1`).
- Reconciliation flags (minutes): `active_untracked_min` = not-afk minus timew intervals; `task_afk_min` = timew intervals ∩ afk; `present_idle_min` = session-present ∩ afk.

- [ ] **Step 1: Failing test (synthetic day)**

Create `~/.local/share/timetrack/lib/tests/test_rollup_derived.py`:
```python
from datetime import date
from timetrack import db, rollup

def test_salah_and_adherence_counts(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026,7,18)
    # 5 salah tasks for the day, all logged (incl. a 'missed') → salah_logged==5
    prayers = [("Fajr","jamaah"),("Dhuhr","alone"),("Asr","jamaah"),("Maghrib","qaza"),("Isha","missed")]
    d["tasks"].upsert_all([
        {"uuid":f"s{n}","description":p,"project":"salah","status":"completed",
         "salah_status":st,"due":"2026-07-18T12:00:00","tags":["salah"]}
        for n,(p,st) in enumerate(prayers)], pk="uuid")
    # one real tracked task interval → tasks_tracked>=1
    d["intervals"].upsert_all([{"start":"20260718T083000Z","end":"20260718T093000Z",
        "tags":["work","x"],"project":"work","description":"x"}], pk="start")
    # a login session (clock-in)
    d["sessions"].upsert_all([{"ts":"2026-07-18T07:12:00+05:30","type":"login","detail":None}], pk="ts")
    rollup.rollup_derived(d, day, rules=[])
    adh = list(d["adherence"].rows)[0]
    assert adh["salah_logged"] == 5
    assert adh["clock_in_logged"] == 1
    assert adh["tasks_tracked"] >= 1
    assert rollup.streak(d, day) == 1        # this day counts

def test_reconciliation_active_untracked(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026,7,18)
    # not-afk 09:00–10:00 (local) with NO timew interval → 60 min active-untracked
    d["_afk_raw"].insert_all(
        [{"start":"2026-07-18T09:00:00+05:30","end":"2026-07-18T10:00:00+05:30","status":"not-afk"}],
        pk="start")
    rollup.rollup_derived(d, day, rules=[])
    rec = list(d["reconciliation"].rows)[0]
    assert rec["active_untracked_min"] == 60
    assert rec["task_afk_min"] == 0
```

- [ ] **Step 2: Run — must fail**

Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_rollup_derived.py::test_salah_and_adherence_counts -q`
Expected: FAIL — `rollup.rollup_derived` does not exist.

- [ ] **Step 3: Implement `rollup_derived` + `streak`**

Append to `~/.local/share/timetrack/lib/timetrack/rollup.py`:
```python
from . import intervals as I

PRAYERS = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

def _rows(db, table):
    """Read a table's rows, or [] if it doesn't exist yet (partial days / tests)."""
    return db[table].rows if table in db.table_names() else []

def _afk_spans(db, want_status):
    return [(_parse(r["start"]), _parse(r["end"])) for r in _rows(db, "_afk_raw") if r["status"] == want_status]

def _iso(compact: str) -> str:  # 20260718T083000Z -> 2026-07-18T08:30:00+00:00
    return datetime.strptime(compact, "%Y%m%dT%H%M%SZ").strftime("%Y-%m-%dT%H:%M:%S+00:00")

def _logday(ts: str) -> str:  # ISO ts -> its 4am-logical date string
    return str(logical_date(_parse(ts).astimezone().replace(tzinfo=None)))

def _iv_logday(compact_start: str):  # timew UTC compact start -> its 4am-local logical date
    return logical_date(_parse(_iso(compact_start)).astimezone().replace(tzinfo=None))

def rollup_derived(db, day, rules) -> None:
    ds = str(day)
    # salah from tasks (project 'salah', due on `day`)
    salah = [{"date": ds, "prayer": t["description"], "status": t.get("salah_status"),
              "due": t.get("due"), "logged_at": t.get("modified")}
             for t in _rows(db, "tasks")
             if t.get("project") == "salah" and (t.get("due") or "").startswith(ds)]
    dbmod.upsert(db, "salah", salah)
    salah_logged = sum(1 for s in salah if s["status"])

    # intervals belonging to THIS logical day (convert UTC start -> local -> 4am boundary)
    day_ivs = [iv for iv in _rows(db, "intervals") if iv.get("start") and _iv_logday(iv["start"]) == day]
    ivspans = [(_parse(_iso(iv["start"])), _parse(_iso(iv["end"]))) for iv in day_ivs if iv.get("end")]

    cat_seconds = {}
    for u in _rows(db, "usage"):
        if u["date"] == ds:
            cat_seconds[u["category"]] = cat_seconds.get(u["category"], 0) + u["seconds"]
    clock_in = 1 if any(s.get("type") == "login" and _logday(s["ts"]) == ds for s in _rows(db, "sessions")) else 0
    day_breaks = [b for b in _rows(db, "breaks") if _logday(b["start"]) == ds]
    labeled = sum(1 for b in day_breaks if b.get("label"))

    dbmod.upsert(db, "daily_summary", [{
        "date": ds, "categories": cat_seconds, "tracked_seconds": sum(cat_seconds.values()),
        "breaks": len(day_breaks), "salah_logged": salah_logged}])
    dbmod.upsert(db, "adherence", [{
        "date": ds, "clock_in_logged": clock_in, "salah_logged": salah_logged,
        "breaks_labeled": labeled, "breaks_total": len(day_breaks), "tasks_tracked": len(day_ivs)}])

    notafk, afk = _afk_spans(db, "not-afk"), _afk_spans(db, "afk")
    present = [(min(s for s, _ in notafk), max(e for _, e in notafk))] if notafk else []
    dbmod.upsert(db, "reconciliation", [{
        "date": ds,
        "active_untracked_min": round(sum((e - s).total_seconds() for s, e in I.subtract(notafk, ivspans)) / 60),
        "task_afk_min": round(I.overlap(ivspans, afk) / 60),
        "present_idle_min": round(I.overlap(present, afk) / 60)}])

def streak(db, day) -> int:
    rows = {r["date"]: r for r in _rows(db, "adherence")}
    n, cur = 0, day
    while True:
        r = rows.get(str(cur))
        if r and r["clock_in_logged"] and r["salah_logged"] == 5 and r["tasks_tracked"] >= 1:
            n += 1; cur = cur - timedelta(days=1)
        else:
            return n
```

- [ ] **Step 4: Run all derived tests — must pass**

Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_rollup_derived.py -q`
Expected: PASS (both `test_salah_and_adherence_counts` and `test_reconciliation_active_untracked`).

- [ ] **Step 5: Commit**

```bash
chezmoi add ~/.local/share/timetrack/lib/timetrack/rollup.py ~/.local/share/timetrack/lib/tests/test_rollup_derived.py
git -C ~/src/caelestia-shell add -A && git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage3 — salah + reconciliation + daily_summary/adherence + streak"
```

---

### Task 7: Obsidian daily-note renderer (`note.py`)

Render the §7a note (frontmatter + the human layout + streak graph) from `daily_summary`/`adherence`/`salah`/`reconciliation`, and write it to the personal vault.

**Files:**
- Create: `~/.local/share/timetrack/lib/timetrack/note.py`
- Create: `~/.local/share/timetrack/lib/tests/test_note.py`

**Interfaces:**
- Produces: `render(db, day) -> str` (markdown); `write(db, day) -> pathlib.Path` (writes `config.VAULT_DAILY / f"{day}.md"`, creating dirs). Uses `streak(db, day)`.

- [ ] **Step 1: Failing test**

Create `~/.local/share/timetrack/lib/tests/test_note.py`:
```python
from datetime import date
from timetrack import db, note

def test_render_has_frontmatter_streak_and_salah(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026,7,18)
    d["daily_summary"].upsert_all([{"date":str(day),"categories":{"Infra":12000,"Code":10200},
        "tracked_seconds":22200,"breaks":5,"salah_logged":5}], pk="date")
    d["adherence"].upsert_all([{"date":str(day),"clock_in_logged":1,"salah_logged":5,
        "breaks_labeled":1,"breaks_total":5,"tasks_tracked":3}], pk="date")
    d["salah"].upsert_all([{"date":str(day),"prayer":"Fajr","status":"jamaah"}], pk=("date","prayer"))
    d["reconciliation"].upsert_all([{"date":str(day),"active_untracked_min":35,
        "task_afk_min":0,"present_idle_min":0}], pk="date")
    md = note.render(d, day)
    assert md.startswith("---\n")           # frontmatter for Dataview
    assert "streak" in md.lower()
    assert "Infra" in md and "Salah" in md
    assert "35m" in md                        # optional-review line
```

- [ ] **Step 2: Run — fail; then implement `note.py`**

Create `~/.local/share/timetrack/lib/timetrack/note.py`:
```python
"""Render + write the Obsidian daily note (never-guilt, scannable)."""
from datetime import date
from . import config
from .rollup import streak, PRAYERS

def _hm(seconds) -> str:
    m = round(seconds / 60); return f"{m//60}h{m%60:02d}" if m >= 60 else f"{m}m"

def _bars(seconds, top) -> str:
    return "▓" * max(1, round(8 * seconds / top)) if top else ""

def render(db, day: date) -> str:
    ds = str(day)
    summ = next((r for r in db["daily_summary"].rows if r["date"] == ds), {})
    adh = next((r for r in db["adherence"].rows if r["date"] == ds), {})
    rec = next((r for r in db["reconciliation"].rows if r["date"] == ds), {})
    salah = {r["prayer"]: r.get("status") for r in db["salah"].rows if r["date"] == ds}
    cats = summ.get("categories", {}) or {}
    top = max(cats.values()) if cats else 0
    n = streak(db, day)
    where = "  ".join(f"{c} {_hm(s)} {_bars(s, top)}" for c, s in sorted(cats.items(), key=lambda kv:-kv[1]))
    tick = "".join("✅" if salah.get(p) and salah[p] != "missed" else ("◻" if salah.get(p) == "missed" else "▫") for p in PRAYERS)
    lines = [
        "---", f"date: {ds}", f"tracked_seconds: {summ.get('tracked_seconds',0)}",
        f"salah_logged: {adh.get('salah_logged',0)}", f"streak: {n}",
        f"counts: {bool(adh.get('clock_in_logged') and adh.get('salah_logged')==5 and adh.get('tasks_tracked',0)>=1)}",
        "---", "",
        f"## ⏱ {ds}   ·   🔥 {n}-day streak", "",
        f"Tracked  {_hm(summ.get('tracked_seconds',0))}",
        f"Where    {where}",
        f"Breaks   {summ.get('breaks',0)}   ({adh.get('breaks_labeled',0)} labeled)",
        f"Salah    {tick}  logged {adh.get('salah_logged',0)}/5",
    ]
    au = rec.get("active_untracked_min", 0)
    if au:
        lines += ["", f"Review (optional)  ~{au}m active with no task running"]
    return "\n".join(lines) + "\n"

def write(db, day: date):
    config.VAULT_DAILY.mkdir(parents=True, exist_ok=True)
    p = config.VAULT_DAILY / f"{day}.md"
    p.write_text(render(db, day))
    return p
```
Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_note.py -q` → PASS.

- [ ] **Step 3: [user-assisted] Eyeball the rendered note**

Print a sample to confirm it reads well (no live vault write yet): the reviewer/user runs the test's `render()` output through `less` or views it. Note in the report that the real vault render is confirmed in Task 10 acceptance.

- [ ] **Step 4: Commit**

```bash
chezmoi add ~/.local/share/timetrack/lib/timetrack/note.py ~/.local/share/timetrack/lib/tests/test_note.py
git -C ~/src/caelestia-shell add -A && git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage3 — Obsidian daily-note renderer + streak graph"
```

---

### Task 8: sqlite-diffable git sync (`sync.py`)

Stable-sorted `sqlite-diffable` text dump + pull-before-write single-writer commit/push. The dump must be byte-identical across runs on unchanged data (so hourly diffs stay minimal).

**Files:**
- Create: `~/.local/share/timetrack/lib/timetrack/sync.py`
- Create: `~/.local/share/timetrack/lib/tests/test_sync.py`

**Interfaces:**
- Produces: `dump(db_path, out_dir) -> None` (writes stable `out_dir/<table>.ndjson` + `<table>.metadata.json`, sorted by pk); `push(repo=config.DATA_REPO, db_path=config.DB_PATH) -> bool` (pull→dump→commit→push; returns False, non-fatal, if `repo` isn't a git repo yet).

- [ ] **Step 1: Failing test — dump stability**

Create `~/.local/share/timetrack/lib/tests/test_sync.py`:
```python
import json
from timetrack import db, sync

def test_dump_is_stable_and_pk_sorted(tmp_path):
    p = tmp_path / "t.db"
    d = db.open_db(p)
    # same (date,category,app), differing hour → pk sort orders by hour
    d["usage"].upsert_all([
        {"date":"2026-07-18","category":"Code","app":"kitty","hour":10,"seconds":600},
        {"date":"2026-07-18","category":"Code","app":"kitty","hour":9,"seconds":300},
    ], pk=("date","category","app","hour"))
    o1, o2 = tmp_path/"a", tmp_path/"b"
    sync.dump(p, o1); sync.dump(p, o2)
    a = (o1/"usage.ndjson").read_text(); b = (o2/"usage.ndjson").read_text()
    assert a == b                                   # deterministic across runs
    lines = a.strip().splitlines()
    # dump writes JSON arrays [date,category,app,hour,seconds]; index 3 == hour
    assert json.loads(lines[0])[3] == 9             # sorted by pk → hour 9 first
    assert json.loads(lines[1])[3] == 10

def test_push_noops_without_repo(tmp_path):
    assert sync.push(repo=tmp_path/"nope", db_path=tmp_path/"t.db") is False
```

- [ ] **Step 2: Run — fail; then implement `sync.py`**

Create `~/.local/share/timetrack/lib/timetrack/sync.py`:
```python
"""Stable sqlite-diffable dump + single-writer git backup of the observe DB."""
import json, subprocess
from pathlib import Path
import sqlite_utils
from . import config, db as dbmod

def dump(db_path, out_dir) -> None:
    out = Path(out_dir); out.mkdir(parents=True, exist_ok=True)
    d = sqlite_utils.Database(db_path)
    for table in sorted(d.table_names()):
        if table.startswith("_"):
            continue
        pk = dbmod.PKS.get(table)
        cols = [c.name for c in d[table].columns]
        key = (lambda r: tuple(r.get(k) for k in ([pk] if isinstance(pk, str) else pk))) if pk else (lambda r: r)
        rows = sorted(d[table].rows, key=key)
        (out / f"{table}.metadata.json").write_text(json.dumps({"name": table, "columns": cols}, indent=2, sort_keys=True) + "\n")
        with (out / f"{table}.ndjson").open("w") as f:
            for r in rows:
                f.write(json.dumps([r[c] for c in cols], sort_keys=True) + "\n")

def _git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)

def push(repo=None, db_path=None) -> bool:
    repo = Path(repo or config.DATA_REPO); db_path = db_path or config.DB_PATH
    if not (repo / ".git").is_dir():
        return False                       # repo not set up yet — non-fatal
    _git(repo, "pull", "--quiet", "--no-rebase")      # single-writer: pull before write
    dump(db_path, repo / "tables")
    _git(repo, "add", "-A")
    if not _git(repo, "diff", "--cached", "--quiet").returncode:
        return True                        # nothing changed
    _git(repo, "commit", "--quiet", "-m", "rollup: refresh observe data")
    return _git(repo, "push", "--quiet").returncode == 0
```
Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_sync.py -q` → PASS.

- [ ] **Step 3: Commit**

```bash
chezmoi add ~/.local/share/timetrack/lib/timetrack/sync.py ~/.local/share/timetrack/lib/tests/test_sync.py
git -C ~/src/caelestia-shell add -A && git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage3 — stable sqlite-diffable dump + single-writer git sync"
```

---

### Task 9: CLI (`__main__.py`) + wrapper + systemd timers

Wire the modules into `timetrack rollup|note|sync|all`, a wrapper on PATH, and the two `Persistent` timers (rollup 30 min, sync hourly).

**Files:**
- Create: `~/.local/share/timetrack/lib/timetrack/__main__.py`
- Create: `~/.local/bin/timetrack`
- Create: `~/.config/systemd/user/timetrack-rollup.service` + `.timer`
- Create: `~/.config/systemd/user/timetrack-sync.service` + `.timer`
- Create: `~/.local/share/timetrack/lib/tests/test_cli.py`

**Interfaces:**
- Produces: `main(argv) -> int` dispatching `rollup` (read all sources for today's logical day → `rollup_raw`+`rollup_derived`), `note` (`note.write`), `sync` (`sync.push`), `all` (rollup→note→sync). The rollup queries AW with `start/end` = the logical day's 04:00→next 04:00.

- [ ] **Step 1: Failing test — `all` runs end-to-end against a fake DB dir**

Create `~/.local/share/timetrack/lib/tests/test_cli.py`:
```python
from timetrack import __main__ as cli

def test_all_dispatch_smoke(tmp_path, monkeypatch):
    # point config at temp paths; stub the source readers so no live services are hit
    from timetrack import config, sources
    monkeypatch.setattr(config, "DB_PATH", tmp_path/"t.db")
    monkeypatch.setattr(config, "VAULT_DAILY", tmp_path/"vault")
    monkeypatch.setattr(config, "DATA_REPO", tmp_path/"norepo")
    monkeypatch.setattr(sources, "read_tasks", lambda: [])
    monkeypatch.setattr(sources, "read_intervals", lambda: [])
    monkeypatch.setattr(sources, "read_aw_events", lambda *a, **k: [])
    monkeypatch.setattr(sources, "read_logind", lambda: [])
    assert cli.main(["all"]) == 0
    assert (tmp_path/"vault").exists()      # note written
```

- [ ] **Step 2: Run — fail; then implement `__main__.py`**

Create `~/.local/share/timetrack/lib/timetrack/__main__.py`:
```python
"""timetrack CLI: rollup | note | sync | all."""
import sys
from datetime import datetime, timedelta, time
from . import config, sources, categorize, db as dbmod, rollup, note, sync

def _today_window():
    now = datetime.now()
    day = config.logical_date(now)
    start = datetime.combine(day, time(config.DAY_BOUNDARY_HOUR))
    return day, start, start + timedelta(days=1)

def _do_rollup():
    day, start, end = _today_window()
    d = dbmod.open_db()
    rules = categorize.load_rules()
    si, ei = start.astimezone().isoformat(), end.astimezone().isoformat()
    rollup.rollup_raw(d, day,
        tasks=sources.read_tasks(), intervals_=sources.read_intervals(),
        window_events=sources.read_aw_events(sources.WINDOW_BUCKET, si, ei),
        afk_events=sources.read_aw_events(sources.AFK_BUCKET, si, ei),
        logind=sources.read_logind(), rules=rules)
    rollup.rollup_derived(d, day, rules)
    return d, day

def main(argv=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    cmd = argv[0] if argv else "all"
    if cmd in ("rollup", "all"):
        d, day = _do_rollup()
    if cmd in ("note", "all"):
        d = dbmod.open_db(); day = config.logical_date(datetime.now())
        note.write(d, day)
    if cmd in ("sync", "all"):
        sync.push()
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
```
Run: `cd ~/.local/share/timetrack/lib && ../venv/bin/python -m pytest tests/test_cli.py -q` → PASS.

- [ ] **Step 3: Wrapper + units**

Create `~/.local/bin/timetrack`:
```bash
#!/usr/bin/env bash
# timetrack — run the Stage-3 observe rollup/note/sync from its venv.
exec env PYTHONPATH="$HOME/.local/share/timetrack/lib" \
    "$HOME/.local/share/timetrack/venv/bin/python" -m timetrack "$@"
```
Create `~/.config/systemd/user/timetrack-rollup.service`:
```ini
[Unit]
Description=timetrack rollup (refresh local observe DB + Obsidian note)
[Service]
Type=oneshot
ExecStart=%h/.local/bin/timetrack rollup
ExecStartPost=%h/.local/bin/timetrack note
```
Create `~/.config/systemd/user/timetrack-rollup.timer`:
```ini
[Unit]
Description=timetrack rollup every 30 min (<=30min local freshness)
[Timer]
OnCalendar=*:0/30
OnStartupSec=60
Persistent=true
[Install]
WantedBy=timers.target
```
Create `~/.config/systemd/user/timetrack-sync.service`:
```ini
[Unit]
Description=timetrack git backup (sqlite-diffable dump -> private repo)
[Service]
Type=oneshot
ExecStart=%h/.local/bin/timetrack sync
```
Create `~/.config/systemd/user/timetrack-sync.timer`:
```ini
[Unit]
Description=timetrack hourly backup (<=1h backup freshness)
[Timer]
OnCalendar=*:05
OnStartupSec=120
Persistent=true
[Install]
WantedBy=timers.target
```

- [ ] **Step 4: [user-assisted] Enable timers + one live rollup**

Run:
```bash
chmod +x ~/.local/bin/timetrack
systemctl --user daemon-reload
systemctl --user enable --now timetrack-rollup.timer timetrack-sync.timer
~/.local/bin/timetrack rollup && ~/.local/bin/timetrack note
sqlite3 ~/.local/share/timetrack/timetrack.db '.tables'
ls ~/powerhouse/timetrack/daily/
systemctl --user list-timers 'timetrack-*' --no-pager
```
Expected: tables created, today's note written to the personal vault, both timers armed. (`sync` is expected to no-op until Task 10 creates the repo.)

- [ ] **Step 5: Commit**

```bash
chezmoi add ~/.local/share/timetrack/lib/timetrack/__main__.py ~/.local/bin/timetrack ~/.config/systemd/user/timetrack-rollup.service ~/.config/systemd/user/timetrack-rollup.timer ~/.config/systemd/user/timetrack-sync.service ~/.config/systemd/user/timetrack-sync.timer ~/.local/share/timetrack/lib/tests/test_cli.py
git -C ~/src/caelestia-shell add -A && git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage3 — CLI + wrapper + rollup(30m)/sync(1h) timers"
```

---

### Task 10: aw-watcher-web + private repo + Datasette otter module + runbook & acceptance

Wire the remaining live pieces (all user-assisted), add per-domain web capture, the on-demand Datasette launcher, and document + accept.

**Files:**
- Modify: `~/.local/share/timetrack/lib/timetrack/rollup.py` (add `web` aggregation from the aw-watcher-web bucket)
- Modify: `~/.config/otter-launcher/config.toml` (a `tt` module → Datasette)
- Create: `~/.local/bin/timetrack-datasette`
- Create: `~/src/caelestia-shell/docs/superpowers/notes/2026-07-18-timetrack-stage3-runbook.md`

**Interfaces:**
- Consumes: everything from Tasks 1–9.

- [ ] **Step 1: `web` aggregation (TDD) — from the aw-watcher-web bucket**

Add `rollup_web(db, day, web_events, rules)` to `rollup.py` aggregating per `(date, domain, hour) → seconds` (domain from `data.url`'s host, category via `categorize(..., domain=host)`), upserting `web`. Add `test_rollup_web` with two events on `github.com` same hour → summed. Run the test → PASS. Wire `rollup_web` into `__main__._do_rollup` guarded on the web bucket existing (`sources.list_aw_buckets()`), so it's a no-op until the extension is installed.

- [ ] **Step 2: [user-assisted] Install aw-watcher-web**

Guide the user: install the ActivityWatch Web watcher extension in **Brave** (Chrome Web Store) or **Firefox** (AMO), which auto-creates a bucket like `aw-watcher-web-brave`. Verify:
```bash
curl -s http://127.0.0.1:5600/api/0/buckets/ | grep -i web
```
Record the exact bucket id and set `WEB_BUCKET` in `config.py` (default `None` → web rollup skipped). Commit the config change.

- [ ] **Step 3: [user-assisted] Create the private data repo + clone it**

The user creates a NEW PRIVATE repo on the personal account (suggested `shaiknoorullah/timetrack-data`), then:
```bash
git clone git@github-personal:shaiknoorullah/timetrack-data.git ~/.local/share/timetrack/data-repo
~/.local/bin/timetrack sync && git -C ~/.local/share/timetrack/data-repo log --oneline -1
```
Expected: `sync` now dumps `tables/*.ndjson` and pushes one commit. Confirm on GitHub the repo is **Private**.

- [ ] **Step 4: Datasette on-demand via otter**

Create `~/.local/bin/timetrack-datasette`:
```bash
#!/usr/bin/env bash
exec "$HOME/.local/share/timetrack/venv/bin/datasette" serve "$HOME/.local/share/timetrack/timetrack.db" --open
```
Add to `~/.config/otter-launcher/config.toml` a module:
```toml
[[modules]]
name = "timetrack"
prefix = "tt"
cmd = "kitty --class datasette --config ~/.config/kitty/otter.conf -e ~/.local/bin/timetrack-datasette"
description = "observe: datasette over timetrack.db"
```
`chmod +x ~/.local/bin/timetrack-datasette`. **[user-assisted]** confirm `tt` in otter opens Datasette at `localhost:8001`.

- [ ] **Step 5: Runbook**

Create `~/src/caelestia-shell/docs/superpowers/notes/2026-07-18-timetrack-stage3-runbook.md` documenting: the pipeline, the paths, the two timers + cadence, `timetrack rollup|note|sync|all`, the categories.toml refine-loop, the private-repo/single-writer rule, health checks (`systemctl --user list-timers 'timetrack-*'`, `sqlite3 …/timetrack.db '.tables'`, `git -C …/data-repo log`), and the vault/note location.

- [ ] **Step 6: [user-assisted] End-to-end acceptance**

Confirm with the user: (1) `timetrack all` runs clean; (2) today's Obsidian note renders in `~/powerhouse` with categories + salah ticks + streak; (3) `tt` opens Datasette and the tables have rows; (4) the private repo received a commit and is Private; (5) both timers armed; (6) Stage-1/2 untouched (`systemctl --user list-timers` still shows aw/awatcher/salah).

- [ ] **Step 7: Commit**

```bash
chezmoi add ~/.local/share/timetrack/lib/timetrack/rollup.py ~/.local/bin/timetrack-datasette ~/.config/otter-launcher/config.toml
git -C ~/src/caelestia-shell add -A
git -C ~/src/caelestia-shell commit -m "feat(timetrack): stage3 — aw-watcher-web + private data repo + datasette otter module + runbook"
```

---

## Done-When (Stage 3 acceptance)
- `timetrack all` reads taskwarrior 3.4.2 / timew / AW / logind and populates `~/.local/share/timetrack/timetrack.db` with all 10 tables via idempotent upserts (rerun ≠ duplicate).
- The Obsidian daily note renders in `~/powerhouse/timetrack/daily/` with per-category time, salah ticks, the optional review line, and the engagement-based streak; a Dataview-ready frontmatter block is present.
- Rollup timer (30 min) keeps the local DB ≤30 min fresh; sync timer (hourly) pushes a stable `sqlite-diffable` text dump to the PRIVATE `timetrack-data` repo (≤1 h backup), single-writer, lean history.
- `tt` in otter opens Datasette over the DB.
- Categorization is a versioned `categories.toml` (app+title+domain, first-match-wins, `Uncategorized` fallback).
- Stage-1 capture + Stage-2 daily-driver untouched; the rollup is read-only against all sources.
