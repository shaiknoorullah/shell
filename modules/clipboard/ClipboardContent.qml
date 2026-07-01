pragma ComponentBehavior: Bound

// v2 clipboard overlay content — a compact, scan-first popup.
//
// The LIST is the hero: no permanent preview pane (the v1 dead panel is gone),
// pins sort to the top (marked with 📌 by ClipEntry). Search is a thin line, not
// a bar. The type filter is cycled with Tab (shown as a small tag) instead of a
// chip row. Footer hints use a readable colour. Rich preview / edit / secret
// masking land in follow-up increments (see the clipboard-v2 plan).

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
    property bool peeking: false
    property bool peekRevealed: false

    readonly property var filters: ["all", "text", "image", "link"]

    readonly property var model: root.filterModel()
    readonly property int clampedIndex: Math.max(0, Math.min(index, model.length - 1))
    readonly property var current: model.length ? model[clampedIndex] : null

    // Pins first (deduped against history), then the rest of cliphist.
    function merged(): var {
        const pins = ClipPins.pins.map(p => ({
                    id: String(p.raw).split("\t")[0],
                    raw: p.raw,
                    preview: p.preview,
                    pinned: true,
                    section: "Pinned"
                }));
        const hist = Cliphist.entries.filter(e => !ClipPins.isPinned(e.raw)).map(e => ({
                    id: e.id,
                    raw: e.raw,
                    preview: e.preview,
                    pinned: false,
                    section: "Recent"
                }));
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

    function cycleFilter(dir: int): void {
        const i = root.filters.indexOf(root.filter);
        const n = root.filters.length;
        root.filter = root.filters[(i + dir + n) % n];
    }

    // Central key handling; plain characters keep flowing to the search field.
    function handleKey(event: var): void {
        const mod = event.modifiers;
        const ctrl = (mod & Qt.ControlModifier) !== 0;
        const shift = (mod & Qt.ShiftModifier) !== 0;
        const k = event.key;
        const n = root.model.length;

        if (k === Qt.Key_Escape) {
            if (root.peeking)
                root.peeking = false;
            else
                root.requestClose();
            event.accepted = true;
        } else if (k === Qt.Key_Space) {
            if (root.current) {
                root.peeking = !root.peeking;
                root.peekRevealed = false;
            }
            event.accepted = true;
        } else if (ctrl && k === Qt.Key_R) {
            if (root.peeking && root.current)
                root.peekRevealed = true;
            event.accepted = true;
        } else if (k === Qt.Key_Down || (ctrl && k === Qt.Key_J)) {
            root.index = Math.min(root.clampedIndex + 1, n - 1);
            event.accepted = true;
        } else if (k === Qt.Key_Up || (ctrl && k === Qt.Key_K)) {
            root.index = Math.max(root.clampedIndex - 1, 0);
            event.accepted = true;
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            if (root.current) {
                Cliphist.copy(root.current.raw);
                root.requestClose();
            }
            event.accepted = true;
        } else if (k === Qt.Key_Tab) {
            root.cycleFilter(1);
            event.accepted = true;
        } else if (k === Qt.Key_Backtab) {
            root.cycleFilter(-1);
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
        } else if (ctrl && k === Qt.Key_S) {
            if (root.current)
                ClipMeta.setMarked(root.current.raw, !ClipMeta.markedSensitive(root.current.raw));
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

    // No dim backdrop (it animated in awkwardly). Just an invisible click-catcher
    // so clicking outside the card still closes; the card itself is translucent +
    // compositor-blurred (frosted glass) via the caelestia-clipboard layer rule.
    MouseArea {
        anchors.fill: parent
        onClicked: root.requestClose()
    }

    StyledRect {
        id: card

        anchors.centerIn: parent
        width: Math.min(400, parent.width * 0.42)
        height: Math.min(470, parent.height * 0.64)
        radius: Tokens.rounding.large
        // Translucent so the compositor blur (Hyprland layer rule) shows through
        // as frosted glass.
        color: {
            const c = Colours.palette.m3surface;
            return Qt.rgba(c.r, c.g, c.b, 0.88);
        }

        // Swallow clicks so they don't fall through to the backdrop.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            // --- thin search line -----------------------------------------
            StyledRect {
                Layout.fillWidth: true
                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                radius: Tokens.rounding.full
                implicitHeight: search.implicitHeight + Tokens.padding.small * 2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.large
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "search"
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledTextField {
                        id: search

                        Layout.fillWidth: true
                        focus: true
                        placeholderText: qsTr("Search…")
                        onTextChanged: root.query = text
                        Component.onCompleted: forceActiveFocus()
                        Keys.onPressed: event => root.handleKey(event)
                    }

                    // active filter tag (Tab cycles it)
                    StyledText {
                        visible: root.filter !== "all"
                        text: root.filter
                        color: Colours.palette.m3primary
                        font: Tokens.font.mono.small
                    }

                    StyledText {
                        text: `${root.model.length}`
                        color: Colours.palette.m3outline
                        font: Tokens.font.mono.small
                    }
                }
            }

            // --- the list (hero) — full width, no preview pane -------------
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

            // --- footer: separator + shortcut pills -----------------------
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colours.palette.m3outlineVariant
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: [
                        { k: "↵", l: "copy" },
                        { k: "⌃P", l: "pin" },
                        { k: "⌃D", l: "del" },
                        { k: "⌃1-9", l: "quick" },
                        { k: "⇥", l: "filter" },
                        { k: "esc", l: "close" }
                    ]

                    StyledRect {
                        required property var modelData

                        radius: Tokens.rounding.small
                        color: Colours.palette.m3surfaceContainerHighest
                        implicitHeight: pill.implicitHeight + 4
                        implicitWidth: pill.implicitWidth + 12

                        Row {
                            id: pill

                            anchors.centerIn: parent
                            spacing: 5

                            StyledText {
                                text: modelData.k
                                font: Tokens.font.mono.small
                                color: Colours.palette.m3onSurface
                            }

                            StyledText {
                                text: modelData.l
                                font: Tokens.font.body.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }
        }
    }

    ClipPeek {
        visible: root.peeking
        entry: root.current
        revealed: root.peekRevealed
        onRequestClose: root.peeking = false
    }
}
