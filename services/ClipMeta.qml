pragma Singleton

// Read-only view over the clipboard metadata sidecar written by
// ~/.config/caelestia/scripts/clip-meta-record.sh. That script maps
// md5(content) -> { ts, app } at ${Paths.state}/clip-meta.json
// (e.g. ~/.local/state/caelestia/clip-meta.json), recording the source app and
// capture time of each clip. The overlay joins it lazily: decode an entry's text,
// Qt.md5() it, and call lookup() to show "<app> · <relative time>".
//
// watchChanges keeps the in-memory map fresh as the sidecar appends entries.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    // { [md5]: { ts: int, app: string } }
    property var map: ({})

    // Manual sensitive overrides, keyed by md5(raw): { [md5]: true }. Persisted
    // separately from the sidecar-owned meta store so the user's ⌃s toggles
    // survive independently. Raw-keyed (no per-row decode needed).
    property var marks: ({})

    readonly property string path: `${Paths.state}/clip-meta.json`
    readonly property string marksPath: `${Paths.state}/clip-marks.json`

    function lookup(md5: string): var {
        return root.map[md5] ?? null;
    }

    // Has the user manually marked this raw entry as sensitive?
    function markedSensitive(raw: string): bool {
        return root.marks[Qt.md5(raw)] === true;
    }

    // Toggle/set the manual sensitive mark for a raw entry, then persist.
    function setMarked(raw: string, on: bool): void {
        const key = Qt.md5(raw);
        const next = Object.assign({}, root.marks);
        if (on)
            next[key] = true;
        else
            delete next[key];
        root.marks = next;
        marksView.setText(JSON.stringify(root.marks));
    }

    FileView {
        path: root.path
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoaded: {
            try {
                root.map = JSON.parse(text() || "{}");
            } catch (e) {
                root.map = ({});
            }
        }
        onLoadFailed: root.map = ({})
    }

    FileView {
        id: marksView

        path: root.marksPath
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoaded: {
            try {
                root.marks = JSON.parse(text() || "{}");
            } catch (e) {
                root.marks = ({});
            }
        }
        onLoadFailed: err => {
            root.marks = ({});
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => marksView.setText("{}"));
        }
    }
}
