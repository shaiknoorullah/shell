pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia
import qs.components
import qs.components.effects
import qs.services
import qs.utils
import "shot.js" as Shot

MouseArea {
    id: root

    required property LazyLoader loader
    required property ShellScreen screen

    property bool onClient

    property real realBorderWidth: onClient ? (Hypr.options["general:border_size"] ?? 1) : 2
    property real realRounding: onClient ? (Hypr.options["decoration:rounding"] ?? 0) : 0

    property real ssx
    property real ssy

    property real sx: 0
    property real sy: 0
    property real ex: screen.width
    property real ey: screen.height

    property real rsx: Math.min(sx, ex)
    property real rsy: Math.min(sy, ey)
    property real sw: Math.abs(sx - ex)
    property real sh: Math.abs(sy - ey)

    property list<var> clients: {
        const mon = Hypr.monitorFor(screen);
        if (!mon)
            return [];

        const special = mon.lastIpcObject.specialWorkspace;
        const wsId = special.name ? special.id : mon.activeWorkspace.id;

        return Hypr.toplevels.values.filter(c => c.workspace?.id === wsId).sort((a, b) => {
            // Pinned first, then fullscreen, then floating, then any other
            const ac = a.lastIpcObject;
            const bc = b.lastIpcObject;
            return (bc.pinned - ac.pinned) || ((bc.fullscreen !== 0) - (ac.fullscreen !== 0)) || (bc.floating - ac.floating);
        });
    }

    function checkClientRects(x: real, y: real): void {
        for (const client of clients) {
            if (!client)
                continue;

            let {
                at: [cx, cy],
                size: [cw, ch]
            } = client.lastIpcObject;
            cx -= screen.x;
            cy -= screen.y;
            if (cx <= x && cy <= y && cx + cw >= x && cy + ch >= y) {
                onClient = true;
                sx = cx;
                sy = cy;
                ex = cx + cw;
                ey = cy + ch;
                break;
            }
        }
    }

    property string lastPath
    property var grimCb
    property string grimPath

    // Swappable capture backend: native CUtils.saveItem (grabToImage) by default,
    // grim fallback when CAELESTIA_SHOT_GRIM=1 (set this if the nixGL grab comes
    // out black — see the Phase 2 risk gate).
    function capture(r: rect, outPath: string, cb: var): void {
        if (Quickshell.env("CAELESTIA_SHOT_GRIM") === "1") {
            grimCb = cb;
            grimPath = outPath;
            grimProc.command = Shot.grimCommand({
                x: r.x,
                y: r.y,
                w: r.width,
                h: r.height
            }, outPath);
            grimProc.running = true;
        } else {
            CUtils.saveItem(screencopy, Qt.resolvedUrl(outPath), r, cb);
        }
    }

    function save(): void {
        const r = Qt.rect(Math.ceil(rsx), Math.ceil(rsy), Math.floor(sw), Math.floor(sh));
        const outPath = Shot.shotPath(Date.now(), Paths.pictures);
        capture(r, outPath, path => {
            root.lastPath = path;

            // OCR mode (pin phase): run tesseract on the saved capture, copy the
            // recognised text to the clipboard and notify. No image copy/notify.
            if (root.loader.ocr) {
                Quickshell.execDetached(["sh", "-c", `tesseract '${path}' - --psm 6 | wl-copy && notify-send -a caelestia-cli 'OCR copied' "$(wl-paste | head -c 4000)"`]);
                closeAnim.start();
                return;
            }

            Quickshell.execDetached(["sh", "-c", `wl-copy --type image/png < '${path}'`]);
            if (root.loader.clipboardOnly) {
                Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-i", path, "-h", `string:image-path:${path}`, "Screenshot copied", "Copied to clipboard"]);
            } else {
                // Actionable notification routed via notifProc's stdout:
                // open/edit/copy/delete come from Shot.notifyArgs; the extra "pin"
                // action (pin phase) opens the capture in the pin module.
                notifProc.command = Shot.notifyArgs(path, true).concat(["--action=pin=Pin"]);
                notifProc.running = true;
            }
            closeAnim.start();
        });
    }

    onClientsChanged: checkClientRects(mouseX, mouseY)

    anchors.fill: parent
    opacity: 0
    hoverEnabled: true
    cursorShape: Qt.CrossCursor

    Component.onCompleted: {
        Hypr.extras.refreshOptions();

        // Break binding if frozen
        if (loader.freeze)
            clients = clients;

        opacity = 1;

        // Fullscreen / focused-monitor fast path (shot phase): select the whole
        // screen and trigger the screencopy capture immediately, skipping the
        // interactive selection overlay.
        if (loader.fullscreen) {
            onClient = false;
            sx = 0;
            sy = 0;
            ex = screen.width;
            ey = screen.height;
            overlay.visible = border.visible = false;
            screencopy.visible = false;
            screencopy.active = true;
            return;
        }

        const c = clients[0];
        if (c) {
            const cx = c.lastIpcObject.at[0] - screen.x;
            const cy = c.lastIpcObject.at[1] - screen.y;
            onClient = true;
            sx = cx;
            sy = cy;
            ex = cx + c.lastIpcObject.size[0];
            ey = cy + c.lastIpcObject.size[1];
        } else {
            sx = screen.width / 2 - 100;
            sy = screen.height / 2 - 100;
            ex = screen.width / 2 + 100;
            ey = screen.height / 2 + 100;
        }
    }

    onPressed: event => {
        ssx = event.x;
        ssy = event.y;
    }

    onReleased: {
        if (closeAnim.running)
            return;

        if (root.loader.freeze) {
            save();
        } else {
            overlay.visible = border.visible = false;
            screencopy.visible = false;
            screencopy.active = true;
        }
    }

    onPositionChanged: event => {
        const x = event.x;
        const y = event.y;

        if (pressed) {
            onClient = false;
            sx = ssx;
            sy = ssy;
            ex = x;
            ey = y;
        } else {
            checkClientRects(x, y);
        }
    }

    focus: true
    Keys.onEscapePressed: closeAnim.start()

    SequentialAnimation {
        id: closeAnim

        PropertyAction {
            target: root.loader
            property: "closing"
            value: true
        }
        ParallelAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
            Anim {
                target: root
                properties: "rsx,rsy"
                to: 0
            }
            Anim {
                target: root
                property: "sw"
                to: root.screen.width
            }
            Anim {
                target: root
                property: "sh"
                to: root.screen.height
            }
        }
        PropertyAction {
            target: root.loader
            property: "activeAsync"
            value: false
        }
    }

    Process {
        running: true
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pos = JSON.parse(text);
                root.checkClientRects(pos.x - root.screen.x, pos.y - root.screen.y);
            }
        }
    }

    Loader {
        id: screencopy

        asynchronous: true
        anchors.fill: parent

        active: root.loader.freeze

        sourceComponent: ScreencopyView {
            captureSource: root.screen

            onHasContentChanged: {
                if (hasContent && !root.loader.freeze) {
                    if (!root.loader.fullscreen)
                        overlay.visible = border.visible = true;
                    root.save();
                }
            }
        }
    }

    StyledRect {
        id: overlay

        anchors.fill: parent
        color: Colours.palette.m3secondaryContainer
        opacity: 0.3

        layer.enabled: true
        layer.effect: Mask {
            maskSource: selectionWrapper
            maskInverted: true
        }
    }

    Item {
        id: selectionWrapper

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            id: selectionRect

            radius: root.realRounding
            x: root.rsx
            y: root.rsy
            implicitWidth: root.sw
            implicitHeight: root.sh
        }
    }

    Rectangle {
        id: border

        color: "transparent"
        radius: root.realRounding > 0 ? root.realRounding + root.realBorderWidth : 0
        border.width: root.realBorderWidth
        border.color: Colours.palette.m3primary

        x: selectionRect.x - root.realBorderWidth
        y: selectionRect.y - root.realBorderWidth
        implicitWidth: selectionRect.implicitWidth + root.realBorderWidth * 2
        implicitHeight: selectionRect.implicitHeight + root.realBorderWidth * 2

        Behavior on border.color {
            CAnim {}
        }
    }

    // Cursor loupe (shot phase). Hidden in fullscreen mode and when the pointer
    // is off the surface; best in freeze mode where screencopy is live.
    Magnifier {
        source: screencopy
        cursorX: root.mouseX
        cursorY: root.mouseY
        regionX: root.rsx
        regionY: root.rsy
        regionW: root.sw
        regionH: root.sh
        screenWidth: root.screen.width
        screenHeight: root.screen.height
        visible: !root.loader.fullscreen && root.opacity > 0 && root.containsMouse
    }

    // grim fallback backend (CAELESTIA_SHOT_GRIM=1): fires the capture callback
    // on successful exit.
    Process {
        id: grimProc

        onExited: exitCode => {
            // qmllint disable signal-handler-parameters
            if (exitCode === 0 && root.grimCb)
                root.grimCb(root.grimPath);
            root.grimCb = null;
        }
    }

    // Routes the activated notify-send action (printed on stdout) to its handler.
    // edit -> native annotation editor (editor phase); pin -> pin module (pin phase).
    Process {
        id: notifProc

        stdout: StdioCollector {
            onStreamFinished: {
                const action = text.trim();
                const p = root.lastPath;
                if (!p)
                    return;
                if (action === "open")
                    Quickshell.execDetached(["xdg-open", p]);
                else if (action === "edit")
                    Quickshell.execDetached(["caelestia-shell", "ipc", "call", "editor", "open", p]);
                else if (action === "copy")
                    Quickshell.execDetached(["wl-copy", p]);
                else if (action === "delete")
                    Quickshell.execDetached(["rm", p]);
                else if (action === "pin")
                    Quickshell.execDetached(["caelestia-shell", "ipc", "call", "pin", "open", p]);
            }
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.StandardLarge
        }
    }

    Behavior on rsx {
        enabled: !root.pressed

        Anim {}
    }

    Behavior on rsy {
        enabled: !root.pressed

        Anim {}
    }

    Behavior on sw {
        enabled: !root.pressed

        Anim {}
    }

    Behavior on sh {
        enabled: !root.pressed

        Anim {}
    }
}
