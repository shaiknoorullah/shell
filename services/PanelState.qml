pragma Singleton

// PANEL STATE SINGLETON — navigation + cross-page state for the multi-page focus
// panel (FocusPanel.qml). Pages read/drive this to switch views and pass a
// selected task to the Detail page.

import Quickshell

Singleton {
    id: root

    // Current page: "focus" | "tasks" | "detail" | "projects" | "tags" | "reports"
    property string page: "focus"

    // The task the Detail page edits (taskwarrior id).
    property int selectedTaskId: -1

    // Keyboard selection index within the current list page (driven by the
    // FocusPanel key router; list pages render this as the highlighted row).
    property int sel: 0

    // Tasks-page filters.
    property string filterProject: ""           // "" = all
    property string filterTag: ""               // "" = all
    property string filterStatus: "pending"     // pending | today | overdue | all

    readonly property var order: ["focus", "tasks", "projects", "tags", "reports"]

    function go(p: string): void {
        root.page = p;
        root.sel = 0;
    }
    function cycle(dir: int): void {
        let i = root.order.indexOf(root.page);
        if (i < 0)
            i = 0;
        root.go(root.order[(i + dir + root.order.length) % root.order.length]);
    }
    function openDetail(id: int): void {
        root.selectedTaskId = id;
        root.page = "detail";
        root.sel = 0;
    }
    function reset(): void {
        root.page = "focus";
        root.selectedTaskId = -1;
        root.filterProject = "";
        root.filterTag = "";
        root.filterStatus = "pending";
    }
}
