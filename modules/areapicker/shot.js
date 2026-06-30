.pragma library

// shot.js — pure geometry / filename / notify-arg helpers for the caelestia
// screenshot tool (Phase 2 "shot"). All functions are side-effect free so they
// can be unit-tested with `node --test modules/areapicker/shot.test.mjs`.
//
// QML usage:  import "shot.js" as Shot   ->   Shot.monitorRect(...), Shot.shotPath(...)
//
// This is a QML JavaScript "stateless library" resource: `.pragma library` on
// line 1 + plain top-level `function` declarations — the documented Qt/Quickshell
// pattern (same as modules/clipboard/logic.js and caelestia's utils/scripts/*).
// It must NOT use ES `export`: Quickshell's QML JS engine rejects it with
// "Unexpected token export". The node test loads it by stripping the pragma and
// appending exports (see shot.test.mjs).

function _clamp(v, lo, hi) {
    return Math.max(lo, Math.min(v, hi));
}

function _pad2(n) {
    return n < 10 ? "0" + n : "" + n;
}

// monitorRect(mon) -> screen-local logical rect {x:0, y:0, w, h}.
// `mon` is a Hyprland-monitor-like object with physical {width,height} and a
// fractional {scale}. The picker works in logical pixels, so logical = physical
// / scale. Used by the fullscreen / focused-monitor fast path.
function monitorRect(mon) {
    const scale = mon && mon.scale ? mon.scale : 1;
    const w = Math.round((mon && mon.width ? mon.width : 0) / scale);
    const h = Math.round((mon && mon.height ? mon.height : 0) / scale);
    return { x: 0, y: 0, w, h };
}

// clampRect(r, screen) -> r clamped (edge-based) to [0,0,screen.width,screen.height].
// Normalises negative width/height, then clamps each edge independently so an
// off-screen drag never produces an out-of-bounds capture rect.
function clampRect(r, screen) {
    const W = screen && screen.width ? screen.width : 0;
    const H = screen && screen.height ? screen.height : 0;
    const x0 = Math.min(r.x, r.x + r.w);
    const y0 = Math.min(r.y, r.y + r.h);
    const x1 = Math.max(r.x, r.x + r.w);
    const y1 = Math.max(r.y, r.y + r.h);
    const left = _clamp(x0, 0, W);
    const top = _clamp(y0, 0, H);
    const right = _clamp(x1, 0, W);
    const bottom = _clamp(y1, 0, H);
    return { x: left, y: top, w: right - left, h: bottom - top };
}

// dirOf(path) -> parent directory of a unix path.
function dirOf(path) {
    const i = path.lastIndexOf("/");
    return i <= 0 ? "/" : path.slice(0, i);
}

// shotPath(now, picturesDir) -> "<picturesDir>/Screenshots/screenshot-YYYYMMDD-HHMMSS.png".
// `now` is epoch milliseconds (Date.now()). The timestamp is formatted in UTC so
// the result is deterministic across machine timezones and lexically sortable.
// `picturesDir` defaults to "~/Pictures"; QML passes the resolved Paths.pictures.
function shotPath(now, picturesDir) {
    if (picturesDir === undefined || picturesDir === null || picturesDir === "")
        picturesDir = "~/Pictures";
    const d = new Date(now);
    const stamp =
        d.getUTCFullYear() +
        _pad2(d.getUTCMonth() + 1) +
        _pad2(d.getUTCDate()) +
        "-" +
        _pad2(d.getUTCHours()) +
        _pad2(d.getUTCMinutes()) +
        _pad2(d.getUTCSeconds());
    const dir = picturesDir.replace(/\/+$/, "") + "/Screenshots";
    return dir + "/screenshot-" + stamp + ".png";
}

// grimGeometry(rect) -> "<x>,<y> <w>x<h>" string for `grim -g` (fallback backend).
function grimGeometry(rect) {
    const x = Math.round(rect.x);
    const y = Math.round(rect.y);
    const w = Math.round(rect.w);
    const h = Math.round(rect.h);
    return x + "," + y + " " + w + "x" + h;
}

// grimCommand(rect, outPath) -> argv for the grim fallback backend. Ensures the
// destination directory exists (the native CUtils backend mkdir's internally,
// grim does not) then captures the rect to outPath.
function grimCommand(rect, outPath) {
    const dir = dirOf(outPath);
    const cmd = "mkdir -p '" + dir + "' && grim -g '" + grimGeometry(rect) + "' '" + outPath + "'";
    return ["sh", "-c", cmd];
}

// notifyArgs(path, copied) -> full argv for `notify-send` with actionable
// buttons. When run via a Process (not execDetached), notify-send prints the
// activated action key (open/edit/copy/delete) on stdout for routing.
function notifyArgs(path, copied) {
    const body = copied ? "Saved and copied to clipboard" : "Saved to " + path;
    return [
        "notify-send",
        "-a", "caelestia-shell",
        "-i", path,
        "-h", "string:image-path:" + path,
        "Screenshot saved",
        body,
        "--action=open=Open",
        "--action=edit=Edit",
        "--action=copy=Copy path",
        "--action=delete=Delete"
    ];
}
