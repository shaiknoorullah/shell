import QtQuick
import QtQuick.Shapes

// A wide, semi-transparent freehand stroke over `points` — a highlighter.
// (The stored model colour is opaque; the ~0.35 alpha + min width is applied at
// render time so it reads as a highlighter without mutating the model.)
Shape {
    id: root

    property var shape: ({})

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    asynchronous: false

    readonly property var polyPath: (root.shape.points ?? []).map(p => Qt.point(p.x, p.y))

    ShapePath {
        strokeColor: Qt.alpha(root.shape.color ?? "#ffcc00", 0.35)
        strokeWidth: Math.max(root.shape.width ?? 16, 16)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        PathPolyline {
            path: root.polyPath
        }
    }
}
