import json
from timetrack import db, sync

def test_dump_is_stable_and_pk_sorted(tmp_path):
    p = tmp_path / "t.db"
    d = db.open_db(p)
    # same (date,category,app), differing hour → pk sort orders by hour
    d["usage"].upsert_all([
        {"date":"2026-07-18","category":"Code","app":"kitty","hour":10,"seconds":600},
        {"date":"2026-07-18","category":"Code","app":"kitty","hour":9,"seconds":300},
    ], pk=("date","category","app","hour"))
    o1, o2 = tmp_path/"a", tmp_path/"b"
    sync.dump(p, o1); sync.dump(p, o2)
    a = (o1/"usage.ndjson").read_text(); b = (o2/"usage.ndjson").read_text()
    assert a == b                                   # deterministic across runs
    lines = a.strip().splitlines()
    # dump writes JSON arrays [date,category,app,hour,seconds]; index 3 == hour
    assert json.loads(lines[0])[3] == 9             # sorted by pk → hour 9 first
    assert json.loads(lines[1])[3] == 10

def test_push_noops_without_repo(tmp_path):
    assert sync.push(repo=tmp_path/"nope", db_path=tmp_path/"t.db") is False
