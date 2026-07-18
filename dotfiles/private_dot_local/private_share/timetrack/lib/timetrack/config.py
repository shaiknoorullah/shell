"""Canonical paths + the 4am logical-day boundary for the timetrack rollup."""
import os
from datetime import datetime, date, timedelta
from pathlib import Path

HOME = Path.home()

TASK = "/home/linuxbrew/.linuxbrew/bin/task"      # taskwarrior 3.4.2 (NOT /usr/bin, NOT go-task)
TIMEW = "/usr/bin/timew"                          # timewarrior 1.7.1 — NOT linuxbrew; timew isn't a brew formula on this box (verified 2026-07-18)
AW_BASE = "http://127.0.0.1:5600"
LOGIND_JSONL = HOME / ".local/share/timetrack/events/logind.jsonl"

DB_PATH = HOME / ".local/share/timetrack/timetrack.db"
DATA_REPO = HOME / ".local/share/timetrack/data-repo"      # private git clone; dump into DATA_REPO/tables/
VAULT_DAILY = HOME / "powerhouse/timetrack/daily"          # PERSONAL vault only
CATEGORIES_TOML = HOME / ".config/timetrack/categories.toml"

WEB_BUCKET = None          # aw-watcher-web bucket id (e.g. "aw-watcher-web-brave"); None = auto-detect/skip

HABIT_SPRINT_START = None  # date | None — set to start the "day X of 14" graduation countdown in the note header

DAY_BOUNDARY_HOUR = 4

def logical_date(dt: datetime) -> date:
    """The 'day' a timestamp belongs to, with the day starting at 04:00 local."""
    return (dt - timedelta(hours=DAY_BOUNDARY_HOUR)).date()
