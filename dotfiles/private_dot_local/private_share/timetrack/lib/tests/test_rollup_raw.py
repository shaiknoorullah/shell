import os
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


def test_rollup_raw_buckets_by_local_hour_not_utc(tmp_path, monkeypatch, request):
    """Proves `_parse(...).astimezone().hour` actually converts UTC → local wall-clock
    hour. conftest pins TZ=UTC for the rest of the suite (where `.astimezone()` is a
    no-op), which can't distinguish "converts to local hour" from "uses raw UTC hour" —
    a regression deleting `.astimezone()` would still pass every other test here. This
    test overrides the process timezone to a non-zero offset (Asia/Kolkata, +05:30) for
    just this test, so a stripped `.astimezone()` fails it."""
    import time

    monkeypatch.setenv("TZ", "Asia/Kolkata")
    time.tzset()

    def _restore_utc():
        os.environ["TZ"] = "UTC"
        time.tzset()

    request.addfinalizer(_restore_utc)

    d = db.open_db(tmp_path / "t2.db")
    day = date(2026, 7, 18)
    # 2026-07-18T14:05:00+00:00 == 2026-07-18 19:35 IST (+05:30) — must land in hour 19.
    window = [_win("2026-07-18T14:05:00+00:00", 300, "kitty", "cluster deploy")]
    rollup.rollup_raw(d, day, tasks=[], intervals_=[], window_events=window,
                      afk_events=[], logind=[], rules=RULES)
    rows = {(r["category"], r["hour"]): r["seconds"] for r in d["usage"].rows}
    assert rows[("Infra", 19)] == 300


def test_usage_recategorization_replaces_not_duplicates(tmp_path):
    """categories.toml refine-loop: re-running rollup_raw for the same day+event under
    a DIFFERENT rule set (app moved e.g. Web -> Comms) must REPLACE the usage row, not
    leave the old-category row orphaned alongside the new one. `usage`'s pk is
    (date,category,app,hour) — category is part of the key — so a naive upsert can't
    remove the old row on its own; rollup_raw must delete the day's usage rows first."""
    d = db.open_db(tmp_path / "t3.db")
    day = date(2026, 7, 18)
    window = [_win("2026-07-18T14:05:00+00:00", 300, "kitty", "chat with team")]

    rules_web = [{"category": "Web", "match_app": "kitty"}]
    rollup.rollup_raw(d, day, tasks=[], intervals_=[], window_events=window,
                      afk_events=[], logind=[], rules=rules_web)
    rows = list(d["usage"].rows)
    assert len(rows) == 1
    assert rows[0]["category"] == "Web"

    rules_comms = [{"category": "Comms", "match_app": "kitty"}]
    rollup.rollup_raw(d, day, tasks=[], intervals_=[], window_events=window,
                      afk_events=[], logind=[], rules=rules_comms)
    rows = list(d["usage"].rows)
    assert len(rows) == 1                          # NOT 2 — old "Web" row must be gone
    assert rows[0]["category"] == "Comms"
