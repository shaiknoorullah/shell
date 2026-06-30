import QtQuick
import QtQuick.Shapes
import "../editor.js" as EditorLogic

// A line from (x,y)→(x2,y2) with a solid filled arrowhead at the tip.
// Head geometry comes from the node-tested editor.js arrowHead().
Shape {
    id: root

    property var shape: ({})

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    asynchronous: false

    readonly property real sw: root.shape.width ?? 4
    readonly property var head: EditorLogic.arrowHead(root.shape.x ?? 0, root.shape.y ?? 0, root.shape.x2 ?? 0, root.shape.y2 ?? 0, Math.max(12, root.sw * 4))

    // shaft
    ShapePath {
        strokeColor: root.shape.color ?? "#ff3b30"
        strokeWidth: root.sw
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

    // filled head triangle
    ShapePath {
        strokeColor: root.shape.color ?? "#ff3b30"
        strokeWidth: root.sw
        fillColor: root.shape.color ?? "#ff3b30"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        startX: root.head[0].x
        startY: root.head[0].y

        PathLine {
            x: root.head[1].x
            y: root.head[1].y
        }
        PathLine {
            x: root.head[2].x
            y: root.head[2].y
        }
        PathLine {
            x: root.head[0].x
            y: root.head[0].y
        }
    }
}
