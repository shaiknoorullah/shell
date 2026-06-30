// CARD — the rounded glass panel used throughout the LEFT bar (mockup .card)
// (pattern: caelestia StyledRect wrappers — a themed Rectangle with a slot)
//
// Default surface mirrors mockup .card { background:--s1; border:--bd; radius:14;
// padding:13 14 }. The `accent`/`gradientTop` props let the special cards
// (timer / agent) tint themselves: the timer card is a purple-tinted gradient
// with an accent border, the agent card a cyan one. Children go in `content`.

import QtQuick
import QtQuick.Layouts
import qs.modules.tasks.components
import qs.services

StyledRect {
    id: root

    default property alias content: col.data
    property string title: ""
    property string titleRight: ""
    property color accentBorder: Theme.bd
    property color fill: Theme.s1

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 26
    radius: 14
    color: fill
    border.width: 1
    border.color: accentBorder
    clip: true

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Theme.withAlpha(Theme.fg, 0.035) }
            GradientStop { position: 0.55; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.withAlpha("#000000", 0.08) }
        }
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: 13
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 9

        // Section title row (mockup .ct — uppercase tracked label + right hint).
        RowLayout {
            Layout.fillWidth: true
            visible: root.title.length > 0

            StyledText {
                text: root.title.toUpperCase()
                color: Theme.comment
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.letterSpacing: 0
                Layout.fillWidth: true
            }
            StyledText {
                text: root.titleRight
                color: Theme.comment
                font.family: Theme.fontMono
                font.pixelSize: 10
                visible: root.titleRight.length > 0
            }
        }
    }
}
