pragma ComponentBehavior: Bound

// TasksPage — the main task list manager (page 2 of the FocusPanel). Segmented
// status filter [All|Pending|Today|Overdue] over a LOCAL statusFilter, plus
// project/tag chips driven by PanelState. Scrollable Dracula-glass rows: per-row
// complete-circle, description (+active block accent), project/tag/priority/due
// metadata, and hover-revealed start/delete actions.
// Contract: a plain Item filling the panel content area; uses Tasks (read),
// TaskActions (write), PanelState (nav/filters), BarState (close).

import QtQuick
import QtQuick.Layouts
import qs.modules.tasks.components
import qs.services

Item {
    id: page

    // local segmented filter — pending | today | overdue | all
    property string statusFilter: "pending"

    // today's YYYYMMDD as a string, for compact-ISO due comparison
    readonly property string todayKey: {
        const d = new Date();
        const y = d.getFullYear();
        const m = ("0" + (d.getMonth() + 1)).slice(-2);
        const day = ("0" + d.getDate()).slice(-2);
        return "" + y + m + day;
    }

    function dueKey(t: var): string {
        const due = t && t.due ? String(t.due) : "";
        return due.length >= 8 ? due.slice(0, 8) : "";
    }

    readonly property var navListTasks: {
        const all = Tasks.all || [];
        const proj = PanelState.filterProject || "";
        const tag = PanelState.filterTag || "";
        const f = page.statusFilter;
        const today = page.todayKey;
        return all.filter(t => {
            // status filter
            if (f === "today") {
                if (page.dueKey(t) !== today)
                    return false;
            } else if (f === "overdue") {
                const dk = page.dueKey(t);
                if (!(dk !== "" && dk < today))
                    return false;
            }
            // pending / all → no status narrowing (Tasks.all is already pending)

            // project filter
            if (proj !== "" && t.project !== proj)
                return false;
            // tag filter
            if (tag !== "" && !((t.tags || []).includes(tag)))
                return false;
            return true;
        });
    }

    // ── Keyboard-nav contract (driven by FocusPanel key router) ──────────
    // `visible` is the already-filtered array the list renders, so selection
    // indices line up; navCount/navActivate are read by the panel.
    readonly property var navList: page.navListTasks
    readonly property int navCount: page.navList.length
    function navActivate(): void {
        if (PanelState.sel >= 0 && PanelState.sel < page.navList.length)
            PanelState.openDetail(page.navList[PanelState.sel].id);
    }

    component Segment: Rectangle {
        id: seg
        required property string label
        required property string value
        readonly property bool active: page.statusFilter === seg.value
        implicitHeight: 26
        implicitWidth: segText.implicitWidth + 22
        radius: Theme.pill
        color: seg.active ? Theme.withAlpha(Theme.purple, 0.22) : "transparent"
        border.width: 1
        border.color: seg.active ? Theme.withAlpha(Theme.purple, 0.55) : Theme.bd
        StyledText {
            id: segText
            anchors.centerIn: parent
            text: seg.label
            color: seg.active ? Theme.fg : Theme.subtext0
            font.family: Theme.fontMono
            font.pixelSize: 12
            font.bold: seg.active
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: page.statusFilter = seg.value
        }
    }

    // small reusable metadata chip
    component MetaChip: Rectangle {
        id: chip
        required property string txt
        property color fgColor: Theme.subtext0
        property color bgColor: Theme.withAlpha(Theme.surface1, 0.7)
        property color bdColor: Theme.bd
        implicitHeight: 18
        implicitWidth: chipText.implicitWidth + 12
        radius: Theme.chip
        color: chip.bgColor
        border.width: 1
        border.color: chip.bdColor
        StyledText {
            id: chipText
            anchors.centerIn: parent
            text: chip.txt
            color: chip.fgColor
            font.family: Theme.fontMono
            font.pixelSize: 10
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 0

        // 1. header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                text: "Tasks"
                color: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: 15
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            StyledText {
                text: `(${page.navList.length} visible)`
                color: Theme.comment
                font.family: Theme.fontMono
                font.pixelSize: 12
            }
        }

        // 2. filter bar
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 7

            Segment { label: "All";     value: "all" }
            Segment { label: "Pending"; value: "pending" }
            Segment { label: "Today";   value: "today" }
            Segment { label: "Overdue"; value: "overdue" }

            Item { Layout.fillWidth: true }

            // project filter chip (removable)
            Rectangle {
                visible: (PanelState.filterProject || "") !== ""
                implicitHeight: 24
                implicitWidth: projChipRow.implicitWidth + 16
                radius: Theme.pill
                color: Theme.withAlpha(Theme.blue, 0.16)
                border.width: 1
                border.color: Theme.withAlpha(Theme.blue, 0.5)
                RowLayout {
                    id: projChipRow
                    anchors.centerIn: parent
                    spacing: 6
                    StyledText {
                        text: `project:${PanelState.filterProject}`
                        color: Theme.blue
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }
                    StyledText {
                        text: "✕"
                        color: Theme.blue
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PanelState.filterProject = ""
                }
            }

            // tag filter chip (removable)
            Rectangle {
                visible: (PanelState.filterTag || "") !== ""
                implicitHeight: 24
                implicitWidth: tagChipRow.implicitWidth + 16
                radius: Theme.pill
                color: Theme.withAlpha(Theme.green, 0.16)
                border.width: 1
                border.color: Theme.withAlpha(Theme.green, 0.5)
                RowLayout {
                    id: tagChipRow
                    anchors.centerIn: parent
                    spacing: 6
                    StyledText {
                        text: `#${PanelState.filterTag}`
                        color: Theme.green
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }
                    StyledText {
                        text: "✕"
                        color: Theme.green
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PanelState.filterTag = ""
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 12; implicitHeight: 1; color: Theme.bd }

        // 3. scrollable list
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8
            contentHeight: col.implicitHeight
            clip: true

            ColumnLayout {
                id: col
                width: parent.width
                spacing: 2

                Repeater {
                    model: page.navList

                    Rectangle {
                        id: row
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 44
                        radius: 10
                        color: index === PanelState.sel
                            ? Theme.withAlpha(Theme.purple, 0.18)
                            : (rowHover.hovered ? Theme.withAlpha(Theme.purple, 0.12) : "transparent")

                        readonly property bool isActive: row.modelData.start !== undefined && row.modelData.start !== null && row.modelData.start !== ""
                        readonly property string dKey: page.dueKey(row.modelData)
                        readonly property bool isOverdue: row.dKey !== "" && row.dKey < page.todayKey
                        readonly property var tagList: row.modelData.tags || []
                        readonly property string prio: row.modelData.priority || ""

                        // body click → detail (sits under the action controls)
                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            property bool hovered: containsMouse
                            onEntered: PanelState.sel = row.index
                            onClicked: PanelState.openDetail(row.modelData.id)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 10

                            // complete circle (its own MouseArea → done only)
                            Item {
                                implicitWidth: 18
                                implicitHeight: 18
                                Layout.alignment: Qt.AlignVCenter
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: doneArea.containsMouse ? "check_circle" : "radio_button_unchecked"
                                    color: doneArea.containsMouse ? Theme.green : Theme.comment
                                    font.pixelSize: 18
                                }
                                MouseArea {
                                    id: doneArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: TaskActions.done(row.modelData.id)
                                }
                            }

                            // description
                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.description || ""
                                color: row.isActive ? Theme.purple : Theme.fg
                                font.family: Theme.fontMono
                                font.pixelSize: 13
                                font.bold: row.isActive
                                elide: Text.ElideRight
                            }

                            // project chip
                            MetaChip {
                                visible: (row.modelData.project || "") !== ""
                                txt: row.modelData.project || ""
                                fgColor: Theme.blue
                                bgColor: Theme.withAlpha(Theme.blue, 0.14)
                                bdColor: Theme.withAlpha(Theme.blue, 0.4)
                            }

                            // up to 2 tag chips
                            Repeater {
                                model: row.tagList.slice(0, 2)
                                MetaChip {
                                    required property var modelData
                                    txt: "#" + modelData
                                    fgColor: Theme.green
                                    bgColor: Theme.withAlpha(Theme.green, 0.13)
                                    bdColor: Theme.withAlpha(Theme.green, 0.38)
                                }
                            }

                            // priority badge
                            MetaChip {
                                visible: row.prio === "H" || row.prio === "M" || row.prio === "L"
                                txt: row.prio
                                fgColor: row.prio === "H" ? Theme.red : (row.prio === "M" ? Theme.orange : Theme.cyan)
                                bgColor: Theme.withAlpha(row.prio === "H" ? Theme.red : (row.prio === "M" ? Theme.orange : Theme.cyan), 0.16)
                                bdColor: Theme.withAlpha(row.prio === "H" ? Theme.red : (row.prio === "M" ? Theme.orange : Theme.cyan), 0.45)
                            }

                            // due text
                            StyledText {
                                visible: row.dKey !== ""
                                text: `${row.dKey.slice(4, 6)}/${row.dKey.slice(6, 8)}`
                                color: row.isOverdue ? Theme.red : Theme.comment
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                font.bold: row.isOverdue
                            }

                            // hover actions: start + delete
                            RowLayout {
                                visible: rowHover.hovered
                                spacing: 4
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    radius: 7
                                    color: startArea.containsMouse ? Theme.withAlpha(Theme.purple, 0.28) : Theme.withAlpha(Theme.surface1, 0.6)
                                    border.width: 1
                                    border.color: Theme.bd
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "play_arrow"
                                        color: Theme.purple
                                        font.pixelSize: 18
                                    }
                                    MouseArea {
                                        id: startArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            TaskActions.startBlock(String(row.modelData.id));
                                            BarState.closePalette();
                                        }
                                    }
                                }

                                Rectangle {
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    radius: 7
                                    color: delArea.containsMouse ? Theme.withAlpha(Theme.red, 0.28) : Theme.withAlpha(Theme.surface1, 0.6)
                                    border.width: 1
                                    border.color: Theme.bd
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "delete"
                                        color: Theme.red
                                        font.pixelSize: 17
                                    }
                                    MouseArea {
                                        id: delArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: TaskActions.remove(row.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                // empty state
                StyledText {
                    visible: page.navList.length === 0
                    Layout.topMargin: 6
                    text: "no tasks match this view"
                    color: Theme.comment
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                }
            }
        }
    }
}
