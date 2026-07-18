from datetime import date
from timetrack import db, rollup

RULES = [{"category": "Dev", "match_domain": "github\\.com"}]

def _web(ts, dur, url):
    return {"id": ts, "timestamp": ts, "duration": dur, "data": {"url": url}}

def test_rollup_web_sums_same_domain_hour(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    # two web events on github.com in the same hour -> summed into one `web` row
    events = [
        _web("2026-07-18T14:05:00+00:00", 300, "https://github.com/foo/bar"),
        _web("2026-07-18T14:20:00+00:00", 120, "https://github.com/baz/qux"),
    ]
    rollup.rollup_web(d, day, events, rules=RULES)
    rows = {(r["domain"], r["hour"]): r["seconds"] for r in d["web"].rows}
    assert rows[("github.com", 14)] == 420
    assert d["web"].count == 1
    cats = {r["domain"]: r["category"] for r in d["web"].rows}
    assert cats["github.com"] == "Dev"

def test_rollup_web_buckets_different_domains_and_hours_separately(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    events = [
        _web("2026-07-18T14:05:00+00:00", 60, "https://github.com/foo"),
        _web("2026-07-18T15:05:00+00:00", 90, "https://github.com/foo"),
        _web("2026-07-18T14:10:00+00:00", 45, "https://example.com/page"),
    ]
    rollup.rollup_web(d, day, events, rules=RULES)
    rows = {(r["domain"], r["hour"]): r["seconds"] for r in d["web"].rows}
    assert rows[("github.com", 14)] == 60
    assert rows[("github.com", 15)] == 90
    assert rows[("example.com", 14)] == 45
    assert d["web"].count == 3

def test_rollup_web_guards_missing_or_none_url(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    events = [
        {"id": "no-url", "timestamp": "2026-07-18T14:05:00+00:00", "duration": 60, "data": {}},
        {"id": "none-url", "timestamp": "2026-07-18T14:10:00+00:00", "duration": 60, "data": {"url": None}},
    ]
    rollup.rollup_web(d, day, events, rules=RULES)
    assert "web" not in d.table_names() or d["web"].count == 0
