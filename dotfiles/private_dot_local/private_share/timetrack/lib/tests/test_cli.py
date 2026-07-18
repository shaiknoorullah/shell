from timetrack import __main__ as cli

def test_all_dispatch_smoke(tmp_path, monkeypatch):
    # point config at temp paths; stub the source readers so no live services are hit
    from timetrack import config, sources
    monkeypatch.setattr(config, "DB_PATH", tmp_path/"t.db")
    monkeypatch.setattr(config, "VAULT_DAILY", tmp_path/"vault")
    monkeypatch.setattr(config, "DATA_REPO", tmp_path/"norepo")
    monkeypatch.setattr(sources, "read_tasks", lambda: [])
    monkeypatch.setattr(sources, "read_intervals", lambda: [])
    monkeypatch.setattr(sources, "read_aw_events", lambda *a, **k: [])
    monkeypatch.setattr(sources, "read_logind", lambda: [])
    assert cli.main(["all"]) == 0
    assert (tmp_path/"vault").exists()      # note written
