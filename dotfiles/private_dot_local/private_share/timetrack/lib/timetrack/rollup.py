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
