// BASE RECT  (pattern: caelestia components/StyledRect.qml)
// A Rectangle that animates its colour automatically. Use this instead of a
// raw Rectangle so theme changes cross-fade.

import QtQuick

Rectangle {
    color: "transparent"

    Behavior on color {
        CAnim {}
    }
}
