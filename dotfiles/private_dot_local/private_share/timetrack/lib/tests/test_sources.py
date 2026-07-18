import json, pathlib, subprocess
from timetrack import sources
FIX = pathlib.Path(__file__).parent / "fixtures"

def test_read_tasks_normalizes_missing_keys(monkeypatch):
    raw = (FIX / "task_export.json").read_text()
    monkeypatch.setattr(sources, "_run", lambda *a, **k: raw)
    tasks = sources.read_tasks()
    assert tasks[0]["uuid"] == "aaaa"
    assert tasks[0]["salah_status"] is None          # missing → None
    assert tasks[1]["salah_status"] == "jamaah"

def test_read_intervals_open_interval_has_none_end(monkeypatch):
    raw = (FIX / "timew_export.json").read_text()
    monkeypatch.setattr(sources, "_run", lambda *a, **k: raw)
    iv = sources.read_intervals()
    assert iv[0]["end"] == "20260718T093000Z"
    assert iv[1]["end"] is None
    assert iv[1]["tags"] == ["work", "tenant-app fix"]

def test_read_logind_parses_jsonl(tmp_path, monkeypatch):
    f = tmp_path / "logind.jsonl"
    f.write_text('{"ts":"2026-07-18T00:39:46+05:30","type":"lock","detail":{}}\n')
    monkeypatch.setattr(sources.config, "LOGIND_JSONL", f)
    ev = sources.read_logind()
    assert ev[0]["type"] == "lock"
