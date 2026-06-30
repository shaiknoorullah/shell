pragma ComponentBehavior: Bound

// ProjectsPage — browse pending tasks grouped by project. Lists Tasks.projects
// ([{name,count}]); pick a project to filter the Tasks page to it, or "All tasks"
// to clear the filter. Contract: a plain Item that fills the panel content area;
// uses Tasks (read), PanelState (filterProject + go).

import QtQuick
import QtQuick.Layouts
import qs.modules.tasks.components
import qs.services

Item {
    id: page

    readonly property var projects: Tasks.projects || []

    // Keyboard-navigable rows: index 0 is the "All tasks" entry (name "" clears
    // the filter), followed by the real projects. Selection indices line up with
    // this array, which the Repeater renders.
    readonly property var navList: [{ "name": "", "count": 0, "all": true }].concat(page.projects)
    readonly property int navCount: page.navList.length

    function navActivate(): void {
        if (PanelState.sel >= 0 && PanelState.sel < page.navList.length) {
            PanelState.filterProject = page.navList[PanelState.sel].name;
            PanelState.go("tasks");
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 0

        // header
        StyledText {
            text: "Projects"
            color: Theme.fg
            font.family: Theme.fontMono
            font.pixelSize: 15
            font.bold: true
        }

        // scrollable list ("All tasks" + projects)
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 12
            contentHeight: list.implicitHeight
            clip: true

            ColumnLayout {
                id: list
                width: parent.width
                spacing: 2

                Repeater {
                    model: page.navList
                    Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isAll: row.modelData.all === true
                        property bool hovered: false
                        Layout.fillWidth: true
                        implicitHeight: row.isAll ? 42 : 40
                        radius: 10
                        color: index === PanelState.sel
                            ? Theme.withAlpha(Theme.purple, 0.18)
                            : (row.hovered
                                ? Theme.withAlpha(Theme.purple, 0.12)
                                : (row.isAll ? Theme.surface0 : "transparent"))
                        border.width: row.isAll ? 1 : 0
                        border.color: Theme.bd

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 11

                            MaterialIcon {
                                text: row.isAll ? "checklist" : "folder_open"
                                color: row.isAll
                                    ? Theme.cyan
                                    : (row.hovered ? Theme.purple : Theme.comment)
                                font.pixelSize: row.isAll ? 18 : 17
                                Layout.preferredWidth: 20
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: row.isAll ? "All tasks" : (row.modelData.name || "(none)")
                                color: (row.isAll || row.hovered) ? Theme.fg : Theme.subtext0
                                font.family: Theme.fontMono
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            // count badge (projects only)
                            Rectangle {
                                visible: !row.isAll
                                implicitHeight: 20
                                implicitWidth: Math.max(20, badge.implicitWidth + 12)
                                radius: Theme.pill
                                color: Theme.s2
                                border.width: 1
                                border.color: Theme.bd
                                StyledText {
                                    id: badge
                                    anchors.centerIn: parent
                                    text: String(row.modelData.count)
                                    color: Theme.subtext0
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: { row.hovered = true; PanelState.sel = row.index; }
                            onExited: row.hovered = false
                            onClicked: {
                                PanelState.filterProject = row.modelData.name;
                                PanelState.go("tasks");
                            }
                        }
                    }
                }

                // empty state
                StyledText {
                    visible: page.projects.length === 0
                    Layout.topMargin: 6
                    text: "no projects yet"
                    color: Theme.comment
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                }
            }
        }
    }
}
