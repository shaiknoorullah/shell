pragma ComponentBehavior: Bound

// A single clipboard history row, rendered by type (image thumbnail, colour
// swatch, link/code/text icon). Used as the ClipList delegate. Emits activated()
// on click; ClipList wires that to copy + close.

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "logic.js" as Logic

Item {
    id: root

    required property var modelData
    required property int index

    readonly property string type: Logic.detectType(modelData.preview)
    readonly property bool pinned: ClipPins.isPinned(modelData.raw)
    readonly property bool current: ListView.isCurrentItem
    // Resolved lazily for image entries (cliphist decode -> /tmp thumbnail).
    property string thumb: ""
    // True when the entry looks like a secret (token/password/key). Masked in the
    // list (lock icon); ↵ still copies the real value (copy uses raw, not display).
    readonly property bool sensitive: Logic.detectSensitive(modelData.preview, "") || ClipMeta.markedSensitive(modelData.raw)
    readonly property string displayText: root.sensitive ? Logic.maskSecret(modelData.preview) : modelData.preview

    signal activated(int index)

    function iconName(t: string): string {
        if (t === "link")
            return "link";
        if (t === "code")
            return "code";
        if (t === "color")
            return "palette";
        return "content_paste";
    }

    implicitHeight: 40
    anchors.left: parent?.left
    anchors.right: parent?.right

    Component.onCompleted: {
        if (root.type === "image")
            Cliphist.decodeImage(modelData.raw, `/tmp/caelestia-clip-thumb-${modelData.id}.png`, p => root.thumb = `file://${p}`);
    }

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: root.activated(root.index)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.small
        anchors.rightMargin: Tokens.padding.small
        spacing: Tokens.spacing.small

        Item {
            id: indicator

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 28
            implicitHeight: 28

            StyledClippingRect {
                anchors.fill: parent
                radius: Tokens.rounding.small
                color: Colours.palette.m3surfaceContainerHighest
                visible: root.type === "image"

                Image {
                    anchors.fill: parent
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                    source: root.thumb
                    visible: root.thumb !== ""
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "image"
                    color: Colours.palette.m3onSurfaceVariant
                    visible: root.thumb === ""
                }
            }

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.small
                visible: root.type === "color"
                color: {
                    const hex = root.modelData.preview.trim().replace("#", "");
                    return `#${hex}`;
                }
                border.width: 1
                border.color: Colours.palette.m3outlineVariant
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: root.sensitive || (root.type !== "image" && root.type !== "color")
                text: root.sensitive ? "lock" : root.iconName(root.type)
                color: root.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: root.displayText
            elide: Text.ElideRight
            maximumLineCount: 1
            font: root.type === "code" && !root.sensitive ? Tokens.font.mono.small : Tokens.font.body.medium
            color: root.sensitive ? Colours.palette.m3outline : (root.current ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant)
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            visible: root.pinned
            text: "push_pin"
            fill: 1
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            visible: root.index < 9
            text: `⌃${root.index + 1}`
            color: Colours.palette.m3outline
            font: Tokens.font.mono.small
        }
    }
}
