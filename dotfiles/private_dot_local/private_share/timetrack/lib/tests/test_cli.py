from timetrack import __main__ as cli

def test_all_dispatch_smoke(tmp_path, monkeypatch):
    # point config at temp paths; stub the source readers so no live services are hit
    from timetrack import config, sources, categorize
    monkeypatch.setattr(config, "DB_PATH", tmp_path/"t.db")
    monkeypatch.setattr(config, "VAULT_DAILY", tmp_path/"vault")
    monkeypatch.setattr(config, "DATA_REPO", tmp_path/"norepo")
    monkeypatch.setattr(sources, "read_tasks", lambda: [])
    monkeypatch.setattr(sources, "read_intervals", lambda: [])
    monkeypatch.setattr(sources, "read_aw_events", lambda *a, **k: [])
    monkeypatch.setattr(sources, "read_logind", lambda: [])
    monkeypatch.setattr(categorize, "load_rules", lambda *a, **k: [])
    assert cli.main(["all"]) == 0
    assert (tmp_path/"vault").exists()      # note written

def test_unknown_subcommand_errors():
    assert cli.main(["bogus"]) == 2
