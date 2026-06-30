// BASE TEXT  (pattern: caelestia components/StyledText.qml)
// Defaults to the theme on-surface colour; animates colour on theme change.
// Set `animate: true` to cross-fade on text changes (used for media titles).

import QtQuick
import qs.services

Text {
    id: root

    property bool animate: false

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: Colours.palette.m3onSurface

    Behavior on color {
        CAnim {}
    }

    Behavior on text {
        enabled: root.animate

        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 0
            }
            PropertyAction {}
            Anim {
                target: root
                property: "opacity"
                to: 1
            }
        }
    }
}
