pragma ComponentBehavior: Bound

// Right-hand preview pane bound to the currently selected entry. Renders the full
// content by type: image (decoded to a temp file), colour (swatch + hex), or
// scrollable text/code. Footer shows the source app + capture time joined from
// ClipMeta via md5(decoded text).

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import "logic.js" as Logic

Item {
    id: root

    // The selected entry { id, raw, preview } or null.
    required property var entry

    readonly property string type: entry ? Logic.detectType(entry.preview) : "text"
    readonly property int maxChars: 100000
    readonly property int nowSeconds: Math.floor(Time.date.getTime() / 1000)
    readonly property var meta: fullText ? ClipMeta.lookup(Qt.md5(fullText)) : null

    property string fullText: ""
    property string imageSource: ""

    function update(): void {
        root.fullText = "";
        root.imageSource = "";
        if (!root.entry)
            return;
        if (root.type === "image")
            Cliphist.decodeImage(root.entry.raw, `/tmp/caelestia-clip-preview-${root.entry.id}.png`, p => root.imageSource = `file://${p}`);
        else
            Cliphist.decodeText(root.entry.raw, t => root.fullText = t);
    }

    onEntryChanged: root.update()
    Component.onCompleted: root.update()

    // --- image -------------------------------------------------------------
    Image {
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectFit
        visible: root.type === "image" && root.imageSource !== ""
        source: root.imageSource
    }

    MaterialIcon {
        anchors.centerIn: parent
        visible: root.type === "image" && root.imageSource === ""
        text: "image"
        color: Colours.palette.m3outline
        fontStyle: Tokens.font.icon.extraLarge
    }

    // --- colour ------------------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.type === "color"
        spacing: Tokens.spacing.medium

        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 120
            implicitHeight: 120
            radius: Tokens.rounding.large
            color: root.entry ? `#${root.entry.preview.trim().replace("#", "")}` : "transparent"
            border.width: 1
            border.color: Colours.palette.m3outlineVariant
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.entry?.preview ?? ""
            font: Tokens.font.mono.medium
        }
    }

    // --- text / code (scrollable) ------------------------------------------
    StyledFlickable {
        id: flick

        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        anchors.bottomMargin: footer.visible ? footer.implicitHeight + Tokens.spacing.small : Tokens.padding.small
        visible: root.type !== "image" && root.type !== "color"
        clip: true
        contentWidth: width
        contentHeight: previewText.implicitHeight

        StyledText {
            id: previewText

            width: flick.width
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            font: root.type === "code" ? Tokens.font.mono.small : Tokens.font.body.medium
            text: {
                if (!root.fullText)
                    return root.entry ? root.entry.preview : "";
                if (root.fullText.length > root.maxChars)
                    return root.fullText.slice(0, root.maxChars) + qsTr("\n\n… (truncated)");
                return root.fullText;
            }
        }

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: flick
        }
    }

    // --- footer: source app + relative time --------------------------------
    StyledText {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.small
        visible: root.meta !== null
        elide: Text.ElideRight
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
        text: root.meta ? `${root.meta.app} · ${Logic.relTime(root.meta.ts, root.nowSeconds)}` : ""
    }
}
