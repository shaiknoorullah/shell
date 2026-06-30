pragma ComponentBehavior: Bound

import "pin.js" as PinLogic
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// A single floating, always-on-top image capture ("pin"). One of these is
// created per entry in Pin.qml's `pins` model via Variants.
//
// It is a wlr layer-shell surface on the Top layer: it floats above normal
// windows, takes no exclusive zone, and never grabs keyboard focus (so typing
// keeps going to the focused app). It is positioned by anchoring to the
// top-left corner and driving `margins.left`/`margins.top` (layer-shell
// surfaces cannot be freely positioned, so margins are how we "move" it).
StyledWindow {
    id: root

    // { id: int, path: string } — injected by Pin.qml's Variants delegate.
    property var pin
    readonly property string path: pin?.path ?? ""

    signal closeRequested(int id)

    // Natural (decoded) pixel size of the image.
    readonly property real natW: image.implicitWidth
    readonly property real natH: image.implicitHeight

    // Live geometry/appearance state.
    property real scaleFactor: 1
    property real winX: 0
    property real winY: 0
    property real contentOpacity: 1
    property bool ready: false

    readonly property real minScale: 0.1
    readonly property real maxScale: 4

    function initGeometry(): void {
        if (root.ready || !(root.natW > 0) || !(root.natH > 0) || !root.screen)
            return;
        root.scaleFactor = PinLogic.fitScale(root.natW, root.natH, root.screen.width * 0.8, root.screen.height * 0.8);
        const dim = PinLogic.dimensions(root.natW, root.natH, root.scaleFactor);
        const off = PinLogic.centerOffset(dim.width, dim.height, root.screen.width, root.screen.height);
        root.winX = off.x;
        root.winY = off.y;
        root.ready = true;
    }

    // Monitor the pin lives on. Resolved ONCE at creation (see Component.onCompleted)
    // to the focused monitor, falling back to the first screen.
    //
    // This is deliberately NOT a live binding to Hypr.focusedMonitor: that property
    // is reactive, so a binding would re-evaluate on every focus change and teleport
    // the pin — and, since all PinWindow instances would share the same binding, every
    // other pin too — onto whatever monitor happens to be focused later. A pin must
    // stay on the monitor it was created on.
    property ShellScreen targetScreen: null
    screen: targetScreen

    name: "pin"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true
    anchors.left: true
    margins.left: Math.round(root.winX)
    margins.top: Math.round(root.winY)

    implicitWidth: Math.max(1, Math.round(root.natW * root.scaleFactor))
    implicitHeight: Math.max(1, Math.round(root.natH * root.scaleFactor))

    onScreenChanged: initGeometry()

    // Snapshot the focused monitor exactly once, when the pin is created.
    Component.onCompleted: {
        const mon = Hypr.focusedMonitor;
        const match = mon ? Quickshell.screens.find(s => s.name === mon.name) : null;
        root.targetScreen = match ?? Quickshell.screens[0] ?? null;
    }

    Item {
        id: content

        anchors.fill: parent

        HoverHandler {
            id: hover
        }

        Image {
            id: image

            anchors.fill: parent
            source: root.path ? `file://${root.path}` : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
            opacity: root.ready ? root.contentOpacity : 0

            onStatusChanged: {
                if (status === Image.Ready)
                    root.initGeometry();
            }
            onImplicitWidthChanged: root.initGeometry()

            Behavior on opacity {
                Anim {}
            }
        }

        // Drag the image body to move the pin. Middle-click closes it.
        MouseArea {
            id: dragArea

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real grabX
            property real grabY

            onPressed: e => {
                if (e.button === Qt.MiddleButton) {
                    if (root.pin)
                        root.closeRequested(root.pin.id);
                    return;
                }
                grabX = e.x;
                grabY = e.y;
            }
            onPositionChanged: e => {
                if (!pressed || !root.screen)
                    return;
                // Move by the delta; the surface follows the cursor so grabX/grabY
                // stay valid without re-capturing them.
                const pos = PinLogic.clampPosition(root.winX + (e.x - grabX), root.winY + (e.y - grabY), root.width, root.height, root.screen.width, root.screen.height);
                root.winX = pos.x;
                root.winY = pos.y;
            }
        }

        // Floating toolbar: opacity slider + close. Shown on hover.
        StyledRect {
            id: toolbar

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Tokens.spacing.small

            radius: Tokens.rounding.small
            color: Colours.tPalette.m3surfaceContainer

            opacity: hover.hovered ? 1 : 0
            visible: opacity > 0

            implicitWidth: toolbarRow.implicitWidth + Tokens.padding.small * 2
            implicitHeight: toolbarRow.implicitHeight + Tokens.padding.small * 2

            Behavior on opacity {
                Anim {}
            }

            RowLayout {
                id: toolbarRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: "opacity"
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledSlider {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 90
                    value: PinLogic.opacityToSlider(root.contentOpacity)
                    onInteraction: v => root.contentOpacity = PinLogic.sliderToOpacity(v)
                }

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    type: IconButton.Text
                    icon: "close"
                    onClicked: {
                        if (root.pin)
                            root.closeRequested(root.pin.id);
                    }
                }
            }
        }

        // Bottom-right resize handle. Preserves aspect ratio.
        StyledRect {
            id: resizeHandle

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.spacing.small

            implicitWidth: 24
            implicitHeight: 24
            radius: Tokens.rounding.small
            color: Colours.tPalette.m3surfaceContainer

            // Stay visible (and thus interactive) while an active resize drag is
            // in progress, even if the cursor briefly leaves the handle bounds.
            opacity: hover.hovered || resizeMouse.pressed ? 0.95 : 0
            visible: opacity > 0

            Behavior on opacity {
                Anim {}
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "open_in_full"
                color: Colours.palette.m3onSurfaceVariant
            }

            MouseArea {
                id: resizeMouse

                anchors.fill: parent
                cursorShape: Qt.SizeFDiagCursor

                onPositionChanged: e => {
                    // Cursor position relative to the pin's (fixed) top-left is the
                    // desired new size; convert to a scale factor.
                    const p = mapToItem(content, e.x, e.y);
                    root.scaleFactor = PinLogic.scaleFromCorner(p.x, p.y, root.natW, root.natH, root.minScale, root.maxScale);
                }
            }
        }
    }
}
