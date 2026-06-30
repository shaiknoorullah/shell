pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.misc
import qs.services

// A centered, keyboard-first menu to choose a screenshot mode. Opened with
// `caelestia-shell ipc call modepicker open` (bound to Super+Print). Each entry
// dispatches the matching `picker` IPC call, so this module stays decoupled from
// AreaPicker. Built on the same Scope/LazyLoader/Variants/StyledWindow overlay
// pattern as AreaPicker.qml.
//
// NOTE: This is intentionally self-contained rather than built on the (separately
// owned) modules/utils/Overlay.qml primitive, which does not exist yet — see the
// phase handoff. It can be refactored onto that primitive once it lands.
Scope {
    id: scope

    LazyLoader {
        id: root

        property bool closing
        property int selectedIndex: 0

        readonly property var modes: [
            {
                icon: "crop_free",
                label: "Region",
                fn: "open"
            },
            {
                icon: "crop_square",
                label: "Window",
                fn: "open"
            },
            {
                icon: "fullscreen",
                label: "Fullscreen",
                fn: "openFullscreen"
            },
            {
                icon: "ac_unit",
                label: "Freeze",
                fn: "openFreeze"
            }
        ]

        function move(delta: int): void {
            const n = modes.length;
            selectedIndex = (selectedIndex + delta + n) % n;
        }

        function activate(): void {
            const mode = modes[selectedIndex];
            Quickshell.execDetached(["caelestia-shell", "ipc", "call", "picker", mode.fn]);
            root.closing = true;
            closeTimer.restart();
        }

        function dismiss(): void {
            root.closing = true;
            closeTimer.restart();
        }

        Variants {
            model: Screens.screens

            StyledWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                name: "screenshot-mode-picker"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: root.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
                mask: root.closing ? empty : null

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Region {
                    id: empty
                }

                // Dim backdrop.
                StyledRect {
                    anchors.fill: parent
                    color: Qt.alpha(Colours.palette.m3scrim, 0.4)
                    opacity: root.closing ? 0 : 1

                    Behavior on opacity {
                        Anim {}
                    }

                    // Click outside the card dismisses.
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.dismiss()
                    }
                }

                FocusScope {
                    id: focusScope

                    anchors.fill: parent
                    focus: true

                    Component.onCompleted: forceActiveFocus()

                    Keys.onEscapePressed: root.dismiss()
                    Keys.onUpPressed: root.move(-1)
                    Keys.onDownPressed: root.move(1)
                    Keys.onReturnPressed: root.activate()
                    Keys.onEnterPressed: root.activate()
                    Keys.onPressed: event => {
                        const t = event.text;
                        if (t === "j")
                            root.move(1);
                        else if (t === "k")
                            root.move(-1);
                        else if (t >= "1" && t <= "4")
                            root.selectedIndex = parseInt(t) - 1;
                        else
                            return;
                        event.accepted = true;
                    }

                    StyledRect {
                        id: card

                        anchors.centerIn: parent
                        implicitWidth: 280
                        implicitHeight: layout.implicitHeight + Tokens.padding.large * 2
                        radius: Tokens.rounding.large
                        color: Colours.palette.m3surfaceContainer
                        opacity: root.closing ? 0 : 1
                        scale: root.closing ? 0.9 : 1

                        Behavior on opacity {
                            Anim {}
                        }
                        Behavior on scale {
                            Anim {}
                        }

                        Column {
                            id: layout

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Tokens.padding.large
                            spacing: Tokens.padding.extraSmall

                            StyledText {
                                anchors.left: parent.left
                                text: "Screenshot"
                                font: Tokens.font.title.small
                                color: Colours.palette.m3onSurface
                            }

                            Item {
                                implicitWidth: 1
                                implicitHeight: Tokens.padding.extraSmall
                            }

                            Repeater {
                                model: root.modes

                                StyledRect {
                                    id: row

                                    required property var modelData
                                    required property int index

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    implicitHeight: rowText.implicitHeight + Tokens.padding.medium * 2
                                    radius: Tokens.rounding.small
                                    color: index === root.selectedIndex ? Colours.palette.m3secondaryContainer : "transparent"

                                    MaterialIcon {
                                        id: rowIcon

                                        anchors.left: parent.left
                                        anchors.leftMargin: Tokens.padding.medium
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: row.modelData.icon
                                        color: index === root.selectedIndex ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                    }

                                    StyledText {
                                        id: rowText

                                        anchors.left: rowIcon.right
                                        anchors.leftMargin: Tokens.padding.medium
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: row.modelData.label
                                        color: index === root.selectedIndex ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    }

                                    StyledText {
                                        anchors.right: parent.right
                                        anchors.rightMargin: Tokens.padding.medium
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: `${row.index + 1}`
                                        font: Tokens.font.mono.small
                                        color: Colours.palette.m3onSurfaceVariant
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.selectedIndex = row.index
                                        onClicked: {
                                            root.selectedIndex = row.index;
                                            root.activate();
                                        }
                                    }
                                }
                            }

                            Item {
                                implicitWidth: 1
                                implicitHeight: Tokens.padding.extraSmall
                            }

                            StyledText {
                                anchors.left: parent.left
                                text: "↑↓ select · enter capture · esc cancel"
                                font: Tokens.font.body.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: closeTimer

        interval: Tokens.anim.durations.normal
        onTriggered: root.activeAsync = false
    }

    IpcHandler {
        function open(): void {
            root.closing = false;
            root.selectedIndex = 0;
            root.activeAsync = true;
        }

        target: "modepicker"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "screenshotMenu"
        description: "Open screenshot mode menu"
        onPressed: {
            root.closing = false;
            root.selectedIndex = 0;
            root.activeAsync = true;
        }
    }
}
