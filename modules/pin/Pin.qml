pragma ComponentBehavior: Bound

import "pin.js" as PinLogic
import Quickshell
import Quickshell.Io

// Pin-to-screen manager. Holds the list of active pins and exposes IPC so other
// parts of the system (Picker notification action, hyprland keybind, the OCR /
// colour-picker hooks) can spawn floating always-on-top image captures via:
//     caelestia-shell ipc call pin open <path>
//     caelestia-shell ipc call pin closeAll
//
// Each pin is a `{ id, path }` object; the id keeps Quickshell `Variants`
// delegates stable (so adding/removing one pin never rebuilds the others, and
// the same image can be pinned more than once).
Scope {
    id: root

    // list<{ id: int, path: string }>
    property var pins: []

    function add(path: string): void {
        const clean = PinLogic.stripFileScheme(path);
        if (!clean || clean.length === 0)
            return;
        root.pins = PinLogic.addPin(root.pins, clean, PinLogic.nextId(root.pins));
    }

    function remove(id: int): void {
        root.pins = PinLogic.removePin(root.pins, id);
    }

    IpcHandler {
        target: "pin"

        function open(path: string): void {
            root.add(path);
        }

        function closeAll(): void {
            root.pins = [];
        }

        // Number of pins currently on screen (handy for scripted verification).
        function count(): int {
            return root.pins.length;
        }
    }

    Variants {
        model: root.pins

        PinWindow {
            required property var modelData

            pin: modelData
            onCloseRequested: id => root.remove(id)
        }
    }
}
