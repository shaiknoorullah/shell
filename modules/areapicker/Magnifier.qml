pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A circular loupe that follows the cursor during interactive region selection.
// It magnifies `source` (the picker's screencopy item) around the cursor and
// shows a live coordinate/size readout. Mounted by Picker.qml; positions itself
// near the cursor and flips to stay on-screen.
Item {
    id: root

    // The item to magnify (the picker's screencopy Loader). May be null while the
    // screencopy is inactive (non-freeze selection) — the loupe then just shows
    // its background + crosshair + the live coordinate readout.
    property Item source: null

    // Cursor position in the picker's (screen-local, logical) coordinate space.
    property real cursorX: 0
    property real cursorY: 0

    // Current selection rect (rsx/rsy/sw/sh from the picker) for the readout.
    property real regionX: 0
    property real regionY: 0
    property real regionW: 0
    property real regionH: 0

    // Screen size, so the loupe can flip to the other side near an edge.
    property int screenWidth: 0
    property int screenHeight: 0

    property int diameter: 140
    property real zoom: 6
    readonly property real sampleSize: diameter / zoom
    readonly property int gap: 24

    implicitWidth: diameter
    implicitHeight: diameter + Tokens.padding.small + labelPill.implicitHeight

    // Keep the loupe near the cursor but flip sides/edges so it never leaves the screen.
    x: cursorX + gap + width <= screenWidth ? cursorX + gap : Math.max(0, cursorX - gap - width)
    y: cursorY + gap + height <= screenHeight ? cursorY + gap : Math.max(0, cursorY - gap - height)

    StyledClippingRect {
        id: loupe

        x: (root.width - root.diameter) / 2
        y: 0
        implicitWidth: root.diameter
        implicitHeight: root.diameter
        radius: root.diameter / 2
        color: Colours.palette.m3surfaceContainer

        ShaderEffectSource {
            id: zoomed

            anchors.fill: parent
            sourceItem: root.source
            sourceRect: Qt.rect(root.cursorX - root.sampleSize / 2, root.cursorY - root.sampleSize / 2, root.sampleSize, root.sampleSize)
            live: true
            hideSource: false
            smooth: false // nearest-neighbour: crisp pixels when zoomed
            visible: root.source !== null
        }

        // Crosshair (clipped to the circle).
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Qt.alpha(Colours.palette.m3primary, 0.6)
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 1
            height: parent.height
            color: Qt.alpha(Colours.palette.m3primary, 0.6)
        }

        // Centre pixel marker — outlines the exact pixel under the cursor.
        Rectangle {
            anchors.centerIn: parent
            width: root.zoom
            height: root.zoom
            color: "transparent"
            border.width: 1
            border.color: Colours.palette.m3primary
        }
    }

    // Ring around the loupe.
    Rectangle {
        anchors.fill: loupe
        radius: root.diameter / 2
        color: "transparent"
        border.width: 3
        border.color: Colours.palette.m3primary
    }

    // Live coordinate / size readout below the loupe.
    StyledRect {
        id: labelPill

        anchors.horizontalCenter: loupe.horizontalCenter
        anchors.top: loupe.bottom
        anchors.topMargin: Tokens.padding.small

        implicitWidth: label.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: label.implicitHeight + Tokens.padding.extraSmall * 2
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHigh

        StyledText {
            id: label

            anchors.centerIn: parent
            font: Tokens.font.mono.small
            color: Colours.palette.m3onSurface
            text: `${Math.round(root.cursorX)},${Math.round(root.cursorY)}  ${Math.round(root.regionW)}×${Math.round(root.regionH)}`
        }
    }
}
