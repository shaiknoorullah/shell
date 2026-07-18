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
