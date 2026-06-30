// pin.js — pure logic for the pin-to-screen feature (Phase "pin").
//
// Dual-consumable (same convention as modules/areapicker/shot.js and
// modules/editor/editor.js):
//   - QML:  import "pin.js" as PinLogic   (Qt6 exposes the ES exports on the namespace)
//             ... PinLogic.addPin(pins, path, PinLogic.nextId(pins)) ...
//   - node: import { ... } from "./pin.js" (ESM, unit-tested with `node --test`)
//
// NOTE: intentionally NO `.pragma library` line. Under node v22 a leading
// `.pragma library` directive is not valid ECMAScript and breaks ESM detection
// (node falls back to CommonJS and the named imports fail). Omitting it lets node
// auto-detect ESM while Qt 6 still imports an `export`-bearing .js as a module.
//
// All the array bookkeeping + geometry math lives here (rather than inline in the
// QML) so it is deterministic and testable without a running compositor. The QML
// files contain only wiring + bindings.

/**
 * Clamp `v` into the inclusive range [lo, hi]. Tolerates lo > hi by preferring lo.
 * @param {number} v
 * @param {number} lo
 * @param {number} hi
 * @returns {number}
 */
export function clamp(v, lo, hi) {
    if (hi < lo)
        return lo;
    if (v < lo)
        return lo;
    if (v > hi)
        return hi;
    return v;
}

/**
 * Next monotonic id for a new pin, given the existing pin objects.
 * Pins are stored as `{ id: number, path: string }`; a stable unique id is
 * required so Quickshell `Variants` can key delegates by object identity
 * (two pins of the same image path must remain distinct).
 * @param {{id:number}[]} pins
 * @returns {number}
 */
export function nextId(pins) {
    let max = 0;
    for (const p of pins) {
        if (p && typeof p.id === "number" && p.id > max)
            max = p.id;
    }
    return max + 1;
}

/**
 * Append a new pin. Returns a NEW array but reuses the existing pin object
 * references so `Variants` only instantiates the one new delegate.
 * @param {{id:number,path:string}[]} pins
 * @param {string} path
 * @param {number} id
 * @returns {{id:number,path:string}[]}
 */
export function addPin(pins, path, id) {
    return [...pins, { id, path }];
}

/**
 * Remove the pin with the given id, preserving the remaining object references.
 * @param {{id:number,path:string}[]} pins
 * @param {number} id
 * @returns {{id:number,path:string}[]}
 */
export function removePin(pins, id) {
    return pins.filter(p => p.id !== id);
}

/**
 * Strip a leading `file://` (or `file://localhost`) scheme from a path, if present.
 * IPC callers may pass either a bare path or a file URI.
 * @param {string} path
 * @returns {string}
 */
export function stripFileScheme(path) {
    if (typeof path !== "string")
        return "";
    if (path.startsWith("file://localhost"))
        return path.slice("file://localhost".length);
    if (path.startsWith("file://"))
        return path.slice("file://".length);
    return path;
}

/**
 * Initial scale factor so the image fits within (maxW x maxH) while preserving
 * aspect ratio. Never upscales past 1:1.
 * @param {number} natW natural pixel width
 * @param {number} natH natural pixel height
 * @param {number} maxW
 * @param {number} maxH
 * @returns {number} scale in (0, 1]
 */
export function fitScale(natW, natH, maxW, maxH) {
    if (!(natW > 0) || !(natH > 0) || !(maxW > 0) || !(maxH > 0))
        return 1;
    const s = Math.min(maxW / natW, maxH / natH, 1);
    return s > 0 ? s : 1;
}

/**
 * Pixel dimensions for a given scale factor (rounded to whole pixels, min 1px).
 * @param {number} natW
 * @param {number} natH
 * @param {number} scale
 * @returns {{width:number,height:number}}
 */
export function dimensions(natW, natH, scale) {
    return {
        width: Math.max(1, Math.round(natW * scale)),
        height: Math.max(1, Math.round(natH * scale))
    };
}

/**
 * Scale factor derived from a corner-resize-handle drag. `pointerX`/`pointerY`
 * are the cursor coordinates relative to the pin's top-left corner (which stays
 * fixed during a resize). Uses the larger of the two axis-derived scales so the
 * aspect ratio is preserved and dragging either axis outward grows the pin.
 * @param {number} pointerX
 * @param {number} pointerY
 * @param {number} natW
 * @param {number} natH
 * @param {number} minScale
 * @param {number} maxScale
 * @returns {number}
 */
export function scaleFromCorner(pointerX, pointerY, natW, natH, minScale, maxScale) {
    if (!(natW > 0) || !(natH > 0))
        return minScale;
    const sx = pointerX / natW;
    const sy = pointerY / natH;
    return clamp(Math.max(sx, sy), minScale, maxScale);
}

/**
 * Map a normalised slider value [0,1] to a window opacity in [minOpacity, 1].
 * Keeps the pin from ever becoming fully invisible.
 * @param {number} v slider value in [0,1]
 * @param {number} [minOpacity=0.15]
 * @returns {number}
 */
export function sliderToOpacity(v, minOpacity = 0.15) {
    const t = clamp(v, 0, 1);
    return minOpacity + t * (1 - minOpacity);
}

/**
 * Inverse of {@link sliderToOpacity} — initial slider handle position for a
 * given opacity.
 * @param {number} opacity
 * @param {number} [minOpacity=0.15]
 * @returns {number} slider value in [0,1]
 */
export function opacityToSlider(opacity, minOpacity = 0.15) {
    if (1 - minOpacity <= 0)
        return 1;
    return clamp((opacity - minOpacity) / (1 - minOpacity), 0, 1);
}

/**
 * Top-left margins to center a (w x h) window on a (screenW x screenH) screen.
 * Result is clamped to non-negative integers (layer-shell margins are
 * non-negative ints).
 * @param {number} w
 * @param {number} h
 * @param {number} screenW
 * @param {number} screenH
 * @returns {{x:number,y:number}}
 */
export function centerOffset(w, h, screenW, screenH) {
    return {
        x: Math.max(0, Math.round((screenW - w) / 2)),
        y: Math.max(0, Math.round((screenH - h) / 2))
    };
}

/**
 * Clamp a window's top-left (x, y) so the surface stays anchored on-screen.
 * Layer-shell margins are non-negative ints, so the top-left is kept within
 * [0, screen - keepVisible]; this guarantees at least `keepVisible` px of the
 * pin remains reachable even for windows larger than the screen.
 * @param {number} x
 * @param {number} y
 * @param {number} w
 * @param {number} h
 * @param {number} screenW
 * @param {number} screenH
 * @param {number} [keepVisible=64]
 * @returns {{x:number,y:number}}
 */
export function clampPosition(x, y, w, h, screenW, screenH, keepVisible = 64) {
    const maxX = Math.max(0, screenW - keepVisible);
    const maxY = Math.max(0, screenH - keepVisible);
    return {
        x: Math.round(clamp(x, 0, maxX)),
        y: Math.round(clamp(y, 0, maxY))
    };
}
