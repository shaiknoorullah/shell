import QtQuick
import Caelestia.Config
import qs.components

// A committed text annotation, anchored at its top-left (x,y).
// Overrides the whole `font` (rather than the inherited token leaf) to avoid a
// binding conflict with StyledText's default `font: Tokens.font.body.small`.
StyledText {
    id: root

    property var shape: ({})

    x: root.shape.x ?? 0
    y: root.shape.y ?? 0
    text: root.shape.text ?? ""
    color: root.shape.color ?? "#ff3b30"
    textFormat: Text.PlainText
    font: Qt.font({
        family: Tokens.font.body.large.family,
        pixelSize: Math.max(14, (root.shape.width ?? 4) * 6),
        bold: true
    })
}
