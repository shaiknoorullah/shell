pragma ComponentBehavior: Bound

// Shared, reusable fullscreen overlay primitive for caelestia.
//
// Wraps the Scope + LazyLoader(activeAsync) + Variants(per-screen) + StyledWindow
// (WlrLayer.Overlay, exclusive keyboard, anchored to every edge) pattern used by
// modules/areapicker/AreaPicker.qml, so feature modules don't each re-implement
// it. Phase "clip" owns this file; other overlay phases (e.g. screenshot editor)
// import it via `import qs.modules.utils` and supply their own `contentComponent`.
//
// Usage:
//   Overlay {
//       id: overlay
//       name: "clipboard"
//       contentComponent: Component {
//           MyContent { onRequestClose: overlay.close() }
//       }
//   }
// Then drive it from an IpcHandler / shortcut with open()/close()/toggle().
//
// The per-screen content is instantiated inside each window via a Loader that
// also exposes `overlay` (this object) and `screen` (the ShellScreen) so loaded
// content can reach them through its `parent` if needed.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components.containers
import qs.services

Scope {
    id: root

    // WlrLayershell namespace becomes `caelestia-<name>`; keep it unique per overlay.
    property string name: "overlay"
    // While true (during close) keyboard focus is released so input falls through.
    property bool closing
    // Set false for OnDemand focus instead of Exclusive (rarely needed).
    property bool exclusiveKeyboard: true
    // The content shown, full-bleed, on every screen.
    property Component contentComponent

    readonly property alias active: loader.active

    signal opened
    signal closed

    function open(): void {
        root.closing = false;
        loader.activeAsync = true;
        root.opened();
    }

    function close(): void {
        root.closing = true;
        loader.activeAsync = false;
        root.closed();
    }

    function toggle(): void {
        if (loader.active)
            root.close();
        else
            root.open();
    }

    LazyLoader {
        id: loader

        Variants {
            model: Screens.screens

            StyledWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                name: root.name

                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: root.closing ? WlrKeyboardFocus.None : root.exclusiveKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Loader {
                    id: contentLoader

                    // Exposed to loaded content via `parent.overlay` / `parent.screen`.
                    property var overlay: root
                    property ShellScreen screen: win.modelData

                    anchors.fill: parent
                    active: true
                    sourceComponent: root.contentComponent
                }
            }
        }
    }
}
