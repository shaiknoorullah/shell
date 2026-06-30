pragma Singleton

// Persisted clipboard pins. Pinned entries are shown first in the overlay and
// survive `cliphist wipe`. Stored as a JSON array of { raw, preview } at
// ${Paths.state}/clip-pins.json (e.g. ~/.local/state/caelestia/clip-pins.json).
//
// FileView persistence mirrors services/Notifs.qml: read on load, write via
// setText(), seed an empty file on first run.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    // [{ raw, preview }] — newest pin first.
    property var pins: []

    readonly property string path: `${Paths.state}/clip-pins.json`

    function isPinned(raw: string): bool {
        return root.pins.some(p => p.raw === raw);
    }

    function toggle(raw: string, preview: string): void {
        root.pins = root.isPinned(raw) ? root.pins.filter(p => p.raw !== raw) : [{
                raw,
                preview
            }, ...root.pins];
        view.setText(JSON.stringify(root.pins));
    }

    FileView {
        id: view

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                root.pins = JSON.parse(text() || "[]");
            } catch (e) {
                root.pins = [];
            }
        }
        onLoadFailed: err => {
            root.pins = [];
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => view.setText("[]"));
        }
    }
}
