import QtQuick
import qs.components

// An unfilled rectangle outline spanning (x,y)→(x2,y2) (order-independent).
Item {
    id: root

    property var shape: ({})

    anchors.fill: parent

    readonly property real rx: Math.min(root.shape.x ?? 0, root.shape.x2 ?? 0)
    readonly property real ry: Math.min(root.shape.y ?? 0, root.shape.y2 ?? 0)
    readonly property real rw: Math.abs((root.shape.x2 ?? 0) - (root.shape.x ?? 0))
    readonly property real rh: Math.abs((root.shape.y2 ?? 0) - (root.shape.y ?? 0))

    StyledRect {
        x: root.rx
        y: root.ry
        width: root.rw
        height: root.rh
        color: "transparent"
        radius: 2
        border.width: root.shape.width ?? 4
        border.color: root.shape.color ?? "#ff3b30"
    }
}
