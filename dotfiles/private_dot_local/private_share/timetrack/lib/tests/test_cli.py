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
    monkeypatch.setattr(sources, "list_aw_buckets", lambda: [])   # no live AW call; no web bucket -> rollup_web skipped
    monkeypatch.setattr(categorize, "load_rules", lambda *a, **k: [])
    assert cli.main(["all"]) == 0
    assert (tmp_path/"vault").exists()      # note written

def test_rollup_calls_rollup_web_when_web_bucket_present(tmp_path, monkeypatch):
    """_do_rollup must auto-detect a web bucket via sources.list_aw_buckets() and feed
    its events into rollup.rollup_web — proving the wiring isn't just inert-by-default."""
    from timetrack import config, sources, categorize, rollup

    monkeypatch.setattr(config, "DB_PATH", tmp_path/"t.db")
    monkeypatch.setattr(config, "WEB_BUCKET", None)
    monkeypatch.setattr(sources, "read_tasks", lambda: [])
    monkeypatch.setattr(sources, "read_intervals", lambda: [])
    monkeypatch.setattr(sources, "read_logind", lambda: [])
    monkeypatch.setattr(sources, "list_aw_buckets", lambda: ["aw-watcher-window_devsupreme", "aw-watcher-web-brave"])

    calls = []
    def _fake_read_aw_events(bucket, *a, **k):
        calls.append(bucket)
        return []
    monkeypatch.setattr(sources, "read_aw_events", _fake_read_aw_events)
    monkeypatch.setattr(categorize, "load_rules", lambda *a, **k: [])

    web_calls = []
    real_rollup_web = rollup.rollup_web
    monkeypatch.setattr(rollup, "rollup_web", lambda *a, **k: (web_calls.append(1), real_rollup_web(*a, **k))[-1])

    assert cli.main(["rollup"]) == 0
    assert "aw-watcher-web-brave" in calls
    assert web_calls == [1]

def test_unknown_subcommand_errors():
    assert cli.main(["bogus"]) == 2
