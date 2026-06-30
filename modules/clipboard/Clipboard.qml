pragma ComponentBehavior: Bound

// Top-level wiring for the clipboard overlay. Instantiated once from shell.qml.
// Uses the shared modules/utils/Overlay.qml primitive and exposes an IPC target
// so it can be toggled from a keybind:
//
//   caelestia-shell ipc call clipboard open      # bound to Super+C in Hyprland
//   caelestia-shell ipc call clipboard toggle
//   caelestia-shell ipc call clipboard close
//
// (mirrors the IpcHandler pattern in modules/areapicker/AreaPicker.qml.)

import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.utils

Scope {
    id: root

    Overlay {
        id: overlay

        name: "clipboard"

        contentComponent: Component {
            ClipboardContent {
                onRequestClose: overlay.close()
            }
        }
    }

    IpcHandler {
        target: "clipboard"

        function open(): void {
            Cliphist.refresh();
            overlay.open();
        }

        function close(): void {
            overlay.close();
        }

        function toggle(): void {
            if (overlay.active) {
                overlay.close();
            } else {
                Cliphist.refresh();
                overlay.open();
            }
        }
    }
}
