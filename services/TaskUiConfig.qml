pragma Singleton

// TASK UI CONFIG — active YAML theme/keybind profile normalized to JSON.
// QML reads JSON because it has no native YAML parser. The helper script merges:
//   ~/.config/quickshell/task-ui.yaml
//   selected task-ui/themes/*.yaml
//   selected task-ui/keybinds/*.yaml

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string name: "Fallback"
    property string fontText: "JetBrainsMono Nerd Font"
    property string fontIcon: "Material Symbols Rounded"
    property var colors: ({})
    property var keybinds: ({})
    property var layout: ({})
    property string error: ""
    property string sourceTheme: ""
    property string sourceKeybinds: ""

    readonly property var defaultColors: ({
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
        "error": "#ff4d4d"
    })

    readonly property var defaultLayout: ({
        "density": "compact",
        "show_filter_pane": true,
        "show_detail_pane": true,
        "line_numbers": true,
        "reduced_motion": false
    })

    readonly property var defaultKeybinds: ({
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
        "close": ["q"]
    })

    function cloneObject(o) {
        const out = ({});
        for (const k in o)
            out[k] = o[k];
        return out;
    }

    function mergeObject(base, extra) {
        const out = root.cloneObject(base || {});
        for (const k in (extra || {}))
            out[k] = extra[k];
        return out;
    }

    function color(name, fallback) {
        return root.colors[name] || root.defaultColors[name] || fallback || "#ff00ff";
    }

    function bind(action) {
        const b = root.keybinds[action] || root.defaultKeybinds[action] || [];
        return b instanceof Array ? b : [String(b)];
    }

    function bindLabel(action) {
        return root.bind(action).join(" / ");
    }

    function layoutBool(name) {
        const v = root.layout[name];
        if (v === undefined)
            return !!root.defaultLayout[name];
        return !!v;
    }

    function load(raw) {
        try {
            const data = JSON.parse((raw || "").trim() || "{}");
            const theme = data.theme || {};
            root.name = theme.name || "Fallback";
            root.fontText = (theme.fonts && theme.fonts.text) || "JetBrainsMono Nerd Font";
            root.fontIcon = (theme.fonts && theme.fonts.icon) || "Material Symbols Rounded";
            root.colors = root.mergeObject(root.defaultColors, theme.colors || {});
            root.keybinds = root.mergeObject(root.defaultKeybinds, data.keybinds || {});
            root.layout = root.mergeObject(root.defaultLayout, data.layout || {});
            root.error = data.error || "";
            root.sourceTheme = data.source ? (data.source.theme || "") : "";
            root.sourceKeybinds = data.source ? (data.source.keybinds || "") : "";
        } catch (e) {
            root.name = "Fallback";
            root.colors = root.defaultColors;
            root.keybinds = root.defaultKeybinds;
            root.layout = root.defaultLayout;
            root.error = String(e);
        }
    }

    function refresh() {
        proc.running = true;
    }

    Process {
        id: proc
        command: ["sh", "-c", "qs-task-ui-config.sh"]
        stdout: StdioCollector {
            onStreamFinished: root.load(text)
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
