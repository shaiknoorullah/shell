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

def test_dump_deterministic_for_unregistered_table(tmp_path):
    """Regression test: dump() must handle tables not in db.PKS gracefully.
    Previously, the fallback sort key was (lambda r: r), which tries to sort
    dicts and raises TypeError. This test verifies the fix: sort by all columns."""
    p = tmp_path / "t.db"
    d = db.open_db(p)
    # Create a table NOT in db.PKS with 2+ rows in non-sorted order
    d["misc"].insert_all([
        {"id": 2, "name": "zebra", "value": 100},
        {"id": 1, "name": "apple", "value": 50},
    ])
    # Verify it's not in PKS
    assert "misc" not in db.PKS

    # Call dump() twice into separate dirs — should not raise
    o1, o2 = tmp_path / "a", tmp_path / "b"
    sync.dump(p, o1)
    sync.dump(p, o2)

    # Both outputs should be byte-identical (deterministic sort)
    a = (o1 / "misc.ndjson").read_text()
    b = (o2 / "misc.ndjson").read_text()
    assert a == b, "dump() output must be deterministic for unregistered tables"

    # Verify the output is sorted (by column tuple)
    lines = a.strip().splitlines()
    assert len(lines) == 2
    # Columns are [id, name, value]; sorted by column tuple means:
    # (1, 'apple', 50) comes before (2, 'zebra', 100)
    assert json.loads(lines[0]) == [1, "apple", 50]
    assert json.loads(lines[1]) == [2, "zebra", 100]
