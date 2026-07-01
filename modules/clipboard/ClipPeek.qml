pragma ComponentBehavior: Bound

// On-demand rich preview for the selected clipboard entry (Space toggles it in
// ClipboardContent). Shows the full decoded content — image as a fitted Image,
// text/code as scrollable wrapped text. Masked secrets stay hidden until ⌃r
// (revealed is driven by ClipboardContent). Keyboard is handled by the parent
// (search field keeps focus); this is display-only.

import QtQuick
import QtQuick.Controls
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
    // When true the read-only body is replaced by an editable field pre-filled
    // with the decoded content; ↵/⌃↵ copies the edited text, Esc cancels.
    property bool editing: false

    signal requestClose

    readonly property string type: entry ? Logic.detectType(entry.preview) : "text"
    readonly property bool sensitive: entry ? Logic.detectSensitive(entry.preview, "") : false
    property string content: ""
    property string imgPath: ""

    anchors.fill: parent

    onEntryChanged: root.load()
    Component.onCompleted: root.load()

    // Focus the edit field as soon as edit mode turns on. Pre-fill it with the
    // decoded content; if the decode hasn't finished yet, onContentChanged fills
    // it in when it arrives.
    onEditingChanged: {
        if (root.editing) {
            editField.text = root.content;
            Qt.callLater(() => editField.forceActiveFocus());
        }
    }

    // While editing, mirror late-arriving decoded content into the field until
    // the user starts typing (edit mode always starts from a fresh decode).
    onContentChanged: {
        if (root.editing && editField.text === "")
            editField.text = root.content;
    }

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

        // masked secret (until revealed) — hidden while editing (the edit field
        // shows the decoded content so it can be modified).
        StyledText {
            anchors.centerIn: parent
            visible: root.sensitive && !root.revealed && !root.editing
            horizontalAlignment: Text.AlignHCenter
            text: `${Logic.maskSecret(root.entry ? root.entry.preview : "")}\n\n⌃r to reveal`
            color: Colours.palette.m3onSurfaceVariant
        }

        // text / code (scrollable, wrapped) — read-only view
        Flickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            anchors.bottomMargin: Tokens.padding.large + 16
            visible: root.type !== "image" && (!root.sensitive || root.revealed) && !root.editing
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

        // edit-in-place — multiline editable field pre-filled with the decoded
        // content. ↵/⌃↵ copies the edited text and closes; Esc cancels.
        Flickable {
            id: editFlick

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            anchors.bottomMargin: Tokens.padding.large + 16
            visible: root.editing && root.type !== "image"
            contentWidth: width
            contentHeight: editField.implicitHeight
            clip: true

            TextArea.flickable: TextArea {
                id: editField

                width: editFlick.width
                wrapMode: TextEdit.Wrap
                color: Colours.palette.m3onSurface
                font: root.type === "code" ? Tokens.font.mono.small : Tokens.font.body.medium
                background: null
                selectByMouse: true

                // Intercept before the TextArea inserts a newline so ↵ confirms.
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => {
                    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        Cliphist.copyText(editField.text);
                        root.requestClose();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.requestClose();
                        event.accepted = true;
                    }
                }
            }

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: editFlick
            }
        }

        // footer hint
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.padding.small
            text: root.editing ? qsTr("↵ save · esc cancel") : (root.sensitive && !root.revealed ? qsTr("⌃r reveal · space/esc close") : qsTr("space / esc close"))
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }
    }
}
