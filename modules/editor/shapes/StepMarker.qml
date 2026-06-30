import QtQuick
import qs.components
import qs.services

// A numbered circle centred on (x,y). `n` is assigned via editor.js nextStep().
Item {
    id: root

    property var shape: ({})

    readonly property real r: Math.max(14, (root.shape.width ?? 4) * 4)

    x: (root.shape.x ?? 0) - r
    y: (root.shape.y ?? 0) - r
    width: r * 2
    height: r * 2

    StyledRect {
        anchors.fill: parent
        radius: width / 2
        color: root.shape.color ?? Colours.palette.m3primary
    }

    StyledText {
        anchors.centerIn: parent
        text: root.shape.n ?? 1
        color: "#ffffff"
        font: Qt.font({ pixelSize: root.r, bold: true })
    }
}
