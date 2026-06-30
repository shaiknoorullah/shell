pragma ComponentBehavior: Bound

// SUMMONED LEFT BAR  (mockup #left — "What are you chasing?")
// (window pattern: caelestia StyledWindow / PanelWindow + WlrLayershell; the
//  slide-in mirrors caelestia's drawer panels that translate in from an edge.)
//
// A layer-shell panel pinned to the LEFT edge, HIDDEN by default. When summoned
// (BarState.leftOpen — flipped by a Hyprland keybind via `qs ipc call leftbar
// toggle`, or click-away) the inner glass panel SLIDES IN from the left and
// fades up, exactly like the mockup:
//   #left{ transform:translateX(-470px); opacity:0;
//          transition:transform .42s var(--ease), opacity .42s var(--ease) }
//   body.state-left #left{ transform:translateX(0); opacity:1 }
//
// Layout, top → bottom (mockup order):
//   1. header     — "What are you chasing?" + "one block · one outcome",
//                   right-side date + "ʿAsr in 48m" runway          (Time/Salah)
//   2. BIG TIMER  — the live block clock (from adhd-focus.sh status + the live
//                   HH:MM:SS from ActiveTask.elapsed), task label, salah runway,
//                   progress to the next prayer                     (Focus/ActiveTask/Salah)
//   3. salah strip— Fajr Dhuhr ʿAsr Maghrib Isha with done/next state  (Salah)
//   4. agent card — "Ask anything" stub + model chips (Gemini/Claude/local)
//   5. now·next   — active + next pending tasks                    (Tasks)
//
// The whole window only accepts input while open (it covers a slab of the left
// screen). A full-window click-away closes it.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.tasks.components
import qs.services
import Quickshell.Hyprland

PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData
    color: "transparent"

    // Summoned drawer: no surface at all unless opened (else it covers windows).
    visible: BarState.leftOpen

    // Bindings don't update while the window is hidden, so on open force the
    // data services to re-poll → the BIG timer/task reflect the live block at once.
    onVisibleChanged: if (visible) {
        ActiveTask.refresh();
        Focus.refresh();
        Tasks.refresh();
    }

    // Start a focus block on a task id (or "new:<description>" to quick-add) by
    // writing a request the HOST actuator (adhd-block.path → adhd-block-exec.sh)
    // picks up — the in-shell replacement for the rofi launcher. The request is
    // passed as a positional arg ($1), never interpolated, so it's injection-safe.
    Process { id: startProc }
    function startBlock(req: string): void {
        startProc.command = ["sh", "-c",
            "printf '%s' \"$1\" > \"$HOME/.cache/adhd/start-request\"", "sh", req];
        startProc.running = true;
        BarState.closeLeft();
    }

    WlrLayershell.namespace: "quickshell-leftbar"
    // Above normal windows so it reads as an overlay drawer.
    WlrLayershell.layer: WlrLayer.Overlay
    // Take keyboard only while open (for the future "ask anything" field).
    WlrLayershell.keyboardFocus: BarState.leftOpen
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Stretch the full left edge so the slab + click-away have room.
    anchors.top: true
    anchors.left: true
    anchors.bottom: true
    implicitWidth: panelWidth + clickAwayWidth
    exclusiveZone: 0

    readonly property int panelWidth: 430
    readonly property int margin: 12
    // While open, also accept clicks in the area to the right of the panel so a
    // click-away can dismiss it. While closed the window passes input through.
    readonly property int clickAwayWidth: BarState.leftOpen ? 600 : 0

    // Pass-through when closed: no input mask means clicks fall to windows below.
    mask: Region {
        item: BarState.leftOpen ? hit : null
    }

    // Click-away catcher (covers panel + the slab to its right while open).
    Item {
        id: hit
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            // Clicking anywhere NOT on the panel closes the drawer.
            onClicked: BarState.closeLeft()
        }
    }

    // ── The sliding glass panel ────────────────────────────────────────
    StyledRect {
        id: panel

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.topMargin: 46
        anchors.bottomMargin: 42
        anchors.leftMargin: root.margin
        width: root.panelWidth

        radius: Theme.rad
        color: Theme.panelStrong
        border.width: 1
        border.color: Theme.edge
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Theme.shine }
                GradientStop { position: 0.22; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.shade }
            }
        }

        // Eat clicks on the panel so they don't bubble to the click-away.
        MouseArea {
            anchors.fill: parent
            onClicked: {} // swallow
        }

        // Slide-in + fade (mockup translateX(-470)->0, opacity 0->1, .42s ease).
        opacity: BarState.leftOpen ? 1 : 0
        transform: Translate {
            x: BarState.leftOpen ? 0 : -(root.panelWidth + 40)
            Behavior on x {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.25, 1, 0.5, 1, 1, 1]
                }
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 11

            // ── 1. Header ─────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    StyledText {
                        text: "What are you chasing?"
                        color: Theme.fg
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                        font.bold: true
                    }
                    StyledText {
                        text: "one block · one outcome"
                        color: Theme.comment
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                    }
                }

                ColumnLayout {
                    spacing: 2
                    StyledText {
                        text: Time.format("ddd · h:mm")
                        color: Theme.comment
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight
                    }
                    StyledText {
                        text: Salah.nextPrayer
                            ? `${Salah.nextPrayer.display} at ${Salah.nextPrayer.time}`
                            : ""
                        color: Theme.comment
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }

            // ── 2. BIG TIMER card ─────────────────────────────────────
            Card {
                title: "deep block"
                titleRight: Salah.nextPrayer
                    ? `→ ${Salah.nextPrayer.display} ${Salah.nextPrayer.time}` : ""
                fill: Theme.withAlpha(Theme.purple, 0.10)
                accentBorder: Theme.withAlpha(Theme.purple, 0.35)

                // Big live clock — HH:MM:SS straight from the timewarrior-backed
                // ActiveTask.elapsed. Counts UP (Flowtime), never down.
                StyledText {
                    Layout.topMargin: 2
                    Layout.fillWidth: true
                    text: ActiveTask.active ? ActiveTask.elapsed : "00:00:00"
                    color: Theme.fg
                    font.family: Theme.fontMono
                    font.pixelSize: 48
                    minimumPixelSize: 34
                    fontSizeMode: Text.Fit
                    font.bold: true
                    font.letterSpacing: 0
                }

                // What the block is for (the active task).
                StyledText {
                    text: ActiveTask.task
                    color: Theme.purple
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Runway line — calm, gentle-nudge framing (no hard deadline).
                StyledText {
                    text: Focus.running
                        ? `${Focus.blockMinutes}m in · gentle nudge at 90m`
                        : "idle · start a block when you're ready"
                    color: Theme.comment
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }

                ProgressBar {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    // % of a 90-minute soft block elapsed (cap at 100, calm fill).
                    value: Math.min(100, Focus.blockMinutes / 90 * 100)
                }
            }

            // ── 3. Salah strip ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Salah.prayers

                    StyledRect {
                        id: chip
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 26
                        radius: Theme.chip
                        color: modelData.state === "done"
                            ? Theme.withAlpha(Theme.green, 0.12)
                            : modelData.state === "next"
                                ? Theme.withAlpha(Theme.purple, 0.18)
                                : Theme.s1
                        border.width: 1
                        border.color: modelData.state === "next"
                            ? Theme.withAlpha(Theme.purple, 0.35) : "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            text: chip.modelData.display
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.bold: chip.modelData.state === "next"
                            color: chip.modelData.state === "done"
                                ? Theme.green
                                : chip.modelData.state === "next"
                                    ? Theme.purple : Theme.comment
                        }
                    }
                }

                // Fallback when the conf hasn't been read yet.
                StyledText {
                    visible: Salah.prayers.length === 0
                    text: "prayer times loading…"
                    color: Theme.comment
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                }
            }

            // ── 4. Agent card ("ask anything" stub) ───────────────────
            Card {
                title: "master agent"
                titleRight: "full context"
                fill: Theme.withAlpha(Theme.cyan, 0.10)
                accentBorder: Theme.withAlpha(Theme.cyan, 0.28)

                // The "ask" input stub — a focusable pill. This is a STUB: it
                // captures text and, on Enter, will hand off to an agent runner
                // (left as a TODO — no agent backend is wired yet).
                StyledRect {
                    Layout.fillWidth: true
                    Layout.topMargin: 3
                    implicitHeight: 36
                    radius: Theme.pill
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.bd

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 13
                        spacing: 9

                        TextInput {
                            id: ask
                            Layout.fillWidth: true
                            color: Theme.fg
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter
                            // Placeholder shown when empty.
                            property string placeholder: "Ask anything — \"summarize my open PRs\""
                            onAccepted: {
                                // STUB: hand the query to an agent runner here.
                                // e.g. Quickshell.execDetached(["adhd-agent.sh", text])
                                text = "";
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: ask.text.length === 0
                                text: ask.placeholder
                                color: Theme.comment
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                            }
                        }
                    }
                }

                // Model chips — which backend the ask routes to (cosmetic stub).
                RowLayout {
                    Layout.topMargin: 2
                    spacing: 6
                    Repeater {
                        model: [
                            { label: " Gemini 2.5", on: true },
                            { label: " Claude", on: false },
                            { label: "local", on: false },
                            { label: "NotebookLM", on: false }
                        ]
                        StyledRect {
                            required property var modelData
                            implicitWidth: chipText.implicitWidth + 18
                            implicitHeight: 22
                            radius: Theme.pill
                            color: modelData.on
                                ? Theme.withAlpha(Theme.cyan, 0.16) : Theme.s1
                            StyledText {
                                id: chipText
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.bold: parent.modelData.on
                                color: parent.modelData.on ? Theme.cyan : Theme.comment
                            }
                        }
                    }
                }
            }

            // ── 5. now · next tasks ───────────────────────────────────
            Card {
                title: "now · next"

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 0

                    // Quick-add: type a task + Enter → create it (+today) and start
                    // a block, no rofi. Routed through the host actuator.
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        implicitHeight: 30
                        radius: 9
                        color: Theme.s2
                        border.width: 1
                        border.color: addInput.activeFocus ? Theme.purple : Theme.bd

                        TextInput {
                            id: addInput
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                            clip: true
                            selectByMouse: true
                            onAccepted: {
                                const t = text.trim();
                                if (t.length > 0) {
                                    root.startBlock("new:" + t);
                                    text = "";
                                }
                            }
                        }
                        StyledText {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: addInput.text.length === 0 && !addInput.activeFocus
                            text: "+ start a block — type a task, Enter"
                            color: Theme.comment
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                        }
                    }

                    Repeater {
                        model: Tasks.items

                        StyledRect {
                            id: taskRow
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: 9
                            color: modelData.active
                                ? Theme.withAlpha(Theme.purple, 0.12) : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 10

                                // active = play circle; pending = unchecked circle
                                MaterialIcon {
                                    text: taskRow.modelData.active ? "play_circle" : "radio_button_unchecked"
                                    color: taskRow.modelData.active
                                        ? Theme.purple : Theme.comment
                                    font.pixelSize: 17
                                    Layout.preferredWidth: 18
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: taskRow.modelData.description
                                    color: taskRow.modelData.active ? Theme.fg : Theme.subtext0
                                    font.family: Theme.fontMono
                                    font.pixelSize: 12
                                    font.bold: taskRow.modelData.active
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    text: taskRow.modelData.active
                                        ? ActiveTask.elapsed.replace(/:\d\d$/, "")
                                        : (taskRow.modelData.project || "")
                                    color: Theme.comment
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                }
                            }

                            // Click a task to open a deep-focus block on it.
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.startBlock(String(taskRow.modelData.id))
                            }
                        }
                    }

                    StyledText {
                        visible: Tasks.items.length === 0
                        text: "no pending tasks — clear runway"
                        color: Theme.comment
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                    }
                }
            }

            // Push everything up; the panel breathes at the bottom.
            Item { Layout.fillHeight: true }
        }
    }
}
