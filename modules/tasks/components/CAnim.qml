// COLOR-ANIMATION PRESET  (pattern: caelestia components/CAnim.qml)
// Used by StyledRect / StyledText so every colour change cross-fades smoothly
// when the theme switches.

import QtQuick

ColorAnimation {
    duration: 500
    easing.type: Easing.OutCubic
}
