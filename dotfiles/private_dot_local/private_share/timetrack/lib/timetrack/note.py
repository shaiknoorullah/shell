"""Render + write the Obsidian daily note (never-guilt, scannable)."""
import json
from datetime import date
from . import config
from .rollup import streak, PRAYERS

def _hm(seconds) -> str:
    m = round(seconds / 60); return f"{m//60}h{m%60:02d}" if m >= 60 else f"{m}m"

def _bars(seconds, top) -> str:
    return "▓" * max(1, round(8 * seconds / top)) if top else ""

def render(db, day: date) -> str:
    ds = str(day)
    summ = next((r for r in db["daily_summary"].rows if r["date"] == ds), {})
    adh = next((r for r in db["adherence"].rows if r["date"] == ds), {})
    rec = next((r for r in db["reconciliation"].rows if r["date"] == ds), {})
    salah = {r["prayer"]: r.get("status") for r in db["salah"].rows if r["date"] == ds}
    cats_raw = summ.get("categories", {}) or {}
    # sqlite-utils stores nested dicts as JSON strings; parse if needed
    cats = json.loads(cats_raw) if isinstance(cats_raw, str) else cats_raw
    top = max(cats.values()) if cats else 0
    n = streak(db, day)
    where = "  ".join(f"{c} {_hm(s)} {_bars(s, top)}" for c, s in sorted(cats.items(), key=lambda kv:-kv[1]))
    tick = "".join("✅" if salah.get(p) and salah[p] != "missed" else ("◻" if salah.get(p) == "missed" else "▫") for p in PRAYERS)
    lines = [
        "---", f"date: {ds}", f"tracked_seconds: {summ.get('tracked_seconds',0)}",
        f"salah_logged: {adh.get('salah_logged',0)}", f"streak: {n}",
        f"counts: {bool(adh.get('clock_in_logged') and adh.get('salah_logged')==5 and adh.get('tasks_tracked',0)>=1)}",
        "---", "",
        f"## ⏱ {ds}   ·   🔥 {n}-day streak", "",
        f"Tracked  {_hm(summ.get('tracked_seconds',0))}",
        f"Where    {where}",
        f"Breaks   {summ.get('breaks',0)}   ({adh.get('breaks_labeled',0)} labeled)",
        f"Salah    {tick}  logged {adh.get('salah_logged',0)}/5",
    ]
    au = rec.get("active_untracked_min", 0)
    if au:
        lines += ["", f"Review (optional)  ~{au}m active with no task running"]
    return "\n".join(lines) + "\n"

def write(db, day: date):
    config.VAULT_DAILY.mkdir(parents=True, exist_ok=True)
    p = config.VAULT_DAILY / f"{day}.md"
    p.write_text(render(db, day))
    return p
