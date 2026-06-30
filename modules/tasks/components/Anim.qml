// NUMBER-ANIMATION PRESET  (pattern: caelestia components/Anim.qml)
//
// Caelestia routes ALL spatial animations through a single Anim component so
// duration/easing are consistent (a trimmed M3 motion system). Use it inside
// Behavior {} or as a Transition child. The full repo has an enum of 14 motion
// types; this minimal version exposes the two you need most.

import QtQuick

NumberAnimation {
    enum Type {
        Standard = 0,
        Emphasized
    }

    property int type: Anim.Standard

    duration: type === Anim.Emphasized ? 500 : 300
    easing.type: Easing.BezierSpline
    // M3 standard vs emphasized easing curves.
    easing.bezierCurve: type === Anim.Emphasized
        ? [0.05, 0, 0.13, 1, 0.31, 1, 0.5, 1, 0.69, 1, 0.87, 1, 1, 1, 1, 1]
        : [0.2, 0, 0, 1, 1, 1]
}
