// PROGRESS RING — thin circular arc (value 0..1) wrapping its content.
// Used to ring the collapsed album art with playback progress.

import QtQuick
import QtQuick.Shapes
import qs.services

Item {
    id: root

    property real value: 0
    property int ringWidth: 2
    property color color: Theme.ctxAccent
    property color track: Theme.withAlpha(Theme.fg, 0.15)
    default property alias content: holder.data

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.track
            strokeWidth: root.ringWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.ringWidth) / 2
                radiusY: (root.height - root.ringWidth) / 2
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.ringWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.ringWidth) / 2
                radiusY: (root.height - root.ringWidth) / 2
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, root.value))

                Behavior on sweepAngle {
                    NumberAnimation { duration: 400; easing.type: Easing.OutSine }
                }
            }
        }
    }

    Item {
        id: holder
        anchors.centerIn: parent
        width: parent.width - root.ringWidth * 2 - 2
        height: width
    }
}
