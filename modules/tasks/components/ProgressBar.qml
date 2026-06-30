// PROGRESS BAR — a thin rounded fill bar (mockup .prog / .fbar / .full .trk)
// (pattern: caelestia StyledRect + a clipped fill child with an Anim on width)
//
// A muted track with a gradient fill from `from`->`to`, width = value%. Used by
// the LEFT bar's big-timer card. Calm: the fill width animates with the shared
// settle-in easing rather than snapping.

import QtQuick
import qs.modules.tasks.components
import qs.services

StyledRect {
    id: root

    property real value: 0           // 0..100
    property color from: Theme.purple
    property color to: Theme.pink
    property color track: Theme.s2

    implicitHeight: 5
    radius: height / 2
    color: track
    clip: true

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0, Math.min(1, root.value / 100))
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.from }
            GradientStop { position: 1; color: root.to }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.durBase
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.25, 1, 0.5, 1, 1, 1]
            }
        }
    }
}
