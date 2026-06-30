pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Floating top toolbar. Binds the active tool/colour/width to the ToolController
// and surfaces undo/redo/crop/export/cancel as signals for EditorCanvas/Editor.
StyledRect {
    id: root

    required property ToolController controller
    property bool canUndo: false
    property bool canRedo: false
    property bool hasCrop: false

    signal requestUndo
    signal requestRedo
    signal requestExport
    signal requestCancel
    signal requestClearCrop

    readonly property var tools: [
        { id: "select", icon: "arrow_selector_tool" },
        { id: "pen", icon: "draw" },
        { id: "line", icon: "pen_size_2" },
        { id: "arrow", icon: "north_east" },
        { id: "box", icon: "rectangle" },
        { id: "ellipse", icon: "circle" },
        { id: "highlight", icon: "ink_highlighter" },
        { id: "text", icon: "title" },
        { id: "blur", icon: "blur_on" },
        { id: "step", icon: "looks_one" },
        { id: "crop", icon: "crop" }
    ]
    readonly property var swatches: ["#ff3b30", "#ffcc00", "#34c759", "#0a84ff", "#000000", "#ffffff", Colours.palette.m3primary]

    implicitWidth: row.implicitWidth + Tokens.padding.large * 2
    implicitHeight: row.implicitHeight + Tokens.padding.small * 2
    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: root.tools

            IconButton {
                required property var modelData

                icon: modelData.icon
                type: IconButton.Text
                isToggle: true
                checked: root.controller.tool === modelData.id
                onClicked: root.controller.tool = modelData.id
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.topMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.padding.small
            implicitWidth: 1
            color: Colours.palette.m3outlineVariant
        }

        Repeater {
            model: root.swatches

            StyledRect {
                required property var modelData

                implicitWidth: 22
                implicitHeight: 22
                radius: width / 2
                color: modelData
                border.width: Qt.colorEqual(root.controller.color, modelData) ? 3 : 1
                border.color: Colours.palette.m3onSurface

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.controller.color = parent.color
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.topMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.padding.small
            implicitWidth: 1
            color: Colours.palette.m3outlineVariant
        }

        MaterialIcon {
            text: "line_weight"
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledSlider {
            id: widthSlider

            Layout.preferredWidth: 120
            from: 1
            to: 40
            value: root.controller.width
            onInteraction: v => root.controller.width = Math.round(widthSlider.from + v * (widthSlider.to - widthSlider.from))
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.topMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.padding.small
            implicitWidth: 1
            color: Colours.palette.m3outlineVariant
        }

        IconButton {
            icon: "crop_free"
            type: IconButton.Text
            disabled: !root.hasCrop
            onClicked: root.requestClearCrop()
        }
        IconButton {
            icon: "undo"
            type: IconButton.Text
            disabled: !root.canUndo
            onClicked: root.requestUndo()
        }
        IconButton {
            icon: "redo"
            type: IconButton.Text
            disabled: !root.canRedo
            onClicked: root.requestRedo()
        }
        IconButton {
            icon: "check"
            type: IconButton.Filled
            onClicked: root.requestExport()
        }
        IconButton {
            icon: "close"
            type: IconButton.Text
            onClicked: root.requestCancel()
        }
    }
}
