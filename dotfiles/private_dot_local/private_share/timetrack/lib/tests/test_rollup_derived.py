import os
from datetime import date
from timetrack import db, rollup

def test_salah_and_adherence_counts(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026,7,18)
    # 5 salah tasks for the day, all logged (incl. a 'missed') → salah_logged==5
    # `due` values are taskwarrior's REAL compact-UTC export form (verified via
    # `task project:salah export`, e.g. "20260718T080000Z" for a same-day Dhuhr due) —
    # NOT the dashed ISO "2026-07-18T12:00:00" a naive .startswith(ds) check would need.
    # Each due falls in [2026-07-18T04:00Z, 2026-07-19T04:00Z) so _due_logday maps all
    # five to the 2026-07-18 logical day under the TZ=UTC test pin.
    prayers = [
        ("Fajr", "jamaah", "20260718T053100Z"),
        ("Dhuhr", "alone", "20260718T080000Z"),
        ("Asr", "jamaah", "20260718T114500Z"),
        ("Maghrib", "qaza", "20260718T132900Z"),
        ("Isha", "missed", "20260718T145900Z"),
    ]
    d["tasks"].upsert_all([
        {"uuid":f"s{n}","description":p,"project":"salah","status":"completed",
         "salah_status":st,"due":due,"tags":["salah"]}
        for n,(p,st,due) in enumerate(prayers)], pk="uuid")
    # one real tracked task interval → tasks_tracked>=1
    d["intervals"].upsert_all([{"start":"20260718T083000Z","end":"20260718T093000Z",
        "tags":["work","x"],"project":"work","description":"x"}], pk="start")
    # a login session (clock-in). NOTE: conftest pins TZ=UTC process-wide; timestamp is
    # given in UTC (07:12Z, after the 04:00 boundary) so it maps to the 2026-07-18
    # logical day under .astimezone(). The brief's original +05:30 offset would convert
    # to 01:42Z, which the 4am boundary maps to the PREVIOUS logical day (2026-07-17)
    # under the TZ=UTC test pin, failing clock_in_logged==1 below.
    d["sessions"].upsert_all([{"ts":"2026-07-18T07:12:00+00:00","type":"login","detail":None}], pk="ts")
    rollup.rollup_derived(d, day, rules=[])
    adh = list(d["adherence"].rows)[0]
    assert adh["salah_logged"] == 5
    assert adh["clock_in_logged"] == 1
    assert adh["tasks_tracked"] >= 1
    assert rollup.streak(d, day) == 1        # this day counts

def test_reconciliation_active_untracked(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026,7,18)
    # not-afk 09:00-10:00 UTC with NO timew interval → 60 min active-untracked. Uses a
    # +00:00 offset (not +05:30 like an earlier draft): under the conftest TZ=UTC pin,
    # "local" IS UTC, and _logday's .astimezone() actually converts a +05:30-offset
    # input, shifting it across the 4am boundary into the WRONG logical day (2026-07-17)
    # — this would silently fail the day-scoped _afk_spans filter added for Critical-2.
    d["_afk_raw"].insert_all(
        [{"start":"2026-07-18T09:00:00+00:00","end":"2026-07-18T10:00:00+00:00","status":"not-afk"}],
        pk="start")
    rollup.rollup_derived(d, day, rules=[])
    rec = list(d["reconciliation"].rows)[0]
    assert rec["active_untracked_min"] == 60
    assert rec["task_afk_min"] == 0

def test_afk_spans_day_scoped_excludes_prior_day(tmp_path):
    """_afk_raw is upserted every 30-min rollup with no pruning (pk=start), so it
    accumulates across days. Without day-scoping in _afk_spans, a day-N+1 rollup would
    still see day-N's not-afk spans and leak their minutes into active_untracked_min."""
    d = db.open_db(tmp_path / "t.db")
    day = date(2026,7,18)
    d["_afk_raw"].insert_all([
        # prior day (2026-07-17): 120 min not-afk — must be EXCLUDED
        {"start":"2026-07-17T09:00:00+00:00","end":"2026-07-17T11:00:00+00:00","status":"not-afk"},
        # this day (2026-07-18): 60 min not-afk — must be the ONLY span counted
        {"start":"2026-07-18T09:00:00+00:00","end":"2026-07-18T10:00:00+00:00","status":"not-afk"},
    ], pk="start")
    rollup.rollup_derived(d, day, rules=[])
    rec = list(d["reconciliation"].rows)[0]
    # if the prior-day span leaked in, this would be 180 (120+60); day-scoped it's 60
    assert rec["active_untracked_min"] == 60

def test_coverage_pct_computed_from_intervals_and_active_untracked(tmp_path):
    """coverage = 100 * interval_seconds / (interval_seconds + active_untracked_seconds).
    One tracked hour (3600s) + 30min (1800s) of not-afk-but-untracked time, non-overlapping
    -> 3600/(3600+1800) = 66.67% -> rounds to 67."""
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    d["intervals"].upsert_all([{"start": "20260718T100000Z", "end": "20260718T110000Z",
        "tags": ["work", "x"], "project": "work", "description": "x"}], pk="start")
    d["_afk_raw"].insert_all([
        {"start": "2026-07-18T09:00:00+00:00", "end": "2026-07-18T09:30:00+00:00", "status": "not-afk"},
    ], pk="start")
    rollup.rollup_derived(d, day, rules=[])
    adh = list(d["adherence"].rows)[0]
    assert adh["coverage_pct"] == 67

def test_coverage_pct_none_when_denominator_zero(tmp_path):
    """No intervals and no active-untracked time on the day -> the fraction is 0/0;
    coverage_pct must be None (not a crash, not a misleading 0%) so the note omits it."""
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    rollup.rollup_derived(d, day, rules=[])
    adh = list(d["adherence"].rows)[0]
    assert adh["coverage_pct"] is None

def test_clock_in_and_clock_out_from_sessions(tmp_path):
    """clock_in = earliest login/unlock event's local HH:MM; clock_out = latest
    logout/lock event's local HH:MM. Under the conftest TZ=UTC pin, 'local' == UTC."""
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    d["sessions"].upsert_all([
        {"ts": "2026-07-18T07:12:00+00:00", "type": "login", "detail": None},
        {"ts": "2026-07-18T12:00:00+00:00", "type": "lock", "detail": None},
        {"ts": "2026-07-18T12:30:00+00:00", "type": "unlock", "detail": None},
        {"ts": "2026-07-18T21:40:00+00:00", "type": "logout", "detail": None},
    ], pk="ts")
    rollup.rollup_derived(d, day, rules=[])
    adh = list(d["adherence"].rows)[0]
    assert adh["clock_in"] == "07:12"
    assert adh["clock_out"] == "21:40"

def test_clock_in_only_leaves_clock_out_none(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    d["sessions"].upsert_all([
        {"ts": "2026-07-18T07:12:00+00:00", "type": "login", "detail": None},
    ], pk="ts")
    rollup.rollup_derived(d, day, rules=[])
    adh = list(d["adherence"].rows)[0]
    assert adh["clock_in"] == "07:12"
    assert adh["clock_out"] is None

def test_no_sessions_clock_in_and_out_both_none(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    rollup.rollup_derived(d, day, rules=[])
    adh = list(d["adherence"].rows)[0]
    assert adh["clock_in"] is None
    assert adh["clock_out"] is None

def test_salah_due_conversion_across_non_utc_local_boundary(tmp_path, monkeypatch, request):
    """Every other derived test runs under the conftest TZ=UTC pin with UTC-offset
    inputs, so `.astimezone()` in _due_logday/_iv_logday is a no-op and the real
    UTC->local(+05:30)->4am-boundary conversion is never exercised. This overrides the
    process TZ to Asia/Kolkata for just this test (same finalizer pattern as
    tests/test_rollup_raw.py::test_rollup_raw_buckets_by_local_hour_not_utc) and picks a
    `due` that is ~05:00 IST — just after the 4am-local boundary, so it belongs to the
    IST logical day of the due date — but whose raw UTC hour (~23:30 the PRIOR day)
    would put it in a different day if the conversion were dropped or done in UTC."""
    import time

    monkeypatch.setenv("TZ", "Asia/Kolkata")
    time.tzset()

    def _restore_utc():
        os.environ["TZ"] = "UTC"
        time.tzset()

    request.addfinalizer(_restore_utc)

    d = db.open_db(tmp_path / "t3.db")
    day = date(2026, 7, 18)
    # 2026-07-17T23:31:00Z == 2026-07-18 05:01 IST (+05:30) — just after the 4am-local
    # boundary, so it belongs to the 2026-07-18 IST logical day, matching `day`.
    d["tasks"].upsert_all([
        {"uuid":"fajr-ist","description":"Fajr","project":"salah","status":"completed",
         "salah_status":"jamaah","due":"20260717T233100Z","tags":["salah"]},
    ], pk="uuid")
    rollup.rollup_derived(d, day, rules=[])
    salah = list(d["salah"].rows)
    assert len(salah) == 1
    assert salah[0]["prayer"] == "Fajr"
    adh = list(d["adherence"].rows)[0]
    assert adh["salah_logged"] == 1
