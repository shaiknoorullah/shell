pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia
import qs.components.containers
import qs.services
import qs.utils
import "editor.js" as EditorLogic

// Annotation editor entry point: a per-screen fullscreen Overlay window driven by
// IPC (`caelestia-shell ipc call editor open <path>`), hosting EditorCanvas.
//
// NOTE on the Overlay primitive: the architecture calls for importing the
// clip-phase `modules/utils/Overlay.qml`. That file does not exist yet and the
// two upstream specs describe it differently (clip: "centered modal w/ dim
// backdrop"; orchestrator: fullscreen per-screen StyledWindow). The editor needs
// the fullscreen-window shape, so the windowing is inlined here with the exact,
// confirmed areapicker APIs (mirrors modules/areapicker/AreaPicker.qml). When
// clip lands a fullscreen-shaped Overlay, replace the Scope/LazyLoader/Variants/
// StyledWindow block below with `Overlay { ... }` (see openIssues for the seam).
Scope {
    id: scope

    function open(p: string): void {
        loader.path = p;
        loader.closing = false;
        loader.activeAsync = true;
    }
    function close(): void {
        loader.closing = true;
        loader.activeAsync = false;
    }

    function shquote(argv: var): string {
        return argv.map(a => "'" + String(a).replace(/'/g, "'\\''") + "'").join(" ");
    }

    function postExport(savedPath: string): void {
        Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < '" + savedPath.replace(/'/g, "'\\''") + "'"]);
        Quickshell.execDetached(["notify-send", "-a", "caelestia-cli", "-i", savedPath, "Annotation saved", savedPath]);
        scope.close();
    }

    function exportImage(canvas: var): void {
        const ts = Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss");
        const dir = Paths.pictures + "/Screenshots";
        const out = dir + "/screenshot-" + ts + "-edited.png";

        if (Quickshell.env("CAELESTIA_EDITOR_MAGICK") === "1") {
            // Fallback backend (Task 6 risk gate): composite the model server-side
            // onto the original PNG with ImageMagick, then crop to the crop rect.
            const r = canvas.exportRect();
            const sc = canvas.fitScale > 0 ? 1 / canvas.fitScale : 1;
            const cx = Math.round(r.x * sc), cy = Math.round(r.y * sc);
            const cw = Math.round(r.width * sc), ch = Math.round(r.height * sc);
            const drawArgs = EditorLogic.toMagickArgs(canvas.nativeModel(), { x: 0, y: 0 });
            const cropArg = canvas.cropRect ? ["-crop", `${cw}x${ch}+${cx}+${cy}`, "+repage"] : [];
            const cmd = ["convert", canvas.basePath()].concat(drawArgs).concat(cropArg).concat([out]);
            const proc = magickComp.createObject(scope, {
                command: ["sh", "-c", `mkdir -p '${dir}' && ` + scope.shquote(cmd)],
                outPath: out
            });
            proc.running = true;
        } else {
            // Primary backend: GPU grab of the annotated canvas. CUtils.saveItem
            // runs grabToImage + DPR scaling + rect crop + mkpath internally
            // (see plugin/src/Caelestia/cutils.cpp) — same path the picker uses.
            // Hide editor-only chrome (selection box, crop border + handles) so it
            // is not baked into the grabbed PNG; restore it in the save callback.
            canvas.grabbing = true;
            CUtils.saveItem(canvas.captureTarget, Qt.resolvedUrl(out), canvas.exportRect(), savedPath => {
                canvas.grabbing = false;
                scope.postExport(savedPath);
            });
        }
    }

    LazyLoader {
        id: loader

        property string path: ""
        property bool closing: false

        Variants {
            model: Screens.screens

            StyledWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                name: "editor"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: loader.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                EditorCanvas {
                    anchors.fill: parent
                    path: loader.path
                    onRequestClose: scope.close()
                    onRequestExport: source => scope.exportImage(source)
                }
            }
        }
    }

    // ImageMagick fallback process (only created when the env flag is set).
    Component {
        id: magickComp

        Process {
            id: proc

            property string outPath

            onExited: code => {
                if (code === 0)
                    scope.postExport(proc.outPath);
                proc.destroy();
            }
        }
    }

    IpcHandler {
        function open(path: string): void {
            scope.open(path);
        }
        function close(): void {
            scope.close();
        }

        target: "editor"
    }
}
