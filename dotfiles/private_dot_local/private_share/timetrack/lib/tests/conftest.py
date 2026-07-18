import os, sys, time, pathlib
# Pin the test-process timezone to UTC so tests that exercise datetime.astimezone()
# (e.g. rollup's hour-of-day bucketing) are deterministic regardless of the dev
# machine's locale (this box is Asia/Kolkata, +05:30 — without this pin,
# test_rollup_raw's UTC fixture timestamps land in a different local hour bucket).
os.environ["TZ"] = "UTC"
time.tzset()
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))  # make `timetrack` importable
