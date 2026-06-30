pragma ComponentBehavior: Bound

// DetailPage — edit a single task (page 5 of the FocusPanel). Description /
// project / priority / due / tags / annotations / actions. Reads the task out
// of Tasks.all by PanelState.selectedTaskId; all writes go through TaskActions.
// Contract: TextInputs are seeded ONCE (Component.onCompleted + a task-change
// Connections) — never live-bound to task.*, which would clobber typing.

import QtQuick
import QtQuick.Layouts
import qs.modules.tasks.components
import qs.services

Item {
    id: page

    readonly property var task: {
        const a = Tasks.all || [];
        for (var i = 0; i < a.length; i++)
            if (a[i].id === PanelState.selectedTaskId)
                return a[i];
        return null;
    }

    readonly property string curPriority: page.task && page.task.priority ? page.task.priority : ""

    // ---- reusable bits -------------------------------------------------------

    component FieldLabel: StyledText {
        color: Theme.comment
        font.family: Theme.fontMono
        font.pixelSize: 11
        font.bold: true
    }

    // a bordered TextInput box; seed .text imperatively, emit `accepted(text)`
    component InputBox: Rectangle {
        id: box
        property alias text: ti.text
        property string placeholder: ""
        signal accepted(string value)
        Layout.fillWidth: true
        implicitHeight: 32
        radius: Theme.chip
        color: Theme.s1
        border.color: ti.activeFocus ? Theme.purple : Theme.bd
        border.width: 1
        TextInput {
            id: ti
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            font.family: Theme.fontMono
            font.pixelSize: 13
            clip: true
            selectByMouse: true
            onAccepted: box.accepted(text)
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            visible: ti.text.length === 0
            text: box.placeholder
            color: Theme.comment
            font.family: Theme.fontMono
            font.pixelSize: 13
        }
    }

    component PillButton: Rectangle {
        id: pill
        property string label: ""
        property bool active: false
        property color accent: Theme.purple
        signal clicked
        implicitWidth: txt.implicitWidth + 24
        implicitHeight: 28
        radius: Theme.pill
        color: pill.active ? Theme.withAlpha(pill.accent, 0.22)
                           : (ma.containsMouse ? Theme.hov : Theme.s1)
        border.color: pill.active ? pill.accent : Theme.bd
        border.width: 1
        StyledText {
            id: txt
            anchors.centerIn: parent
            text: pill.label
            color: pill.active ? pill.accent : Theme.subtext0
            font.family: Theme.fontMono
            font.pixelSize: 12
            font.bold: pill.active
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component ActionButton: Rectangle {
        id: ab
        property string icon: ""
        property string label: ""
        property color accent: Theme.purple
        signal clicked
        implicitWidth: actionRow.implicitWidth + 24
        implicitHeight: 34
        radius: Theme.chip
        color: abma.containsMouse ? Theme.withAlpha(ab.accent, 0.22) : Theme.withAlpha(ab.accent, 0.12)
        border.color: ab.accent
        border.width: 1

        RowLayout {
            id: actionRow
            anchors.centerIn: parent
            spacing: 7

            MaterialIcon {
                visible: ab.icon.length > 0
                text: ab.icon
                color: ab.accent
                font.pixelSize: 17
                Layout.preferredWidth: 17
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                text: ab.label
                color: ab.accent
                font.family: Theme.fontMono
                font.pixelSize: 13
                font.bold: true
            }
        }

        MouseArea {
            id: abma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ab.clicked()
        }
    }

    // ---- seed the inputs once, and refill when the task changes --------------

    function seed(): void {
        if (!page.task)
            return;
        descInput.text = page.task.description || "";
        projInput.text = page.task.project || "";
        dueInput.text = page.task.due || "";
    }

    Component.onCompleted: page.seed()

    Connections {
        target: page
        function onTaskChanged() { page.seed(); }
    }

    // ---- layout --------------------------------------------------------------

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 36
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            x: 18
            y: 18
            width: page.width - 36
            spacing: 14

            // 1. top bar — back + id
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    implicitWidth: backRow.implicitWidth + 18
                    implicitHeight: 28
                    radius: Theme.pill
                    color: backMa.containsMouse ? Theme.hov : Theme.s1
                    border.color: Theme.bd
                    border.width: 1

                    RowLayout {
                        id: backRow
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialIcon {
                            text: "arrow_back"
                            color: Theme.subtext0
                            font.pixelSize: 16
                            Layout.preferredWidth: 16
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: "back"
                            color: Theme.subtext0
                            font.family: Theme.fontMono
                            font.pixelSize: 13
                        }
                    }

                    MouseArea {
                        id: backMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PanelState.go("tasks")
                    }
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: "#" + (page.task ? page.task.id : "")
                    color: Theme.comment
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            // 2. not found
            StyledText {
                visible: !page.task
                text: "task not found"
                color: Theme.red
                font.family: Theme.fontMono
                font.pixelSize: 14
            }

            // everything else only when a task exists
            ColumnLayout {
                visible: !!page.task
                Layout.fillWidth: true
                spacing: 14

                // 3. description
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    FieldLabel { text: "DESCRIPTION" }
                    InputBox {
                        id: descInput
                        placeholder: "what needs doing…"
                        onAccepted: function (value) {
                            if (page.task)
                                TaskActions.cmd(["modify", String(page.task.id), value]);
                        }
                    }
                }

                // 4. project
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    FieldLabel { text: "PROJECT" }
                    InputBox {
                        id: projInput
                        placeholder: "project name"
                        onAccepted: function (value) {
                            if (page.task)
                                TaskActions.setProject(page.task.id, value);
                        }
                    }
                }

                // 5. priority
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    FieldLabel { text: "PRIORITY" }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        PillButton {
                            label: "H"
                            accent: Theme.red
                            active: page.curPriority === "H"
                            onClicked: if (page.task) TaskActions.setPriority(page.task.id, "H")
                        }
                        PillButton {
                            label: "M"
                            accent: Theme.orange
                            active: page.curPriority === "M"
                            onClicked: if (page.task) TaskActions.setPriority(page.task.id, "M")
                        }
                        PillButton {
                            label: "L"
                            accent: Theme.cyan
                            active: page.curPriority === "L"
                            onClicked: if (page.task) TaskActions.setPriority(page.task.id, "L")
                        }
                        PillButton {
                            label: "None"
                            accent: Theme.comment
                            active: page.curPriority === ""
                            onClicked: if (page.task) TaskActions.setPriority(page.task.id, "")
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                // 6. due
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    FieldLabel { text: "DUE" }
                    InputBox {
                        id: dueInput
                        placeholder: "YYYY-MM-DD · tomorrow · friday · (empty to clear)"
                        onAccepted: function (value) {
                            if (page.task)
                                TaskActions.setDue(page.task.id, value);
                        }
                    }
                }

                // 7. tags
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    FieldLabel { text: "TAGS" }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: page.task ? (page.task.tags || []) : []
                            Rectangle {
                                id: chip
                                required property var modelData
                                implicitWidth: chipRow.implicitWidth + 18
                                implicitHeight: 26
                                radius: Theme.pill
                                color: chipMa.containsMouse ? Theme.withAlpha(Theme.pink, 0.2) : Theme.s1
                                border.color: Theme.bd
                                border.width: 1
                                RowLayout {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    StyledText {
                                        text: "#" + chip.modelData
                                        color: Theme.pink
                                        font.family: Theme.fontMono
                                        font.pixelSize: 12
                                    }
                                    StyledText {
                                        text: "✕"
                                        color: chipMa.containsMouse ? Theme.red : Theme.comment
                                        font.family: Theme.fontMono
                                        font.pixelSize: 11
                                    }
                                }
                                MouseArea {
                                    id: chipMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (page.task) TaskActions.removeTag(page.task.id, chip.modelData)
                                }
                            }
                        }
                    }
                    InputBox {
                        id: tagInput
                        Layout.preferredWidth: 200
                        Layout.maximumWidth: 200
                        placeholder: "+ tag"
                        onAccepted: function (value) {
                            const t = value.trim();
                            if (page.task && t.length)
                                TaskActions.addTag(page.task.id, t);
                            tagInput.text = "";
                        }
                    }
                }

                // 8. annotations
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    FieldLabel { text: "ANNOTATIONS" }
                    Repeater {
                        model: page.task
                            ? ((page.task.annotations || []).map(a => a.description))
                            : []
                        RowLayout {
                            id: noteRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialIcon {
                                text: "notes"
                                color: Theme.comment
                                font.pixelSize: 16
                                Layout.preferredWidth: 18
                                Layout.alignment: Qt.AlignTop
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: noteRow.modelData
                                color: Theme.subtext0
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    InputBox {
                        id: noteInput
                        placeholder: "+ note"
                        onAccepted: function (value) {
                            const t = value.trim();
                            if (page.task && t.length)
                                TaskActions.annotate(page.task.id, t);
                            noteInput.text = "";
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; implicitHeight: 1; color: Theme.bd }

                // 9. actions
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 10
                    ActionButton {
                        icon: "play_arrow"
                        label: "Start block"
                        accent: Theme.purple
                        onClicked: {
                            if (page.task) {
                                TaskActions.startBlock(String(page.task.id));
                                BarState.closePalette();
                            }
                        }
                    }
                    ActionButton {
                        icon: "check"
                        label: "Done"
                        accent: Theme.green
                        onClicked: {
                            if (page.task) {
                                TaskActions.done(page.task.id);
                                PanelState.go("tasks");
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    ActionButton {
                        icon: "delete"
                        label: "Delete"
                        accent: Theme.red
                        onClicked: {
                            if (page.task) {
                                TaskActions.remove(page.task.id);
                                PanelState.go("tasks");
                            }
                        }
                    }
                }
            }
        }
    }
}
