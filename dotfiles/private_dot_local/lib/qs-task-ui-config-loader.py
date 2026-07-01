#!/usr/bin/env python3
import copy
import json
import os
import sys
from pathlib import Path

try:
    import yaml
except Exception as exc:  # pragma: no cover - caller reports JSON fallback
    print(json.dumps({"error": f"PyYAML unavailable: {exc}"}))
    raise SystemExit(0)


DEFAULT = {
    "theme": {
        "name": "Fallback",
        "fonts": {
            "text": "JetBrainsMono Nerd Font",
            "icon": "Material Symbols Rounded",
        },
        "colors": {
            "bg": "#13131f",
            "panel": "#1a1a2e",
            "panel_alt": "#232336",
            "surface": "#2d2d44",
            "surface_alt": "#3a3a52",
            "border": "#4a4a66",
            "border_subtle": "#2d2d44",
            "fg": "#f8f8f2",
            "dim": "#9a9ab8",
            "muted": "#70709a",
            "faint": "#585880",
            "accent": "#bd93f9",
            "accent_2": "#8be9fd",
            "cursor": "#3a3a52",
            "selection": "#44475a",
            "matched": "#f5d547",
            "mode_bg": "#bd93f9",
            "mode_fg": "#13131f",
            "statusbar": "#232336",
            "status_fg": "#9a9ab8",
            "priority_high": "#ff4d4d",
            "priority_medium": "#ff9e3b",
            "priority_low": "#8be9fd",
            "project": "#50fa7b",
            "tag": "#8be9fd",
            "due": "#f5d547",
            "overdue": "#ff4d4d",
            "today": "#ff9e3b",
            "done": "#50fa7b",
            "active": "#bd93f9",
            "warning": "#ff9e3b",
            "error": "#ff4d4d",
        },
    },
    "layout": {
        "density": "compact",
        "show_filter_pane": True,
        "show_detail_pane": True,
        "line_numbers": True,
        "reduced_motion": False,
    },
    "keybinds": {
        "move_down": ["Down"],
        "move_up": ["Up"],
        "first_task": ["gg", "Home"],
        "last_task": ["G", "End"],
        "page_down": ["Ctrl-D", "PageDown"],
        "page_up": ["Ctrl-U", "PageUp"],
        "start_block": ["Enter"],
        "start_or_stop_block": ["s"],
        "new_task": ["n"],
        "edit_task": ["e"],
        "done_task": ["x"],
        "delete_task": ["dd"],
        "cycle_priority": ["p"],
        "set_due": ["r"],
        "set_project": ["+"],
        "edit_tags": ["t"],
        "add_note": ["m"],
        "refresh": ["R"],
        "search": ["/"],
        "command_palette": [":", "Ctrl-P"],
        "filter_project": ["fp"],
        "filter_tag": ["ft"],
        "filter_status": ["fs"],
        "clear_filters": ["C"],
        "toggle_filter_pane": ["["],
        "toggle_detail_pane": ["]"],
        "help": ["?"],
        "escape": ["Esc"],
        "close": ["q"],
    },
}


def deep_merge(base, override):
    if not isinstance(override, dict):
        return copy.deepcopy(base)
    out = copy.deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = deep_merge(out[key], value)
        else:
            out[key] = copy.deepcopy(value)
    return out


def read_yaml(path):
    with open(path, "r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def resolve(base_dir, value):
    if not value:
        return None
    path = Path(os.path.expanduser(str(value)))
    if not path.is_absolute():
        path = base_dir / path
    return path


def as_bind_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return [str(v) for v in value]
    return [str(value)]


def normalize(active_path):
    active_path = Path(active_path).expanduser()
    base_dir = active_path.parent
    active = read_yaml(active_path)

    out = copy.deepcopy(DEFAULT)
    source = {"active": str(active_path)}

    theme_path = resolve(base_dir, active.get("theme"))
    if theme_path and theme_path.exists():
        out["theme"] = deep_merge(out["theme"], read_yaml(theme_path))
        source["theme"] = str(theme_path)

    keybind_path = resolve(base_dir, active.get("keybinds"))
    if keybind_path and keybind_path.exists():
        raw_keybinds = read_yaml(keybind_path)
        out["keybinds"] = deep_merge(out["keybinds"], raw_keybinds)
        source["keybinds"] = str(keybind_path)

    if isinstance(active.get("layout"), dict):
        out["layout"] = deep_merge(out["layout"], active["layout"])

    overrides = active.get("overrides") or {}
    if isinstance(overrides, dict):
        if isinstance(overrides.get("theme"), dict):
            out["theme"] = deep_merge(out["theme"], overrides["theme"])
        if isinstance(overrides.get("colors"), dict):
            out["theme"]["colors"] = deep_merge(out["theme"]["colors"], overrides["colors"])
        if isinstance(overrides.get("keybinds"), dict):
            out["keybinds"] = deep_merge(out["keybinds"], overrides["keybinds"])
        if isinstance(overrides.get("layout"), dict):
            out["layout"] = deep_merge(out["layout"], overrides["layout"])

    out["keybinds"] = {key: as_bind_list(value) for key, value in out["keybinds"].items()}
    out["source"] = source
    out["error"] = ""
    return out


def main():
    active = sys.argv[1] if len(sys.argv) > 1 else "~/.config/quickshell/task-ui.yaml"
    try:
        print(json.dumps(normalize(active), separators=(",", ":")))
    except Exception as exc:
        fallback = copy.deepcopy(DEFAULT)
        fallback["source"] = {"active": str(Path(active).expanduser())}
        fallback["error"] = str(exc)
        print(json.dumps(fallback, separators=(",", ":")))


if __name__ == "__main__":
    main()
