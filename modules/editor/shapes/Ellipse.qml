import QtQuick
import QtQuick.Shapes

// An unfilled ellipse inscribed in the bounding box (x,y)→(x2,y2).
Shape {
    id: root

    property var shape: ({})

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    asynchronous: false

    readonly property real cx: ((root.shape.x ?? 0) + (root.shape.x2 ?? 0)) / 2
    readonly property real cy: ((root.shape.y ?? 0) + (root.shape.y2 ?? 0)) / 2
    readonly property real rx: Math.abs((root.shape.x2 ?? 0) - (root.shape.x ?? 0)) / 2
    readonly property real ry: Math.abs((root.shape.y2 ?? 0) - (root.shape.y ?? 0)) / 2

    ShapePath {
        strokeColor: root.shape.color ?? "#ff3b30"
        strokeWidth: root.shape.width ?? 4
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap

        PathAngleArc {
            centerX: root.cx
            centerY: root.cy
            radiusX: root.rx
            radiusY: root.ry
            startAngle: 0
            sweepAngle: 360
            moveToStart: true
        }
    }
}
