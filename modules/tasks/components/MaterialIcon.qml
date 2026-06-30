// MATERIAL SYMBOLS ICON  (pattern: caelestia components/MaterialIcon.qml)
// Renders a Material Symbols glyph in a stable square box. Requires the
// "Material Symbols Rounded" font installed. `text` is the icon ligature name,
// e.g. "play_arrow".

import QtQuick
import QtQuick.Layouts
import qs.services

StyledText {
    id: root

    readonly property int boxSize: Math.ceil(font.pixelSize * 1.34)

    width: root.boxSize
    height: root.boxSize
    Layout.minimumWidth: root.boxSize
    Layout.minimumHeight: root.boxSize
    Layout.preferredWidth: root.boxSize
    Layout.preferredHeight: root.boxSize

    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    clip: false

    color: Colours.palette.m3onSurface
    font.family: Theme.fontIcon
    font.pixelSize: 20
    font.letterSpacing: 0
    font.wordSpacing: 0
}
