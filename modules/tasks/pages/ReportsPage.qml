pragma ComponentBehavior: Bound

// ReportsPage — overview / reports (page of the FocusPanel). Read-only digest:
// a stats strip + grouped sections (Overdue, Due today, Next up, Recently
// completed). Contract: a plain Item filling the panel content area; uses
// Tasks (read), ActiveTask (active block), PanelState.openDetail (nav).

import QtQuick
import QtQuick.Layouts
import qs.modules.tasks.components
import qs.services

Item {
    id: page

    // today as YYYYMMDD string, computed once with Qt (taskwarrior `due`
    // fields are compact ISO like "20260620T183000Z" — compare leading 8 chars).
    readonly property string todayYYYYMMDD: {
        const d = new Date();
        const y = String(d.getFullYear());
        const m = String(d.getMonth() + 1).padStart(2, "0");
        const day = String(d.getDate()).padStart(2, "0");
        return y + m + day;
    }

    readonly property var overdue: {
        const all = Tasks.all || [];
        return all.filter(t => t.due && String(t.due).slice(0, 8) < page.todayYYYYMMDD).slice(0, 6);
    }
    readonly property var dueToday: {
        const all = Tasks.all || [];
        return all.filter(t => t.due && String(t.due).slice(0, 8) === page.todayYYYYMMDD).slice(0, 6);
    }
    readonly property var nextUp: (Tasks.all || []).slice(0, 5)
    readonly property var recent: (Tasks.done || []).slice(0, 6)

    // Flat array of actionable rows (overdue + due-today + next-up, in display
    // order; excludes the read-only completed section). Keyboard selection
    // indices line up with this array; each actionable section delegate maps
    // its row to a running global index via the section's base offset.
    readonly property var navList: page.overdue.concat(page.dueToday).concat(page.nextUp)
    readonly property int navCount: page.navList.length

    function navActivate(): void {
        if (PanelState.sel >= 0 && PanelState.sel < page.navList.length) {
            const it = page.navList[PanelState.sel];
            if (it && it.id !== undefined)
                PanelState.openDetail(it.id);
        }
    }

    function dueLabel(t): string {
        if (!t.due)
            return "";
        const s = String(t.due).slice(0, 8);
        if (s < page.todayYYYYMMDD)
            return "overdue";
        if (s === page.todayYYYYMMDD)
            return "today";
        return s.slice(0, 4) + "-" + s.slice(4, 6) + "-" + s.slice(6, 8);
    }
    function doneLabel(t): string {
        const raw = t.end || t.modified || "";
        const s = String(raw).slice(0, 8);
        if (s.length !== 8)
            return "";
        return s.slice(0, 4) + "-" + s.slice(4, 6) + "-" + s.slice(6, 8);
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true

        ColumnLayout {
            id: col
            width: parent.width
            // emulate ColumnLayout margins:18 inside the Flickable
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 18
            spacing: 0

            // ── header ───────────────────────────────────────────────
            StyledText {
                text: "Reports"
                color: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: 15
                font.bold: true
            }

            // ── stats strip ──────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14
                spacing: 10

                component StatCard: Rectangle {
                    property string label: ""
                    property string value: ""
                    property color accent: Theme.purple
                    Layout.fillWidth: true
                    implicitHeight: 56
                    radius: Theme.chip
                    color: Theme.s1
                    border.width: 1
                    border.color: Theme.bd
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 2
                        StyledText {
                            Layout.fillWidth: true
                            text: parent.parent.label
                            color: Theme.comment
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: parent.parent.value
                            color: parent.parent.accent
                            font.family: Theme.fontMono
                            font.pixelSize: 18
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }
                }

                StatCard {
                    label: "Pending"
                    value: String((Tasks.all || []).length)
                    accent: Theme.purple
                }
                StatCard {
                    label: "Done (21d)"
                    value: String((Tasks.done || []).length)
                    accent: Theme.green
                }
                StatCard {
                    label: "Active"
                    value: ActiveTask.active ? (ActiveTask.task || "—") : "—"
                    accent: Theme.cyan
                }
            }

            // ── sections ─────────────────────────────────────────────
            // Section = header + up to ~6 compact rows. A row shows the
            // description (elide) + a right-aligned due/project meta. Clicking
            // a (non-completed) row opens its detail.
            //
            // For actionable (non-completed) sections, `baseIndex` is the
            // section's offset into page.navList; each row's global selection
            // index is baseIndex + its position within the section. The
            // completed section keeps baseIndex -1 (never selectable).
            component Section: ColumnLayout {
                property string title: ""
                property color accent: Theme.purple
                property var rows: []
                property bool completed: false
                property string emptyText: "nothing here"
                property int baseIndex: -1

                Layout.fillWidth: true
                Layout.topMargin: 16
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        implicitWidth: 3
                        implicitHeight: 12
                        radius: 2
                        color: parent.parent.accent
                    }
                    StyledText {
                        text: parent.parent.title
                        color: parent.parent.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: String((parent.parent.rows || []).length)
                        color: Theme.comment
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }
                }

                StyledText {
                    visible: (parent.rows || []).length === 0
                    text: parent.emptyText
                    color: Theme.comment
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    Layout.topMargin: 2
                }

                Repeater {
                    model: (parent.rows || []).slice(0, 6)
                    Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        // the enclosing Section (Repeater delegates are parented
                        // to the Section ColumnLayout itself, cf. model: parent.rows)
                        readonly property var section: row.parent
                        // running global index into page.navList (actionable
                        // sections only); completed section stays unselectable.
                        readonly property int navIndex: row.section.completed
                            ? -1 : row.section.baseIndex + row.index
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: Theme.chip
                        color: (!row.section.completed && row.navIndex === PanelState.sel)
                            ? Theme.withAlpha(Theme.purple, 0.18)
                            : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            spacing: 10
                            MaterialIcon {
                                text: row.section.completed ? "check_circle" : "radio_button_unchecked"
                                color: row.section.completed ? Theme.green : row.section.accent
                                font.pixelSize: 17
                                Layout.preferredWidth: 18
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.description ?? ""
                                color: row.section.completed ? Theme.subtext0 : Theme.fg
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: row.section.completed
                                    ? page.doneLabel(row.modelData)
                                    : (page.dueLabel(row.modelData)
                                        || (row.modelData.project ?? ""))
                                color: {
                                    if (row.section.completed)
                                        return Theme.comment;
                                    const lbl = page.dueLabel(row.modelData);
                                    if (lbl === "overdue")
                                        return Theme.red;
                                    if (lbl === "today")
                                        return Theme.orange;
                                    return Theme.comment;
                                }
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: row.section.completed ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onEntered: {
                                if (!row.section.completed)
                                    PanelState.sel = row.navIndex;
                            }
                            onClicked: {
                                if (!row.section.completed)
                                    PanelState.openDetail(row.modelData.id);
                            }
                        }
                    }
                }
            }

            Section {
                title: "Overdue"
                accent: Theme.red
                rows: page.overdue
                emptyText: "nothing overdue"
                baseIndex: 0
            }
            Section {
                title: "Due today"
                accent: Theme.orange
                rows: page.dueToday
                emptyText: "nothing due today"
                baseIndex: page.overdue.length
            }
            Section {
                title: "Next up"
                accent: Theme.purple
                rows: page.nextUp
                emptyText: "no pending tasks"
                baseIndex: page.overdue.length + page.dueToday.length
            }
            Section {
                title: "Recently completed"
                accent: Theme.green
                rows: page.recent
                completed: true
                emptyText: "no completions in 21d"
            }

            Item { Layout.fillWidth: true; implicitHeight: 18 }
        }
    }
}
