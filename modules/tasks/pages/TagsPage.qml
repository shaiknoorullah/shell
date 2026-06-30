pragma ComponentBehavior: Bound

// TagsPage — browse pending tasks by tag. Lists Tasks.tags as wrapping chips
// ("#name  count"); click a chip to filter the task list to that tag.
// Contract: a plain Item that fills the panel content area; uses Tasks (read),
// PanelState (nav/filter).

import QtQuick
import QtQuick.Layouts
import qs.modules.tasks.components
import qs.services

Item {
    id: page

    readonly property var navList: Tasks.tags || []
    readonly property int navCount: page.navList.length

    function navActivate(): void {
        if (PanelState.sel >= 0 && PanelState.sel < page.navList.length) {
            PanelState.filterTag = page.navList[PanelState.sel].name;
            PanelState.go("tasks");
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 0

        StyledText {
            text: "Tags"
            color: Theme.fg
            font.family: Theme.fontMono
            font.pixelSize: 15
            font.bold: true
        }

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 12; implicitHeight: 1; color: Theme.bd }

        StyledText {
            visible: page.navList.length === 0
            Layout.topMargin: 16
            text: "no tags yet"
            color: Theme.comment
            font.family: Theme.fontMono
            font.pixelSize: 13
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 12
            visible: page.navList.length > 0
            contentHeight: flow.implicitHeight
            clip: true

            Flow {
                id: flow
                width: parent.width
                spacing: 8

                Repeater {
                    model: page.navList

                    Rectangle {
                        id: chip
                        required property var modelData
                        required property int index

                        property bool hovered: false

                        implicitWidth: chipRow.implicitWidth + 22
                        implicitHeight: 32
                        radius: Theme.chip
                        color: index === PanelState.sel
                            ? Theme.withAlpha(Theme.purple, 0.18)
                            : (chip.hovered ? Theme.withAlpha(Theme.cyan, 0.15) : Theme.s1)
                        border.width: 1
                        border.color: chip.hovered ? Theme.withAlpha(Theme.cyan, 0.4) : Theme.bd

                        RowLayout {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 8

                            StyledText {
                                text: "#" + (chip.modelData.name ?? "")
                                color: Theme.cyan
                                font.family: Theme.fontMono
                                font.pixelSize: 13
                            }
                            StyledText {
                                text: String(chip.modelData.count ?? 0)
                                color: Theme.comment
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                chip.hovered = true;
                                PanelState.sel = chip.index;
                            }
                            onExited: chip.hovered = false
                            onClicked: {
                                PanelState.filterTag = chip.modelData.name;
                                PanelState.go("tasks");
                            }
                        }
                    }
                }
            }
        }
    }
}
