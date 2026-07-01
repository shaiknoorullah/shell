pragma Singleton

// Backing service for the clipboard overlay. Wraps the `cliphist` CLI
// (https://github.com/sentriz/cliphist) + wl-clipboard. The clipboard history is
// populated by the user's existing `wl-paste --watch cliphist store` Hyprland
// autostart; this service only reads/decodes/copies/deletes entries.
//
// Process usage mirrors services/Network.qml + modules/areapicker/Picker.qml
// (Process + StdioCollector). One-shot Processes are created on demand from
// Components and destroy themselves on exit so we never leak QProcess handles.

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/clipboard/logic.js" as Logic

Singleton {
    id: root

    // [{ id, raw, preview }] — `raw` is the full "<id>\t<preview>" line cliphist
    // decode/delete expect on stdin. Newest first (cliphist list order).
    property var entries: []

    function refresh(): void {
        listProc.running = true;
    }

    // Decode `raw` to its original content and put it on the Wayland clipboard.
    // For entries cliphist tags with an explicit image mime (older cliphist
    // format "binary data image/png") we set wl-copy --type so image consumers
    // get the right mime; otherwise we use the universal `decode | wl-copy` pipe.
    function copy(raw: string): void {
        const m = String(raw).match(/binary data\s+(image\/[\w.+-]+)/i);
        const wl = m ? `wl-copy --type '${m[1]}'` : "wl-copy";
        runSink(["sh", "-c", `printf '%s' "$1" | cliphist decode | ${wl}`, "sh", raw]);
    }

    // Decode `raw` to text and hand it to cb(text). Used for the preview pane.
    function decodeText(raw: string, cb: var): void {
        runText(["sh", "-c", 'printf "%s" "$1" | cliphist decode', "sh", raw], cb);
    }

    // Decode `raw` (an image entry) to `path` then call cb(path).
    function decodeImage(raw: string, path: string, cb: var): void {
        runSink(["sh", "-c", 'printf "%s" "$1" | cliphist decode > "$2"', "sh", raw, path], () => cb(path));
    }

    // Delete a single entry from history, then refresh the list.
    function remove(raw: string): void {
        runSink(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "sh", raw], () => root.refresh());
    }

    // Re-store text into cliphist history (used by delete-undo).
    function restore(text: string): void {
        runSink(["sh", "-c", 'printf "%s" "$1" | cliphist store', "sh", text], () => root.refresh());
    }

    // Put arbitrary text on the Wayland clipboard (used by edit-in-place save).
    function copyText(text: string): void {
        runSink(["sh", "-c", 'printf "%s" "$1" | wl-copy', "sh", text]);
    }

    // Wipe the entire clipboard history.
    function wipe(): void {
        wipeProc.running = true;
        root.entries = [];
    }

    // --- internal one-shot process helpers -----------------------------------

    // Run argv, ignoring stdout; call done() on exit.
    function runSink(argv: list<string>, done: var): void {
        sinkComp.createObject(root, {
            command: argv,
            done: done ?? (() => {})
        }).running = true;
    }

    // Run argv, collecting stdout; call done(text) when the stream finishes.
    function runText(argv: list<string>, done: var): void {
        textComp.createObject(root, {
            command: argv,
            done: done ?? (() => {})
        }).running = true;
    }

    Process {
        id: listProc

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.entries = Logic.parseList(text)
        }
    }

    Process {
        id: wipeProc

        command: ["cliphist", "wipe"]
        onExited: root.refresh()
    }

    Component {
        id: sinkComp

        Process {
            id: sinkProc

            property var done

            onExited: {
                sinkProc.done();
                sinkProc.destroy();
            }
        }
    }

    Component {
        id: textComp

        Process {
            id: textProc

            property var done

            stdout: StdioCollector {
                onStreamFinished: {
                    textProc.done(text);
                    textProc.destroy();
                }
            }
        }
    }

    Component.onCompleted: root.refresh()
}
