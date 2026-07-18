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
    assert "counts: true" in md               # YAML lowercase boolean for Dataview
