pragma ComponentBehavior: Bound

// On-demand rich preview for the selected clipboard entry (Space toggles it in
// ClipboardContent). Shows the full decoded content — image as a fitted Image,
// text/code as scrollable wrapped text. Masked secrets stay hidden until ⌃r
// (revealed is driven by ClipboardContent). Keyboard is handled by the parent
// (search field keeps focus); this is display-only.

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import "logic.js" as Logic

Item {
    id: root

    required property var entry
    property bool revealed: false

    signal requestClose

    readonly property string type: entry ? Logic.detectType(entry.preview) : "text"
    readonly property bool sensitive: entry ? Logic.detectSensitive(entry.preview, "") : false
    property string content: ""
    property string imgPath: ""

    anchors.fill: parent

    onEntryChanged: root.load()
    Component.onCompleted: root.load()

    function load(): void {
        root.content = "";
        root.imgPath = "";
        if (!root.entry)
            return;
        if (root.type === "image")
            Cliphist.decodeImage(root.entry.raw, `/tmp/caelestia-clip-peek-${root.entry.id}.png`, p => root.imgPath = `file://${p}`);
        else
            Cliphist.decodeText(root.entry.raw, t => root.content = t);
    }

    // dim + click-to-close
    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: 0.5

        MouseArea {
            anchors.fill: parent
            onClicked: root.requestClose()
        }
    }

    StyledRect {
        anchors.centerIn: parent
        width: Math.min(700, parent.width * 0.72)
        height: Math.min(500, parent.height * 0.72)
        radius: Tokens.rounding.large
        color: {
            const c = Colours.palette.m3surface;
            return Qt.rgba(c.r, c.g, c.b, 0.96);
        }

        MouseArea {
            anchors.fill: parent
        }

        // image
        Image {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            visible: root.type === "image" && root.imgPath !== ""
            source: root.imgPath
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
        }

        // masked secret (until revealed)
        StyledText {
            anchors.centerIn: parent
            visible: root.sensitive && !root.revealed
            horizontalAlignment: Text.AlignHCenter
            text: `${Logic.maskSecret(root.entry ? root.entry.preview : "")}\n\n⌃r to reveal`
            color: Colours.palette.m3onSurfaceVariant
        }

        // text / code (scrollable, wrapped)
        Flickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            anchors.bottomMargin: Tokens.padding.large + 16
            visible: root.type !== "image" && (!root.sensitive || root.revealed)
            contentWidth: width
            contentHeight: body.implicitHeight
            clip: true

            StyledText {
                id: body

                width: flick.width
                wrapMode: Text.Wrap
                text: root.content
                font: root.type === "code" ? Tokens.font.mono.small : Tokens.font.body.medium
                color: Colours.palette.m3onSurface
            }

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: flick
            }
        }

        // footer hint
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.padding.small
            text: root.sensitive && !root.revealed ? qsTr("⌃r reveal · space/esc close") : qsTr("space / esc close")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }
    }
}
