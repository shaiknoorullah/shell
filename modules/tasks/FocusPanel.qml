pragma ComponentBehavior: Bound

// ADHD command center — one keyboard-first Taskwarrior/Timewarrior surface.
// Inspired by Tuxedo's simple TUI shape: list + filters + detail + mode bar,
// with overlays for command palette, help, pickers, prompts, and confirmation.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.tasks.components
import qs.modules.tasks.pages
import qs.services

FloatingWindow {
    id: root

    implicitWidth: 1040
    implicitHeight: 640
    title: "focus-panel"
    color: TaskUiConfig.color("bg")
    visible: BarState.paletteOpen

    property string mode: "normal"       // normal | search | command | prompt | picker | confirm | help
    property string search: ""
    property string commandQuery: ""
    property int cursor: 0
    property int commandCursor: 0
    property string chord: ""
    property string lastMessage: "ready"
    property bool filterPaneOpen: TaskUiConfig.layoutBool("show_filter_pane")
    property bool detailPaneOpen: TaskUiConfig.layoutBool("show_detail_pane")

    property string projectFilter: ""
    property string tagFilter: ""
    property string statusFilter: "all"  // all | active | today | overdue | done

    property string promptKind: ""
    property string promptTitle: ""
    property string promptHint: ""
    property string promptSeed: ""

    property string pickerKind: ""
    property var pickerItems: []
    property int pickerCursor: 0

    property int confirmTaskId: -1
    property string confirmText: ""
    readonly property string panelIpcKeepAlive: PanelState.page

    readonly property int rowH: TaskUiConfig.layout.density === "cozy" ? 38
        : (TaskUiConfig.layout.density === "comfortable" ? 34 : 30)
    readonly property string todayKey: {
        const d = new Date();
        return String(d.getFullYear())
            + String(d.getMonth() + 1).padStart(2, "0")
            + String(d.getDate()).padStart(2, "0");
    }

    readonly property var actionDefs: [
        { "id": "start_block", "label": "start selected block", "group": "Work" },
        { "id": "start_or_stop_block", "label": "start / stop block", "group": "Work" },
        { "id": "new_task", "label": "new task and start", "group": "Edit" },
        { "id": "edit_task", "label": "edit description", "group": "Edit" },
        { "id": "done_task", "label": "mark task done", "group": "Edit" },
        { "id": "delete_task", "label": "delete task", "group": "Edit" },
        { "id": "cycle_priority", "label": "cycle priority", "group": "Edit" },
        { "id": "set_due", "label": "set due date", "group": "Edit" },
        { "id": "set_project", "label": "set project", "group": "Edit" },
        { "id": "edit_tags", "label": "add / remove tags", "group": "Edit" },
        { "id": "add_note", "label": "add note", "group": "Edit" },
        { "id": "search", "label": "search tasks", "group": "Find" },
        { "id": "filter_project", "label": "filter by project", "group": "Find" },
        { "id": "filter_tag", "label": "filter by tag", "group": "Find" },
        { "id": "filter_status", "label": "filter by status", "group": "Find" },
        { "id": "clear_filters", "label": "clear filters", "group": "Find" },
        { "id": "toggle_filter_pane", "label": "toggle filters pane", "group": "View" },
        { "id": "toggle_detail_pane", "label": "toggle detail pane", "group": "View" },
        { "id": "refresh", "label": "refresh tasks", "group": "System" },
        { "id": "command_palette", "label": "command palette", "group": "System" },
        { "id": "help", "label": "help", "group": "System" },
        { "id": "escape", "label": "escape / clear", "group": "System" },
        { "id": "close", "label": "close", "group": "System" }
    ]

    readonly property var commandHits: {
        const q = root.commandQuery.trim().toLowerCase();
        if (!q)
            return root.actionDefs;
        return root.actionDefs.filter(a =>
            a.label.toLowerCase().includes(q)
            || a.id.toLowerCase().replace(/_/g, " ").includes(q)
            || TaskUiConfig.bindLabel(a.id).toLowerCase().includes(q));
    }

    readonly property var visibleTasks: {
        const base = root.statusFilter === "done" ? (Tasks.done || []) : (Tasks.all || []);
        const q = root.search.trim().toLowerCase();
        return base.filter(t => {
            if (root.statusFilter === "active" && !(t.start !== undefined && t.start !== null && t.start !== ""))
                return false;
            if (root.statusFilter === "today" && root.dueKey(t) !== root.todayKey)
                return false;
            if (root.statusFilter === "overdue") {
                const dk = root.dueKey(t);
                if (!(dk !== "" && dk < root.todayKey))
                    return false;
            }
            if (root.projectFilter !== "" && (t.project || "") !== root.projectFilter)
                return false;
            if (root.tagFilter !== "" && !((t.tags || []).includes(root.tagFilter)))
                return false;
            if (q !== "") {
                const hay = [
                    t.description || "",
                    t.project || "",
                    (t.tags || []).join(" "),
                    t.priority || "",
                    t.due || ""
                ].join(" ").toLowerCase();
                if (!hay.includes(q))
                    return false;
            }
            return true;
        });
    }

    readonly property var selectedTask: {
        if (root.visibleTasks.length === 0)
            return null;
        return root.visibleTasks[Math.max(0, Math.min(root.cursor, root.visibleTasks.length - 1))];
    }

    onVisibleChanged: if (visible) {
        Tasks.refresh();
        Focus.refresh();
        ActiveTask.refresh();
        root.mode = "normal";
        root.chord = "";
        root.clampCursor();
        Qt.callLater(() => scope.forceActiveFocus());
    }

    onSearchChanged: {
        root.cursor = 0;
        root.clampCursor();
    }
    onProjectFilterChanged: root.cursor = 0
    onTagFilterChanged: root.cursor = 0
    onStatusFilterChanged: root.cursor = 0

    Connections {
        target: Tasks
        function onAllChanged() { root.clampCursor(); }
        function onDoneChanged() { root.clampCursor(); }
    }

    Timer {
        id: chordTimer
        interval: 700
        repeat: false
        onTriggered: root.chord = ""
    }

    Timer {
        id: refreshSoon
        interval: 900
        repeat: false
        onTriggered: {
            Tasks.refresh();
            ActiveTask.refresh();
            Focus.refresh();
        }
    }

    function c(name, fallback) {
        return TaskUiConfig.color(name, fallback);
    }

    function tinted(name, alpha) {
        return Theme.withAlpha(root.c(name), alpha);
    }

    function dueKey(t) {
        const due = t && t.due ? String(t.due) : "";
        return due.length >= 8 ? due.slice(0, 8) : "";
    }

    function dueLabel(t) {
        const key = root.dueKey(t);
        if (!key)
            return "";
        if (key === root.todayKey)
            return "today";
        return key.slice(0, 4) + "-" + key.slice(4, 6) + "-" + key.slice(6, 8);
    }

    function taskActive(t) {
        return !!(t && t.start !== undefined && t.start !== null && t.start !== "");
    }

    function priorityColor(p) {
        if (p === "H")
            return root.c("priority_high");
        if (p === "M")
            return root.c("priority_medium");
        if (p === "L")
            return root.c("priority_low");
        return root.c("muted");
    }

    function clampCursor() {
        const n = root.visibleTasks.length;
        if (n <= 0) {
            root.cursor = 0;
            return;
        }
        if (root.cursor < 0)
            root.cursor = 0;
        if (root.cursor >= n)
            root.cursor = n - 1;
    }

    function eventToken(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        let base = "";
        switch (event.key) {
        case Qt.Key_Down: base = "Down"; break;
        case Qt.Key_Up: base = "Up"; break;
        case Qt.Key_Left: base = "Left"; break;
        case Qt.Key_Right: base = "Right"; break;
        case Qt.Key_Return:
        case Qt.Key_Enter: base = "Enter"; break;
        case Qt.Key_Escape: base = "Esc"; break;
        case Qt.Key_Backspace: base = "Backspace"; break;
        case Qt.Key_Delete: base = "Delete"; break;
        case Qt.Key_Tab: base = "Tab"; break;
        case Qt.Key_Home: base = "Home"; break;
        case Qt.Key_End: base = "End"; break;
        case Qt.Key_PageDown: base = "PageDown"; break;
        case Qt.Key_PageUp: base = "PageUp"; break;
        default:
            base = event.text || "";
            break;
        }
        if (base === "")
            return "";
        if (ctrl || alt) {
            const mods = [];
            if (ctrl)
                mods.push("Ctrl");
            if (alt)
                mods.push("Alt");
            return mods.join("-") + "-" + (base.length === 1 ? base.toUpperCase() : base);
        }
        return base;
    }

    function isChordSpec(spec) {
        return spec.length === 2 && !spec.includes("-")
            && !["Up", "Down", "Esc"].includes(spec);
    }

    function actionForToken(token) {
        for (const a of root.actionDefs) {
            const binds = TaskUiConfig.bind(a.id);
            for (const b of binds)
                if (String(b) === token)
                    return a.id;
        }
        return "";
    }

    function resolveAction(token) {
        if (token === "")
            return "";
        if (root.chord !== "") {
            const combo = root.chord + token;
            root.chord = "";
            chordTimer.stop();
            const comboAction = root.actionForToken(combo);
            if (comboAction !== "")
                return comboAction;
        }
        const action = root.actionForToken(token);
        if (action !== "")
            return action;
        for (const a of root.actionDefs) {
            const binds = TaskUiConfig.bind(a.id);
            for (const b of binds) {
                const spec = String(b);
                if (root.isChordSpec(spec) && spec[0] === token) {
                    root.chord = token;
                    chordTimer.restart();
                    root.lastMessage = token + "…";
                    return "__pending";
                }
            }
        }
        return "";
    }

    function perform(action) {
        switch (action) {
        case "move_down":
            root.cursor = Math.min(root.visibleTasks.length - 1, root.cursor + 1);
            break;
        case "move_up":
            root.cursor = Math.max(0, root.cursor - 1);
            break;
        case "first_task":
            root.cursor = 0;
            break;
        case "last_task":
            root.cursor = Math.max(0, root.visibleTasks.length - 1);
            break;
        case "page_down":
            root.cursor = Math.min(root.visibleTasks.length - 1, root.cursor + 10);
            break;
        case "page_up":
            root.cursor = Math.max(0, root.cursor - 10);
            break;
        case "start_block":
            root.startSelected();
            break;
        case "start_or_stop_block":
            root.startOrStop();
            break;
        case "new_task":
            root.openPrompt("new", "new task", "", "Describe the task. Enter creates + starts a focus block.");
            break;
        case "edit_task":
            if (root.requireTask())
                root.openPrompt("description", "edit description", root.selectedTask.description || "", "Enter saves the description.");
            break;
        case "done_task":
            root.doneSelected();
            break;
        case "delete_task":
            root.confirmDelete();
            break;
        case "cycle_priority":
            root.cyclePriority();
            break;
        case "set_due":
            if (root.requireTask())
                root.openPrompt("due", "set due", root.dueLabel(root.selectedTask), "Use YYYY-MM-DD, tomorrow, friday, or empty to clear.");
            break;
        case "set_project":
            if (root.requireTask())
                root.openPrompt("project", "set project", root.selectedTask.project || "", "Project name. Empty clears it.");
            break;
        case "edit_tags":
            if (root.requireTask())
                root.openPrompt("tags", "edit tags", "", "Add tags separated by spaces. Prefix with - to remove.");
            break;
        case "add_note":
            if (root.requireTask())
                root.openPrompt("note", "add note", "", "Append a Taskwarrior annotation.");
            break;
        case "search":
            root.openSearch("");
            break;
        case "command_palette":
            root.openCommand("");
            break;
        case "filter_project":
            root.openPicker("project");
            break;
        case "filter_tag":
            root.openPicker("tag");
            break;
        case "filter_status":
            root.openPicker("status");
            break;
        case "clear_filters":
            root.clearFilters();
            break;
        case "toggle_filter_pane":
            root.filterPaneOpen = !root.filterPaneOpen;
            break;
        case "toggle_detail_pane":
            root.detailPaneOpen = !root.detailPaneOpen;
            break;
        case "refresh":
            Tasks.refresh();
            ActiveTask.refresh();
            Focus.refresh();
            root.lastMessage = "refreshed";
            break;
        case "help":
            root.mode = "help";
            Qt.callLater(() => scope.forceActiveFocus());
            break;
        case "escape":
            root.escapePanel();
            break;
        case "close":
            BarState.closePalette();
            break;
        }
        root.clampCursor();
    }

    function handleNormalKey(event) {
        const token = root.eventToken(event);
        const action = root.resolveAction(token);
        if (action === "__pending") {
            event.accepted = true;
            return;
        }
        if (action !== "") {
            root.perform(action);
            event.accepted = true;
            return;
        }
        if (token.length === 1 && event.text && event.text.length === 1 && !event.text.match(/\s/)) {
            root.openSearch(event.text);
            event.accepted = true;
        }
    }

    function handleOverlayKey(event) {
        const token = root.eventToken(event);
        if (root.mode === "help") {
            if (token === "Esc" || token === "?") {
                root.mode = "normal";
                event.accepted = true;
            }
            return;
        }
        if (root.mode === "confirm") {
            if (token === "y" || token === "Y" || token === "Enter") {
                root.deleteConfirmed();
                event.accepted = true;
            } else if (token === "n" || token === "N" || token === "Esc") {
                root.mode = "normal";
                root.lastMessage = "delete cancelled";
                event.accepted = true;
            }
        } else if (root.mode === "picker") {
            if (token === "Down") {
                root.pickerCursor = Math.min(root.pickerItems.length - 1, root.pickerCursor + 1);
                event.accepted = true;
            } else if (token === "Up") {
                root.pickerCursor = Math.max(0, root.pickerCursor - 1);
                event.accepted = true;
            } else if (token === "Enter") {
                root.choosePicker();
                event.accepted = true;
            } else if (token === "Esc") {
                root.closeOverlay();
                event.accepted = true;
            }
        }
    }

    function openSearch(seed) {
        root.mode = "search";
        root.search = seed || "";
        promptInput.text = root.search;
        Qt.callLater(() => {
            promptInput.forceActiveFocus();
            promptInput.cursorPosition = promptInput.text.length;
        });
    }

    function openCommand(seed) {
        root.mode = "command";
        root.commandQuery = seed || "";
        root.commandCursor = 0;
        promptInput.text = root.commandQuery;
        Qt.callLater(() => promptInput.forceActiveFocus());
    }

    function openPrompt(kind, title, seed, hint) {
        root.mode = "prompt";
        root.promptKind = kind;
        root.promptTitle = title;
        root.promptSeed = seed || "";
        root.promptHint = hint || "";
        promptInput.text = root.promptSeed;
        Qt.callLater(() => {
            promptInput.forceActiveFocus();
            promptInput.selectAll();
        });
    }

    function openPicker(kind) {
        root.mode = "picker";
        root.pickerKind = kind;
        root.pickerCursor = 0;
        if (kind === "project") {
            root.pickerItems = [{ "label": "All projects", "value": "" }]
                .concat((Tasks.projects || []).map(p => ({ "label": "+" + p.name + "  " + p.count, "value": p.name })));
        } else if (kind === "tag") {
            root.pickerItems = [{ "label": "All tags", "value": "" }]
                .concat((Tasks.tags || []).map(t => ({ "label": "#" + t.name + "  " + t.count, "value": t.name })));
        } else {
            root.pickerItems = [
                { "label": "All pending", "value": "all" },
                { "label": "Active block", "value": "active" },
                { "label": "Due today", "value": "today" },
                { "label": "Overdue", "value": "overdue" },
                { "label": "Recently done", "value": "done" }
            ];
        }
        Qt.callLater(() => scope.forceActiveFocus());
    }

    function closeOverlay() {
        root.mode = "normal";
        root.commandQuery = "";
        root.pickerKind = "";
        Qt.callLater(() => scope.forceActiveFocus());
    }

    function escapePanel() {
        if (root.mode !== "normal") {
            root.closeOverlay();
            return;
        }
        if (root.search !== "") {
            root.search = "";
            root.lastMessage = "search cleared";
            return;
        }
        if (root.projectFilter !== "" || root.tagFilter !== "" || root.statusFilter !== "all") {
            root.clearFilters();
            return;
        }
        BarState.closePalette();
    }

    function clearFilters() {
        root.projectFilter = "";
        root.tagFilter = "";
        root.statusFilter = "all";
        root.lastMessage = "filters cleared";
    }

    function requireTask() {
        if (!root.selectedTask) {
            root.lastMessage = "no task selected";
            return false;
        }
        if (root.statusFilter === "done") {
            root.lastMessage = "read-only in done view";
            return false;
        }
        return true;
    }

    function queued(message) {
        root.lastMessage = message;
        refreshSoon.restart();
    }

    function startSelected() {
        if (!root.requireTask())
            return;
        TaskActions.startBlock(String(root.selectedTask.id));
        root.queued("starting #" + root.selectedTask.id);
        BarState.closePalette();
    }

    function startOrStop() {
        if (root.selectedTask && root.taskActive(root.selectedTask)) {
            TaskActions.stopBlock();
            root.queued("stopping active block");
            return;
        }
        if (ActiveTask.active) {
            TaskActions.stopBlock();
            root.queued("stopping active block");
            return;
        }
        root.startSelected();
    }

    function doneSelected() {
        if (!root.requireTask())
            return;
        TaskActions.done(root.selectedTask.id);
        root.queued("queued done #" + root.selectedTask.id);
    }

    function confirmDelete() {
        if (!root.requireTask())
            return;
        root.confirmTaskId = root.selectedTask.id;
        root.confirmText = "Delete #" + root.selectedTask.id + " " + (root.selectedTask.description || "") + "?";
        root.mode = "confirm";
        Qt.callLater(() => scope.forceActiveFocus());
    }

    function deleteConfirmed() {
        if (root.confirmTaskId < 0)
            return;
        TaskActions.remove(root.confirmTaskId);
        root.queued("queued delete #" + root.confirmTaskId);
        root.confirmTaskId = -1;
        root.mode = "normal";
    }

    function cyclePriority() {
        if (!root.requireTask())
            return;
        const order = ["", "H", "M", "L"];
        const cur = root.selectedTask.priority || "";
        const next = order[(order.indexOf(cur) + 1 + order.length) % order.length];
        TaskActions.setPriority(root.selectedTask.id, next);
        root.queued("priority " + (next || "none") + " queued");
    }

    function commitPrompt(value) {
        const v = (value || "").trim();
        if (root.promptKind === "new") {
            if (!v) {
                root.lastMessage = "empty task ignored";
                root.closeOverlay();
                return;
            }
            TaskActions.startBlock("new:" + v);
            root.queued("creating + starting task");
            BarState.closePalette();
            return;
        }
        if (!root.requireTask()) {
            root.closeOverlay();
            return;
        }
        const id = root.selectedTask.id;
        if (root.promptKind === "description") {
            if (v)
                TaskActions.cmd(["modify", String(id), v]);
            root.queued("description queued");
        } else if (root.promptKind === "project") {
            TaskActions.setProject(id, v);
            root.queued("project queued");
        } else if (root.promptKind === "due") {
            TaskActions.setDue(id, v);
            root.queued("due queued");
        } else if (root.promptKind === "tags") {
            for (const raw of v.split(/[,\s]+/).filter(Boolean)) {
                if (raw[0] === "-")
                    TaskActions.removeTag(id, raw.slice(1));
                else
                    TaskActions.addTag(id, raw.replace(/^#/, ""));
            }
            root.queued("tags queued");
        } else if (root.promptKind === "note") {
            if (v)
                TaskActions.annotate(id, v);
            root.queued("note queued");
        }
        root.closeOverlay();
    }

    function runCommandHit() {
        if (root.commandHits.length === 0)
            return;
        const hit = root.commandHits[Math.max(0, Math.min(root.commandCursor, root.commandHits.length - 1))];
        root.closeOverlay();
        root.perform(hit.id);
    }

    function choosePicker() {
        if (root.pickerItems.length === 0)
            return;
        const it = root.pickerItems[Math.max(0, Math.min(root.pickerCursor, root.pickerItems.length - 1))];
        if (root.pickerKind === "project")
            root.projectFilter = it.value;
        else if (root.pickerKind === "tag")
            root.tagFilter = it.value;
        else
            root.statusFilter = it.value;
        root.lastMessage = it.value ? "filter: " + it.value : "filter cleared";
        root.closeOverlay();
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (root.mode === "normal")
                root.handleNormalKey(event);
            else
                root.handleOverlayKey(event);
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                color: root.c("panel")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    StyledText {
                        text: "TASKS"
                        color: root.c("accent")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 12
                        font.bold: true
                    }
                    StyledText {
                        text: `${root.visibleTasks.length}/${root.statusFilter === "done" ? (Tasks.done || []).length : (Tasks.all || []).length}`
                        color: root.c("dim")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 12
                    }
                    StyledText {
                        visible: root.search !== ""
                        text: `/${root.search}`
                        color: root.c("matched")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.maximumWidth: 260
                    }
                    StyledText {
                        visible: root.projectFilter !== ""
                        text: "+" + root.projectFilter
                        color: root.c("project")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 12
                    }
                    StyledText {
                        visible: root.tagFilter !== ""
                        text: "#" + root.tagFilter
                        color: root.c("tag")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 12
                    }
                    StyledText {
                        visible: root.statusFilter !== "all"
                        text: root.statusFilter
                        color: root.statusFilter === "overdue" ? root.c("overdue") : root.c("today")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 12
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: ActiveTask.active ? `${ActiveTask.elapsed} · ${ActiveTask.task}` : "idle"
                        color: ActiveTask.active ? root.c("active") : root.c("dim")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.maximumWidth: 420
                    }
                    StyledText {
                        text: TaskUiConfig.name
                        color: root.c("faint")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 11
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    visible: root.filterPaneOpen
                    Layout.fillHeight: true
                    Layout.preferredWidth: 190
                    color: root.c("panel_alt")

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        FilterBlock {
                            title: "STATUS"
                            rows: [
                                { "label": "all pending", "value": "all", "color": root.c("dim") },
                                { "label": "active", "value": "active", "color": root.c("active") },
                                { "label": "today", "value": "today", "color": root.c("today") },
                                { "label": "overdue", "value": "overdue", "color": root.c("overdue") },
                                { "label": "done", "value": "done", "color": root.c("done") }
                            ]
                            activeValue: root.statusFilter
                            onPicked: value => { root.statusFilter = value; root.lastMessage = "status: " + value; }
                        }

                        FilterBlock {
                            title: "PROJECTS"
                            rows: [{ "label": "all projects", "value": "", "color": root.c("dim") }]
                                .concat((Tasks.projects || []).slice(0, 7).map(p => ({
                                    "label": "+" + p.name + "  " + p.count,
                                    "value": p.name,
                                    "color": root.c("project")
                                })))
                            activeValue: root.projectFilter
                            onPicked: value => { root.projectFilter = value; root.lastMessage = value ? "project: " + value : "project cleared"; }
                        }

                        FilterBlock {
                            title: "TAGS"
                            rows: [{ "label": "all tags", "value": "", "color": root.c("dim") }]
                                .concat((Tasks.tags || []).slice(0, 6).map(t => ({
                                    "label": "#" + t.name + "  " + t.count,
                                    "value": t.name,
                                    "color": root.c("tag")
                                })))
                            activeValue: root.tagFilter
                            onPicked: value => { root.tagFilter = value; root.lastMessage = value ? "tag: " + value : "tag cleared"; }
                        }

                        Item { Layout.fillHeight: true }
                        StyledText {
                            Layout.fillWidth: true
                            text: `${TaskUiConfig.bindLabel("filter_project")} project · ${TaskUiConfig.bindLabel("filter_tag")} tag`
                            color: root.c("faint")
                            font.family: TaskUiConfig.fontText
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: 1
                    color: root.c("border_subtle")
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.c("bg")

                    Flickable {
                        id: listFlick
                        anchors.fill: parent
                        anchors.margins: 10
                        contentHeight: taskColumn.implicitHeight
                        clip: true

                        ColumnLayout {
                            id: taskColumn
                            width: listFlick.width
                            spacing: 1

                            Repeater {
                                model: root.visibleTasks

                                Rectangle {
                                    id: taskRow
                                    required property var modelData
                                    required property int index

                                    readonly property bool selected: taskRow.index === root.cursor
                                    readonly property bool activeTask: root.taskActive(taskRow.modelData)
                                    readonly property string dKey: root.dueKey(taskRow.modelData)
                                    readonly property bool overdue: taskRow.dKey !== "" && taskRow.dKey < root.todayKey
                                    readonly property bool today: taskRow.dKey === root.todayKey

                                    Layout.fillWidth: true
                                    implicitHeight: root.rowH
                                    radius: 6
                                    color: taskRow.selected ? root.tinted("accent", 0.22)
                                        : (taskRow.activeTask ? root.tinted("active", 0.10) : "transparent")
                                    border.width: taskRow.selected ? 1 : 0
                                    border.color: root.c("accent")

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        StyledText {
                                            visible: TaskUiConfig.layoutBool("line_numbers")
                                            text: String(taskRow.index + 1).padStart(2, " ")
                                            color: taskRow.selected ? root.c("fg") : root.c("faint")
                                            font.family: TaskUiConfig.fontText
                                            font.pixelSize: 11
                                            Layout.preferredWidth: 24
                                            horizontalAlignment: Text.AlignRight
                                        }
                                        StyledText {
                                            text: taskRow.activeTask ? "▶" : (taskRow.modelData.priority || "·")
                                            color: taskRow.activeTask ? root.c("active") : root.priorityColor(taskRow.modelData.priority || "")
                                            font.family: TaskUiConfig.fontText
                                            font.pixelSize: 12
                                            font.bold: taskRow.activeTask || (taskRow.modelData.priority || "") !== ""
                                            Layout.preferredWidth: 18
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                        StyledText {
                                            text: "#" + (taskRow.modelData.id || "")
                                            color: root.c("muted")
                                            font.family: TaskUiConfig.fontText
                                            font.pixelSize: 11
                                            Layout.preferredWidth: 38
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: taskRow.modelData.description || ""
                                            color: taskRow.selected ? root.c("fg") : root.c("dim")
                                            font.family: TaskUiConfig.fontText
                                            font.pixelSize: 13
                                            font.bold: taskRow.activeTask
                                            elide: Text.ElideRight
                                        }
                                        StyledText {
                                            visible: (taskRow.modelData.project || "") !== ""
                                            text: "+" + taskRow.modelData.project
                                            color: root.c("project")
                                            font.family: TaskUiConfig.fontText
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 110
                                        }
                                        StyledText {
                                            visible: (taskRow.modelData.tags || []).length > 0
                                            text: "#" + (taskRow.modelData.tags || [])[0]
                                            color: root.c("tag")
                                            font.family: TaskUiConfig.fontText
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 90
                                        }
                                        StyledText {
                                            visible: taskRow.dKey !== ""
                                            text: root.dueLabel(taskRow.modelData)
                                            color: taskRow.overdue ? root.c("overdue") : (taskRow.today ? root.c("today") : root.c("due"))
                                            font.family: TaskUiConfig.fontText
                                            font.pixelSize: 11
                                            font.bold: taskRow.overdue || taskRow.today
                                            Layout.preferredWidth: 82
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.cursor = taskRow.index
                                        onClicked: root.cursor = taskRow.index
                                        onDoubleClicked: root.startSelected()
                                    }
                                }
                            }

                            ColumnLayout {
                                visible: root.visibleTasks.length === 0
                                width: taskColumn.width
                                spacing: 10
                                Item { implicitHeight: 80 }
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.search !== "" || root.projectFilter !== "" || root.tagFilter !== "" || root.statusFilter !== "all"
                                        ? "no tasks match this view"
                                        : "no pending tasks"
                                    color: root.c("dim")
                                    font.family: TaskUiConfig.fontText
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: `${TaskUiConfig.bindLabel("new_task")} new · ${TaskUiConfig.bindLabel("clear_filters")} clear filters · ${TaskUiConfig.bindLabel("help")} help`
                                    color: root.c("faint")
                                    font.family: TaskUiConfig.fontText
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.detailPaneOpen
                    Layout.fillHeight: true
                    implicitWidth: 1
                    color: root.c("border_subtle")
                }

                Rectangle {
                    visible: root.detailPaneOpen
                    Layout.fillHeight: true
                    Layout.preferredWidth: 276
                    color: root.c("panel")

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        StyledText {
                            text: "DETAIL"
                            color: root.c("accent_2")
                            font.family: TaskUiConfig.fontText
                            font.pixelSize: 12
                            font.bold: true
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.selectedTask ? (root.selectedTask.description || "") : "(no task)"
                            color: root.c("fg")
                            font.family: TaskUiConfig.fontText
                            font.pixelSize: 14
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        DetailLine { label: "id"; value: root.selectedTask ? "#" + root.selectedTask.id : "—" }
                        DetailLine { label: "priority"; value: root.selectedTask ? (root.selectedTask.priority || "none") : "—"; valueColor: root.selectedTask ? root.priorityColor(root.selectedTask.priority || "") : root.c("dim") }
                        DetailLine { label: "project"; value: root.selectedTask ? (root.selectedTask.project || "none") : "—"; valueColor: root.c("project") }
                        DetailLine { label: "due"; value: root.selectedTask ? (root.dueLabel(root.selectedTask) || "none") : "—"; valueColor: root.selectedTask && root.dueKey(root.selectedTask) < root.todayKey && root.dueKey(root.selectedTask) !== "" ? root.c("overdue") : root.c("due") }
                        DetailLine { label: "tags"; value: root.selectedTask ? ((root.selectedTask.tags || []).join(" ") || "none") : "—"; valueColor: root.c("tag") }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: root.c("border_subtle")
                        }

                        StyledText {
                            text: ActiveTask.active ? "ACTIVE BLOCK" : "FOCUS"
                            color: ActiveTask.active ? root.c("active") : root.c("dim")
                            font.family: TaskUiConfig.fontText
                            font.pixelSize: 11
                            font.bold: true
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: ActiveTask.active ? `${ActiveTask.elapsed}\n${ActiveTask.task}` : "idle"
                            color: ActiveTask.active ? root.c("fg") : root.c("dim")
                            font.family: TaskUiConfig.fontText
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: root.c("border_subtle")
                        }

                        StyledText {
                            text: "KEYS"
                            color: root.c("accent")
                            font.family: TaskUiConfig.fontText
                            font.pixelSize: 11
                            font.bold: true
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: `${TaskUiConfig.bindLabel("start_block")} start\n${TaskUiConfig.bindLabel("edit_task")} edit · ${TaskUiConfig.bindLabel("done_task")} done\n${TaskUiConfig.bindLabel("set_due")} due · ${TaskUiConfig.bindLabel("set_project")} project\n${TaskUiConfig.bindLabel("command_palette")} command`
                            color: root.c("dim")
                            font.family: TaskUiConfig.fontText
                            font.pixelSize: 11
                            lineHeight: 1.25
                            wrapMode: Text.WordWrap
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                color: root.c("statusbar")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    Rectangle {
                        implicitHeight: 20
                        implicitWidth: modeText.implicitWidth + 16
                        radius: 3
                        color: root.mode === "normal" ? root.c("mode_bg") : root.c("surface_alt")
                        StyledText {
                            id: modeText
                            anchors.centerIn: parent
                            text: root.chord !== "" ? root.chord + "…" : root.mode.toUpperCase()
                            color: root.mode === "normal" ? root.c("mode_fg") : root.c("fg")
                            font.family: TaskUiConfig.fontText
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                    StyledText {
                        text: `↑↓ move · ${TaskUiConfig.bindLabel("start_block")} start · ${TaskUiConfig.bindLabel("new_task")} new · ${TaskUiConfig.bindLabel("search")} search · ${TaskUiConfig.bindLabel("command_palette")} command · ${TaskUiConfig.bindLabel("help")} help`
                        color: root.c("status_fg")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: TaskUiConfig.error ? "config fallback" : root.lastMessage
                        color: TaskUiConfig.error ? root.c("warning") : root.c("dim")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.maximumWidth: 260
                    }
                }
            }
        }
    }

    Rectangle {
        visible: root.mode === "search" || root.mode === "command" || root.mode === "prompt"
        anchors.fill: parent
        color: Theme.withAlpha(root.c("bg"), 0.55)

        Rectangle {
            width: Math.min(parent.width - 120, 680)
            height: root.mode === "command" ? 360 : 126
            anchors.centerIn: parent
            radius: 8
            color: root.c("panel")
            border.width: 1
            border.color: root.c("border")

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                StyledText {
                    text: root.mode === "search" ? "search"
                        : (root.mode === "command" ? "command palette" : root.promptTitle)
                    color: root.c("accent")
                    font.family: TaskUiConfig.fontText
                    font.pixelSize: 12
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 6
                    color: root.c("surface")
                    border.width: 1
                    border.color: root.c("accent")

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.mode === "command" ? ">" : (root.mode === "search" ? "/" : "›")
                        color: root.c("accent")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 14
                        font.bold: true
                    }

                    TextInput {
                        id: promptInput
                        anchors.fill: parent
                        anchors.leftMargin: 32
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.c("fg")
                        selectionColor: root.c("selection")
                        selectedTextColor: root.c("fg")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 14
                        focus: true
                        onTextChanged: {
                            if (root.mode === "search")
                                root.search = text;
                            else if (root.mode === "command") {
                                root.commandQuery = text;
                                root.commandCursor = 0;
                            }
                        }
                        Keys.onPressed: event => {
                            const token = root.eventToken(event);
                            if (token === "Esc") {
                                root.closeOverlay();
                                event.accepted = true;
                            } else if (token === "Enter") {
                                if (root.mode === "command")
                                    root.runCommandHit();
                                else if (root.mode === "prompt")
                                    root.commitPrompt(promptInput.text);
                                else
                                    root.closeOverlay();
                                event.accepted = true;
                            } else if (token === "Down" && root.mode === "command") {
                                root.commandCursor = Math.min(root.commandHits.length - 1, root.commandCursor + 1);
                                event.accepted = true;
                            } else if (token === "Up" && root.mode === "command") {
                                root.commandCursor = Math.max(0, root.commandCursor - 1);
                                event.accepted = true;
                            }
                        }
                    }
                }

                StyledText {
                    visible: root.mode !== "command"
                    Layout.fillWidth: true
                    text: root.mode === "search"
                        ? `${root.visibleTasks.length} matches · Enter keeps · Esc cancels`
                        : root.promptHint
                    color: root.c("dim")
                    font.family: TaskUiConfig.fontText
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Flickable {
                    visible: root.mode === "command"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: commandList.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: commandList
                        width: parent.width
                        spacing: 1

                        Repeater {
                            model: root.commandHits
                            CommandRow {}
                        }
                    }
                }

                StyledText {
                    visible: root.mode === "command"
                    text: "↑↓ navigate · Enter run · Esc cancel"
                    color: root.c("faint")
                    font.family: TaskUiConfig.fontText
                    font.pixelSize: 11
                }
            }
        }
    }

    Rectangle {
        visible: root.mode === "picker"
        anchors.fill: parent
        color: Theme.withAlpha(root.c("bg"), 0.55)

        Rectangle {
            width: 420
            height: Math.min(420, 92 + root.pickerItems.length * 32)
            anchors.centerIn: parent
            radius: 8
            color: root.c("panel")
            border.width: 1
            border.color: root.c("border")

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                StyledText {
                    text: "pick " + root.pickerKind
                    color: root.c("accent")
                    font.family: TaskUiConfig.fontText
                    font.pixelSize: 12
                    font.bold: true
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: pickerList.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: pickerList
                        width: parent.width
                        spacing: 1

                        Repeater {
                            model: root.pickerItems
                            Rectangle {
                                id: pickRow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 30
                                radius: 6
                                color: pickRow.index === root.pickerCursor ? root.tinted("accent", 0.22) : "transparent"
                                StyledText {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    verticalAlignment: Text.AlignVCenter
                                    text: pickRow.modelData.label
                                    color: pickRow.index === root.pickerCursor ? root.c("fg") : root.c("dim")
                                    font.family: TaskUiConfig.fontText
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.pickerCursor = pickRow.index
                                    onClicked: root.choosePicker()
                                }
                            }
                        }
                    }
                }
                StyledText {
                    text: "↑↓ choose · Enter apply · Esc cancel"
                    color: root.c("faint")
                    font.family: TaskUiConfig.fontText
                    font.pixelSize: 11
                }
            }
        }
    }

    Rectangle {
        visible: root.mode === "confirm"
        anchors.fill: parent
        color: Theme.withAlpha(root.c("bg"), 0.62)

        Rectangle {
            width: Math.min(parent.width - 140, 620)
            height: 140
            anchors.centerIn: parent
            radius: 8
            color: root.c("panel")
            border.width: 1
            border.color: root.c("error")

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                StyledText {
                    text: "confirm delete"
                    color: root.c("error")
                    font.family: TaskUiConfig.fontText
                    font.pixelSize: 12
                    font.bold: true
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.confirmText
                    color: root.c("fg")
                    font.family: TaskUiConfig.fontText
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                }
                StyledText {
                    text: "Enter/y delete · Esc/n cancel"
                    color: root.c("dim")
                    font.family: TaskUiConfig.fontText
                    font.pixelSize: 11
                }
            }
        }
    }

    Rectangle {
        visible: root.mode === "help"
        anchors.fill: parent
        color: Theme.withAlpha(root.c("bg"), 0.62)

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 70, 900)
            height: Math.min(parent.height - 70, 520)
            radius: 8
            color: root.c("panel")
            border.width: 1
            border.color: root.c("border")

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: "help"
                        color: root.c("accent")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: "? / Esc close"
                        color: root.c("dim")
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 11
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 2
                    columnSpacing: 22
                    rowSpacing: 8

                    HelpSection { title: "WORK"; actionIds: ["start_block", "start_or_stop_block", "new_task", "done_task", "refresh"] }
                    HelpSection { title: "EDIT"; actionIds: ["edit_task", "set_due", "set_project", "edit_tags", "cycle_priority", "add_note", "delete_task"] }
                    HelpSection { title: "FIND"; actionIds: ["search", "filter_project", "filter_tag", "filter_status", "clear_filters"] }
                    HelpSection { title: "SYSTEM"; actionIds: ["command_palette", "toggle_filter_pane", "toggle_detail_pane", "escape", "close"] }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "YAML: ~/.config/quickshell/task-ui.yaml · " + (TaskUiConfig.error ? "config error: " + TaskUiConfig.error : TaskUiConfig.sourceTheme)
                    color: TaskUiConfig.error ? root.c("warning") : root.c("faint")
                    font.family: TaskUiConfig.fontText
                    font.pixelSize: 10
                    elide: Text.ElideMiddle
                }
            }
        }
    }

    component FilterBlock: ColumnLayout {
        id: block
        property string title: ""
        property var rows: []
        property string activeValue: ""
        signal picked(string value)

        Layout.fillWidth: true
        spacing: 3

        StyledText {
            text: block.title
            color: root.c("accent_2")
            font.family: TaskUiConfig.fontText
            font.pixelSize: 10
            font.bold: true
        }
        Repeater {
            model: block.rows
            Rectangle {
                id: filterRow
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 23
                radius: 5
                color: block.activeValue === filterRow.modelData.value ? root.tinted("accent", 0.18) : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 7
                    spacing: 6
                    StyledText {
                        Layout.fillWidth: true
                        text: filterRow.modelData.label
                        color: block.activeValue === filterRow.modelData.value ? root.c("fg") : filterRow.modelData.color
                        font.family: TaskUiConfig.fontText
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: block.picked(filterRow.modelData.value)
                }
            }
        }
    }

    component DetailLine: RowLayout {
        property string label: ""
        property string value: ""
        property color valueColor: root.c("dim")
        Layout.fillWidth: true
        spacing: 8
        StyledText {
            text: parent.label
            color: root.c("faint")
            font.family: TaskUiConfig.fontText
            font.pixelSize: 11
            Layout.preferredWidth: 72
        }
        StyledText {
            Layout.fillWidth: true
            text: parent.value
            color: parent.valueColor
            font.family: TaskUiConfig.fontText
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    component CommandRow: Rectangle {
        id: commandRow
        required property var modelData
        required property int index
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: commandRow.index === root.commandCursor ? root.tinted("accent", 0.22) : "transparent"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            StyledText {
                text: commandRow.modelData.label
                color: commandRow.index === root.commandCursor ? root.c("fg") : root.c("dim")
                font.family: TaskUiConfig.fontText
                font.pixelSize: 13
                font.bold: commandRow.index === root.commandCursor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            StyledText {
                text: TaskUiConfig.bindLabel(commandRow.modelData.id)
                color: root.c("faint")
                font.family: TaskUiConfig.fontText
                font.pixelSize: 11
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onEntered: root.commandCursor = commandRow.index
            onClicked: root.runCommandHit()
        }
    }

    component HelpSection: ColumnLayout {
        id: helpSection
        property string title: ""
        property var actionIds: []
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 4
        StyledText {
            text: helpSection.title
            color: root.c("accent_2")
            font.family: TaskUiConfig.fontText
            font.pixelSize: 11
            font.bold: true
        }
        Repeater {
            model: helpSection.actionIds
            RowLayout {
                required property string modelData
                Layout.fillWidth: true
                spacing: 10
                StyledText {
                    text: TaskUiConfig.bindLabel(modelData)
                    color: root.c("matched")
                    font.family: TaskUiConfig.fontText
                    font.pixelSize: 11
                    font.bold: true
                    Layout.preferredWidth: 92
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: {
                        for (const a of root.actionDefs)
                            if (a.id === modelData)
                                return a.label;
                        return modelData;
                    }
                    color: root.c("dim")
                    font.family: TaskUiConfig.fontText
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
    }
}
