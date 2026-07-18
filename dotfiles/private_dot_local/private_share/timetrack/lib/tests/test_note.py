from datetime import date, timedelta
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

def test_render_clocked_coverage_breaks_duration_and_salah_detail(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    ds = str(day)
    d["daily_summary"].upsert_all([{"date": ds, "categories": {"Infra": 12000, "Code": 10200},
        "tracked_seconds": 22200, "breaks": 2, "salah_logged": 2}], pk="date")
    d["adherence"].upsert_all([{"date": ds, "clock_in_logged": 1, "salah_logged": 2,
        "breaks_labeled": 1, "breaks_total": 2, "tasks_tracked": 3,
        "coverage_pct": 82, "clock_in": "07:12", "clock_out": "21:40"}], pk="date")
    d["salah"].upsert_all([
        {"date": ds, "prayer": "Fajr", "status": "jamaah"},
        {"date": ds, "prayer": "Dhuhr", "status": "alone"},
    ], pk=("date", "prayer"))
    d["reconciliation"].upsert_all([{"date": ds, "active_untracked_min": 0,
        "task_afk_min": 0, "present_idle_min": 0}], pk="date")
    d["breaks"].upsert_all([
        {"start": "2026-07-18T10:00:00+00:00", "duration": 600, "source": "auto", "label": None},
        {"start": "2026-07-18T14:00:00+00:00", "duration": 900, "source": "manual", "label": "lunch"},
    ], pk="start")
    md = note.render(d, day)
    assert "coverage_pct: 82" in md                              # frontmatter
    assert "07:12 → 21:40" in md                                 # Clocked in->out
    assert "coverage 82%" in md
    assert "Breaks   2 · 25m   (1 auto · 1 labeled)" in md        # 600+900s = 25m
    assert "(Fajr jamaah · Dhuhr alone)" in md                   # only logged prayers
    assert "Maghrib" not in md and "Isha" not in md              # unlogged prayers omitted from detail

def test_render_omits_clocked_times_and_coverage_when_absent(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    ds = str(day)
    d["daily_summary"].upsert_all([{"date": ds, "categories": {}, "tracked_seconds": 0,
        "breaks": 0, "salah_logged": 0}], pk="date")
    d["adherence"].upsert_all([{"date": ds, "clock_in_logged": 0, "salah_logged": 0,
        "breaks_labeled": 0, "breaks_total": 0, "tasks_tracked": 0,
        "coverage_pct": None, "clock_in": None, "clock_out": None}], pk="date")
    md = note.render(d, day)
    clocked_line = next(l for l in md.splitlines() if l.startswith("Clocked"))
    assert "→" not in clocked_line
    assert "coverage" not in clocked_line
    assert "0m tracked" in clocked_line
    assert "coverage_pct" not in md                              # frontmatter also omitted

def test_top_tasks_line_from_intervals_excludes_salah(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    ds = str(day)
    d["daily_summary"].upsert_all([{"date": ds, "categories": {}, "tracked_seconds": 0,
        "breaks": 0, "salah_logged": 0}], pk="date")
    d["adherence"].upsert_all([{"date": ds, "clock_in_logged": 0, "salah_logged": 0,
        "breaks_labeled": 0, "breaks_total": 0, "tasks_tracked": 2}], pk="date")
    d["intervals"].upsert_all([
        {"start": "20260718T083000Z", "end": "20260718T100000Z", "tags": ["work", "ovh-deployment"],
         "project": "work", "description": "ovh-deployment"},
        {"start": "20260718T110000Z", "end": "20260718T120000Z", "tags": ["work", "tenant-app"],
         "project": "work", "description": "tenant-app"},
        {"start": "20260718T130000Z", "end": "20260718T133000Z", "tags": ["salah", "Dhuhr"],
         "project": "salah", "description": "Dhuhr"},
    ], pk="start")
    md = note.render(d, day)
    assert "Top      ovh-deployment 1h30 · tenant-app 1h00" in md
    assert "Dhuhr" not in md                                     # salah interval excluded

def test_top_tasks_line_omitted_when_no_intervals(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    ds = str(day)
    d["daily_summary"].upsert_all([{"date": ds, "categories": {}, "tracked_seconds": 0,
        "breaks": 0, "salah_logged": 0}], pk="date")
    d["adherence"].upsert_all([{"date": ds, "clock_in_logged": 0, "salah_logged": 0,
        "breaks_labeled": 0, "breaks_total": 0, "tasks_tracked": 0}], pk="date")
    md = note.render(d, day)
    assert not any(l.startswith("Top") for l in md.splitlines())

def test_web_line_present_when_web_rows_exist(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    ds = str(day)
    d["daily_summary"].upsert_all([{"date": ds, "categories": {}, "tracked_seconds": 0,
        "breaks": 0, "salah_logged": 0}], pk="date")
    d["adherence"].upsert_all([{"date": ds, "clock_in_logged": 0, "salah_logged": 0,
        "breaks_labeled": 0, "breaks_total": 0, "tasks_tracked": 0}], pk="date")
    d["web"].upsert_all([
        {"date": ds, "domain": "github.com", "hour": 10, "seconds": 2400, "category": "Code"},
        {"date": ds, "domain": "mail.google.com", "hour": 11, "seconds": 900, "category": "Comms"},
    ], pk=("date", "domain", "hour"))
    md = note.render(d, day)
    assert "Web      github.com 40m · mail.google.com 15m" in md

def test_web_line_omitted_when_no_web_rows(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    ds = str(day)
    d["daily_summary"].upsert_all([{"date": ds, "categories": {}, "tracked_seconds": 0,
        "breaks": 0, "salah_logged": 0}], pk="date")
    d["adherence"].upsert_all([{"date": ds, "clock_in_logged": 0, "salah_logged": 0,
        "breaks_labeled": 0, "breaks_total": 0, "tasks_tracked": 0}], pk="date")
    md = note.render(d, day)
    assert not any(l.startswith("Web ") for l in md.splitlines())

def test_habit_bar_counts_correctly(tmp_path):
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    ds = str(day)
    d["daily_summary"].upsert_all([{"date": ds, "categories": {}, "tracked_seconds": 0,
        "breaks": 0, "salah_logged": 0}], pk="date")
    # today: counts (clock_in_logged + salah 5/5 + tasks>=1)
    d["adherence"].upsert_all([{"date": ds, "clock_in_logged": 1, "salah_logged": 5,
        "breaks_labeled": 0, "breaks_total": 0, "tasks_tracked": 1}], pk="date")
    # yesterday: also counts
    yday = str(day - timedelta(days=1))
    d["adherence"].upsert_all([{"date": yday, "clock_in_logged": 1, "salah_logged": 5,
        "breaks_labeled": 0, "breaks_total": 0, "tasks_tracked": 2}], pk="date")
    # day before yesterday: does NOT count (only 3/5 salah logged)
    dby = str(day - timedelta(days=2))
    d["adherence"].upsert_all([{"date": dby, "clock_in_logged": 1, "salah_logged": 3,
        "breaks_labeled": 0, "breaks_total": 0, "tasks_tracked": 1}], pk="date")
    md = note.render(d, day)
    assert "14-day habit:" in md
    assert "2/14" in md

def test_habit_sprint_start_none_header_has_no_day_count(tmp_path, monkeypatch):
    from timetrack import config
    monkeypatch.setattr(config, "HABIT_SPRINT_START", None)
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    ds = str(day)
    d["daily_summary"].upsert_all([{"date": ds, "categories": {}, "tracked_seconds": 0,
        "breaks": 0, "salah_logged": 0}], pk="date")
    d["adherence"].upsert_all([{"date": ds, "clock_in_logged": 0, "salah_logged": 0,
        "breaks_labeled": 0, "breaks_total": 0, "tasks_tracked": 0}], pk="date")
    md = note.render(d, day)
    header_line = next(l for l in md.splitlines() if l.startswith("## "))
    assert "of 14" not in header_line

def test_habit_sprint_start_set_shows_day_count_in_header(tmp_path, monkeypatch):
    from timetrack import config
    monkeypatch.setattr(config, "HABIT_SPRINT_START", date(2026, 7, 13))
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    ds = str(day)
    d["daily_summary"].upsert_all([{"date": ds, "categories": {}, "tracked_seconds": 0,
        "breaks": 0, "salah_logged": 0}], pk="date")
    d["adherence"].upsert_all([{"date": ds, "clock_in_logged": 0, "salah_logged": 0,
        "breaks_labeled": 0, "breaks_total": 0, "tasks_tracked": 0}], pk="date")
    md = note.render(d, day)
    header_line = next(l for l in md.splitlines() if l.startswith("## "))
    assert "day 6 of 14" in header_line          # (2026-07-18 - 2026-07-13).days + 1 == 6

def test_habit_sprint_start_future_date_clamps_to_day_1(tmp_path, monkeypatch):
    from timetrack import config
    monkeypatch.setattr(config, "HABIT_SPRINT_START", date(2026, 7, 20))
    d = db.open_db(tmp_path / "t.db")
    day = date(2026, 7, 18)
    ds = str(day)
    d["daily_summary"].upsert_all([{"date": ds, "categories": {}, "tracked_seconds": 0,
        "breaks": 0, "salah_logged": 0}], pk="date")
    d["adherence"].upsert_all([{"date": ds, "clock_in_logged": 0, "salah_logged": 0,
        "breaks_labeled": 0, "breaks_total": 0, "tasks_tracked": 0}], pk="date")
    md = note.render(d, day)
    header_line = next(l for l in md.splitlines() if l.startswith("## "))
    assert "day 1 of 14" in header_line
