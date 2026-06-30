import QtQuick

// A redaction region: pixelates the underlying base image inside (x,y)→(x2,y2).
// Implemented with a downsampled ShaderEffectSource (no custom GLSL) so it is
// robust under nixGL and irreversible-looking. `sourceItem` is the base Image,
// injected by EditorCanvas so the source never includes the annotations.
Item {
    id: root

    property var shape: ({})
    property Item sourceItem: null

    readonly property real rx: Math.min(root.shape.x ?? 0, root.shape.x2 ?? 0)
    readonly property real ry: Math.min(root.shape.y ?? 0, root.shape.y2 ?? 0)
    readonly property real rw: Math.abs((root.shape.x2 ?? 0) - (root.shape.x ?? 0))
    readonly property real rh: Math.abs((root.shape.y2 ?? 0) - (root.shape.y ?? 0))

    x: rx
    y: ry
    width: rw
    height: rh
    clip: true
    visible: rw > 1 && rh > 1 && sourceItem !== null

    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: root.sourceItem
        sourceRect: Qt.rect(root.rx, root.ry, root.rw, root.rh)
        // Capture the region at ~1/14 resolution then stretch back up with
        // smoothing off → blocky mosaic redaction.
        textureSize: Qt.size(Math.max(1, Math.round(root.rw / 14)), Math.max(1, Math.round(root.rh / 14)))
        smooth: false
        live: true
        recursive: false
        hideSource: false
    }
}
