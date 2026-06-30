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

    readonly property string path: `${Paths.state}/clip-meta.json`

    function lookup(md5: string): var {
        return root.map[md5] ?? null;
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
}
