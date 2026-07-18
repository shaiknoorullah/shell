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
