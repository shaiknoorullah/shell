import QtQuick
import QtQuick.Shapes

// A straight line from (x,y) to (x2,y2). `shape` is a model object; the item
// fills the drawing layer so coordinates are absolute canvas coordinates.
Shape {
    id: root

    property var shape: ({})

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    asynchronous: false

    ShapePath {
        strokeColor: root.shape.color ?? "#ff3b30"
        strokeWidth: root.shape.width ?? 4
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        startX: root.shape.x ?? 0
        startY: root.shape.y ?? 0

        PathLine {
            x: root.shape.x2 ?? 0
            y: root.shape.y2 ?? 0
        }
    }
}
