pragma ComponentBehavior: Bound

// FocusPage — the quick-start launcher (page 1 of the FocusPanel). Auto-focused
// fuzzy search over pending tasks; ↑↓ pick, ⏎ start a deep block, type-to-create.
// Contract: a plain Item that fills the panel content area; uses Tasks (read),
// TaskActions.startBlock (write), Focus (salah runway), BarState (close).

import QtQuick
import QtQuick.Layouts
import qs.modules.tasks.components
import qs.services

Item {
    id: page

    property string query: ""
    property int sel: 0

    readonly property var results: {
        const q = page.query.trim().toLowerCase();
        const all = Tasks.all || [];
        if (!q)
            return all;
        return all.filter(t => (t.description || "").toLowerCase().includes(q));
    }
    readonly property bool canCreate: page.query.trim().length > 0
    readonly property int rowCount: page.results.length + (page.canCreate ? 1 : 0)

    function clampSel(): void {
        if (page.sel < 0)
            page.sel = page.rowCount > 0 ? page.rowCount - 1 : 0;
        if (page.sel >= page.rowCount)
            page.sel = 0;
    }
    function activate(): void {
        if (page.sel < page.results.length)
            TaskActions.startBlock(String(page.results[page.sel].id));
        else if (page.canCreate)
            TaskActions.startBlock("new:" + page.query.trim());
        BarState.closePalette();
    }

    Component.onCompleted: input.forceActiveFocus()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 0

        StyledText {
            text: "Start a deep block"
            color: Theme.fg
            font.family: Theme.fontMono
            font.pixelSize: 15
            font.bold: true
        }

        // search row
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 12

            MaterialIcon {
                text: "search"
                color: Theme.purple
                font.pixelSize: 20
                Layout.preferredWidth: 20
                Layout.alignment: Qt.AlignVCenter
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: 26
                TextInput {
                    id: input
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    font.family: Theme.fontMono
                    font.pixelSize: 16
                    clip: true
                    selectByMouse: true
                    onTextChanged: { page.query = text; page.sel = 0; }
                    Keys.onUpPressed: { page.sel -= 1; page.clampSel(); }
                    Keys.onDownPressed: { page.sel += 1; page.clampSel(); }
                    Keys.onReturnPressed: page.activate()
                    Keys.onEnterPressed: page.activate()
                    Keys.onEscapePressed: BarState.closePalette()
                    Keys.onTabPressed: PanelState.cycle(1)
                    Keys.onBacktabPressed: PanelState.cycle(-1)
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
                    text: "type a task to start or create…"
                    color: Theme.comment
                    font.family: Theme.fontMono
                    font.pixelSize: 16
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 12; implicitHeight: 1; color: Theme.bd }

        // results
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8
            contentHeight: list.implicitHeight
            clip: true

            ColumnLayout {
                id: list
                width: parent.width
                spacing: 2

                Repeater {
                    model: page.results
                    Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 10
                        color: page.sel === row.index ? Theme.withAlpha(Theme.purple, 0.18) : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 11
                            MaterialIcon {
                                text: page.sel === row.index ? "play_arrow" : "radio_button_unchecked"
                                color: page.sel === row.index ? Theme.purple : Theme.comment
                                font.pixelSize: 18
                                Layout.preferredWidth: 18
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.description ?? ""
                                color: page.sel === row.index ? Theme.fg : Theme.subtext0
                                font.family: Theme.fontMono
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: row.modelData.project ?? ""
                                color: Theme.comment
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: page.sel = row.index
                            onClicked: { page.sel = row.index; page.activate(); }
                        }
                    }
                }

                Rectangle {
                    visible: page.canCreate
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 10
                    color: page.sel === page.results.length ? Theme.withAlpha(Theme.green, 0.18) : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 11
                        MaterialIcon {
                            text: "add_circle"
                            color: Theme.green
                            font.pixelSize: 18
                            Layout.preferredWidth: 18
                            Layout.alignment: Qt.AlignVCenter
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: `create & start “${page.query.trim()}”`
                            color: Theme.green
                            font.family: Theme.fontMono
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onEntered: page.sel = page.results.length
                        onClicked: { page.sel = page.results.length; page.activate(); }
                    }
                }

                StyledText {
                    visible: page.rowCount === 0
                    text: "no pending tasks — type to create one"
                    color: Theme.comment
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.bd }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            StyledText {
                text: "↑↓ move   ⏎ start   esc close"
                color: Theme.subtext0
                font.family: Theme.fontMono
                font.pixelSize: 11
            }
            Item { Layout.fillWidth: true }
            StyledText {
                text: Focus.nextPrayerName
                    ? `→ ${Focus.nextPrayerName} ${Focus.nextPrayerTime} · one block, one outcome`
                    : "one block, one outcome"
                color: Theme.ctxAccent
                font.family: Theme.fontMono
                font.pixelSize: 11
            }
        }
    }
}
