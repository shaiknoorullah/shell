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
    # not-afk 09:00–10:00 (local) with NO timew interval → 60 min active-untracked
    d["_afk_raw"].insert_all(
        [{"start":"2026-07-18T09:00:00+05:30","end":"2026-07-18T10:00:00+05:30","status":"not-afk"}],
        pk="start")
    rollup.rollup_derived(d, day, rules=[])
    rec = list(d["reconciliation"].rows)[0]
    assert rec["active_untracked_min"] == 60
    assert rec["task_afk_min"] == 0
