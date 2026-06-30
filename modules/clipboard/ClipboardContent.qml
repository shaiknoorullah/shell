pragma ComponentBehavior: Bound

// The clipboard overlay's content: a centred card with a fuzzy search field,
// type-filter chips, the entry list (left) and a live preview (right). The search
// field owns keyboard focus; plain typing filters, while modified keys drive
// navigation and actions (copy / pin / delete / wipe / quick-pick / open-link).
//
// Mounted per-screen by modules/utils/Overlay.qml via Clipboard.qml.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import "logic.js" as Logic

Item {
    id: root

    signal requestClose

    property string query: ""
    property string filter: "all"
    property int index: 0

    // Reactive model: re-evaluates when query/filter/Cliphist.entries/ClipPins.pins
    // change (all read during evaluation, so QML tracks them as dependencies).
    readonly property var model: root.filterModel()
    readonly property int clampedIndex: Math.max(0, Math.min(index, model.length - 1))
    readonly property var current: model.length ? model[clampedIndex] : null

    // Pins first (deduped against history), then the rest of cliphist.
    function merged(): var {
        const pins = ClipPins.pins.map(p => ({
                    id: String(p.raw).split("\t")[0],
                    raw: p.raw,
                    preview: p.preview,
                    pinned: true
                }));
        const hist = Cliphist.entries.filter(e => !ClipPins.isPinned(e.raw));
        return pins.concat(hist);
    }

    function filterModel(): var {
        let m = root.merged();
        if (root.filter !== "all")
            m = m.filter(e => {
                const t = Logic.detectType(e.preview);
                return root.filter === t || (root.filter === "text" && t === "code");
            });
        return Logic.fuzzy(root.query, m, e => e.preview);
    }

    // Centralised key handling so plain characters keep flowing to the search field
    // (we only accept the events we actually handle).
    function handleKey(event: var): void {
        const mod = event.modifiers;
        const ctrl = (mod & Qt.ControlModifier) !== 0;
        const shift = (mod & Qt.ShiftModifier) !== 0;
        const k = event.key;
        const n = root.model.length;

        if (k === Qt.Key_Escape) {
            root.requestClose();
            event.accepted = true;
        } else if (k === Qt.Key_Down) {
            root.index = Math.min(root.clampedIndex + 1, n - 1);
            event.accepted = true;
        } else if (k === Qt.Key_Up) {
            root.index = Math.max(root.clampedIndex - 1, 0);
            event.accepted = true;
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            // Shift+Return = paste-as-plain; cliphist stores text already, so v1
            // behaves like a normal copy (documented limitation).
            if (root.current) {
                Cliphist.copy(root.current.raw);
                root.requestClose();
            }
            event.accepted = true;
        } else if (ctrl && shift && k === Qt.Key_Delete) {
            Cliphist.wipe();
            event.accepted = true;
        } else if (ctrl && (k === Qt.Key_D || k === Qt.Key_Delete)) {
            if (root.current)
                Cliphist.remove(root.current.raw);
            event.accepted = true;
        } else if (ctrl && k === Qt.Key_P) {
            if (root.current)
                ClipPins.toggle(root.current.raw, root.current.preview);
            event.accepted = true;
        } else if (ctrl && k === Qt.Key_O) {
            if (root.current && Logic.detectType(root.current.preview) === "link")
                Quickshell.execDetached(["xdg-open", root.current.preview.trim()]);
            event.accepted = true;
        } else if (ctrl && k >= Qt.Key_1 && k <= Qt.Key_9) {
            const i = k - Qt.Key_1;
            if (i < n) {
                Cliphist.copy(root.model[i].raw);
                root.requestClose();
            }
            event.accepted = true;
        }
    }

    onQueryChanged: root.index = 0
    onFilterChanged: root.index = 0

    anchors.fill: parent

    // Dim backdrop; clicking outside the card closes the overlay.
    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: 0.4

        MouseArea {
            anchors.fill: parent
            onClicked: root.requestClose()
        }
    }

    StyledRect {
        id: card

        anchors.centerIn: parent
        width: Math.min(1000, parent.width * 0.75)
        height: Math.min(680, parent.height * 0.8)
        radius: Tokens.rounding.large
        color: Colours.palette.m3surface

        // Swallow clicks so they don't fall through to the backdrop.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            // --- search --------------------------------------------------
            StyledRect {
                Layout.fillWidth: true
                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                radius: Tokens.rounding.full
                implicitHeight: Math.max(searchIcon.implicitHeight, search.implicitHeight) + Tokens.padding.small * 2

                MaterialIcon {
                    id: searchIcon

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.padding.large
                    text: "content_paste_search"
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledTextField {
                    id: search

                    anchors.left: searchIcon.right
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.spacing.small
                    anchors.rightMargin: Tokens.padding.large

                    focus: true
                    placeholderText: qsTr("Search clipboard…")
                    onTextChanged: root.query = text
                    Component.onCompleted: forceActiveFocus()
                    Keys.onPressed: event => root.handleKey(event)
                }
            }

            // --- filter chips --------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: ["all", "text", "image", "link"]

                    TextButton {
                        required property string modelData

                        type: TextButton.Tonal
                        checked: root.filter === modelData
                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        onClicked: root.filter = modelData
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: `${root.model.length}`
                    color: Colours.palette.m3outline
                    font: Tokens.font.mono.small
                }
            }

            // --- list + preview ------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.medium

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ClipList {
                        id: list

                        anchors.fill: parent
                        entries: root.model
                        currentIndex: root.clampedIndex
                        onActivated: i => {
                            root.index = i;
                            if (root.model[i])
                                Cliphist.copy(root.model[i].raw);
                            root.requestClose();
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: root.model.length === 0
                        text: qsTr("No clipboard entries")
                        color: Colours.palette.m3outline
                    }
                }

                StyledRect {
                    Layout.preferredWidth: Math.round(card.width * 0.4)
                    Layout.fillHeight: true
                    radius: Tokens.rounding.large
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)

                    ClipPreview {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.small
                        entry: root.current
                    }
                }
            }

            // --- footer hint ---------------------------------------------
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
                text: qsTr("↵ copy   ⌃P pin   ⌃D delete   ⌃O open link   ⌃1–9 quick-pick   ⌃⇧⌫ wipe   esc close")
            }
        }
    }
}
