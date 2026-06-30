.pragma library

// editor.js — pure logic for the caelestia annotation editor.
//
// QML JavaScript "stateless library" resource: `.pragma library` on line 1 +
// plain top-level `function` declarations — the documented Qt/Quickshell pattern
// (same as modules/clipboard/logic.js). QML imports it with
// `import "editor.js" as EditorLogic` -> EditorLogic.CommandStack(), etc. It must
// NOT use ES `export` (Quickshell's QML JS engine rejects it). The node test
// loads it by stripping the pragma and appending exports (see editor.test.mjs).
//
// Shape model object (superset; each tool uses the fields it needs):
//   { id, type, x, y, x2, y2, points:[{x,y}], color, width, text, n }
//   type ∈ "pen" | "line" | "arrow" | "box" | "ellipse" | "highlight"
//          | "blur" | "text" | "step"

// ---------------------------------------------------------------------------
// internal helpers
// ---------------------------------------------------------------------------

function cloneModel(model) {
    // Shapes are plain JSON-safe data, so structured deep-copy via JSON is fine
    // and guarantees callers cannot mutate the stack's internal snapshots.
    return JSON.parse(JSON.stringify(model || []));
}

function boundsOf(shape) {
    if (shape.points && shape.points.length) {
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (const p of shape.points) {
            if (p.x < minX) minX = p.x;
            if (p.y < minY) minY = p.y;
            if (p.x > maxX) maxX = p.x;
            if (p.y > maxY) maxY = p.y;
        }
        return { x: minX, y: minY, x2: maxX, y2: maxY };
    }
    if (shape.type === "text" || shape.type === "step") {
        // point-anchored shapes: a small box around the anchor
        const r = Math.max(16, (shape.width || 3) * 5);
        return { x: shape.x - r, y: shape.y - r, x2: shape.x + r, y2: shape.y + r };
    }
    const x = shape.x ?? 0, y = shape.y ?? 0;
    const x2 = shape.x2 ?? x, y2 = shape.y2 ?? y;
    return { x: Math.min(x, x2), y: Math.min(y, y2), x2: Math.max(x, x2), y2: Math.max(y, y2) };
}

// ---------------------------------------------------------------------------
// undo/redo command stack (full-model snapshots)
// ---------------------------------------------------------------------------

function CommandStack() {
    // Index 0 is always the initial empty model so the first undo lands on a
    // clean canvas.
    const snapshots = [[]];
    let index = 0;

    return {
        // Record a new model state, discarding any redo future.
        push(model) {
            snapshots.length = index + 1;
            snapshots.push(cloneModel(model));
            index = snapshots.length - 1;
        },
        // Step back one state and return it (clone).
        undo() {
            if (index > 0) index--;
            return cloneModel(snapshots[index]);
        },
        // Step forward one state and return it (clone).
        redo() {
            if (index < snapshots.length - 1) index++;
            return cloneModel(snapshots[index]);
        },
        // Current state (clone) without moving the cursor.
        current() {
            return cloneModel(snapshots[index]);
        },
        get canUndo() {
            return index > 0;
        },
        get canRedo() {
            return index < snapshots.length - 1;
        }
    };
}

// ---------------------------------------------------------------------------
// hit testing (topmost shape under a point) — drives select/move
// ---------------------------------------------------------------------------

function hitTest(model, x, y, tol) {
    const t = tol == null ? 6 : tol;
    const list = model || [];
    // Iterate back-to-front: shapes drawn later sit on top.
    for (let i = list.length - 1; i >= 0; i--) {
        const b = boundsOf(list[i]);
        if (x >= b.x - t && x <= b.x2 + t && y >= b.y - t && y <= b.y2 + t)
            return list[i].id ?? null;
    }
    return null;
}

// ---------------------------------------------------------------------------
// arrow head geometry — returns [leftBarb, tip, rightBarb] (a polyline)
// ---------------------------------------------------------------------------

function arrowHead(x, y, x2, y2, size, spread) {
    const len = size == null ? 16 : size;
    const ang = spread == null ? Math.PI / 7 : spread;
    const theta = Math.atan2(y2 - y, x2 - x);
    return [
        { x: x2 - len * Math.cos(theta - ang), y: y2 - len * Math.sin(theta - ang) },
        { x: x2, y: y2 },
        { x: x2 - len * Math.cos(theta + ang), y: y2 - len * Math.sin(theta + ang) }
    ];
}

// ---------------------------------------------------------------------------
// numbered step markers — next auto-increment number
// ---------------------------------------------------------------------------

function nextStep(model) {
    let max = 0;
    for (const s of model || []) {
        if (s.type === "step" && typeof s.n === "number" && s.n > max)
            max = s.n;
    }
    return max + 1;
}

// ---------------------------------------------------------------------------
// ImageMagick fallback compositor — emit `convert` argv for the model.
// Caller wraps as: convert <basePng> ...toMagickArgs(model, baseRect) <outPng>
// `baseRect` ({x,y,width,height}) offsets coords so they are relative to the
// (possibly cropped) base origin. Coords are assumed already in base-image px.
// ---------------------------------------------------------------------------

function toMagickArgs(model, baseRect) {
    const off = baseRect || { x: 0, y: 0 };
    const ox = off.x || 0;
    const oy = off.y || 0;
    const tx = v => Math.round(v - ox);
    const ty = v => Math.round(v - oy);
    const esc = s => String(s).replace(/'/g, "\\'");

    const args = [];
    for (const s of model || []) {
        const color = s.color || "#ff0000";
        const w = s.width || 3;
        switch (s.type) {
        case "blur": {
            const x = Math.min(s.x, s.x2), y = Math.min(s.y, s.y2);
            const ww = Math.abs(s.x2 - s.x), hh = Math.abs(s.y2 - s.y);
            args.push("-region", `${Math.round(ww)}x${Math.round(hh)}+${tx(x)}+${ty(y)}`,
                "-scale", "8%", "-scale", "1250%", "-blur", "0x8", "+region");
            break;
        }
        case "line":
            args.push("-fill", "none", "-stroke", color, "-strokewidth", String(w),
                "-draw", `line ${tx(s.x)},${ty(s.y)} ${tx(s.x2)},${ty(s.y2)}`);
            break;
        case "box":
            args.push("-fill", "none", "-stroke", color, "-strokewidth", String(w),
                "-draw", `rectangle ${tx(Math.min(s.x, s.x2))},${ty(Math.min(s.y, s.y2))} ${tx(Math.max(s.x, s.x2))},${ty(Math.max(s.y, s.y2))}`);
            break;
        case "ellipse": {
            const cx = (s.x + s.x2) / 2, cy = (s.y + s.y2) / 2;
            const rx = Math.abs(s.x2 - s.x) / 2, ry = Math.abs(s.y2 - s.y) / 2;
            args.push("-fill", "none", "-stroke", color, "-strokewidth", String(w),
                "-draw", `ellipse ${tx(cx)},${ty(cy)} ${Math.round(rx)},${Math.round(ry)} 0,360`);
            break;
        }
        case "arrow": {
            args.push("-fill", "none", "-stroke", color, "-strokewidth", String(w),
                "-draw", `line ${tx(s.x)},${ty(s.y)} ${tx(s.x2)},${ty(s.y2)}`);
            const h = arrowHead(s.x, s.y, s.x2, s.y2, Math.max(12, w * 4));
            args.push("-draw", `polyline ${tx(h[0].x)},${ty(h[0].y)} ${tx(h[1].x)},${ty(h[1].y)} ${tx(h[2].x)},${ty(h[2].y)}`);
            break;
        }
        case "pen":
        case "highlight": {
            const pts = (s.points || []).map(p => `${tx(p.x)},${ty(p.y)}`).join(" ");
            if (pts)
                args.push("-fill", "none", "-stroke", color,
                    "-strokewidth", String(s.type === "highlight" ? Math.max(w, 14) : w),
                    "-draw", `polyline ${pts}`);
            break;
        }
        case "text":
            args.push("-fill", color, "-stroke", "none",
                "-pointsize", String(Math.max(14, w * 6)),
                "-draw", `text ${tx(s.x)},${ty(s.y)} '${esc(s.text || "")}'`);
            break;
        case "step": {
            const r = Math.max(14, w * 4);
            args.push("-fill", color, "-stroke", "none",
                "-draw", `circle ${tx(s.x)},${ty(s.y)} ${tx(s.x) + r},${ty(s.y)}`);
            args.push("-fill", "#ffffff", "-stroke", "none",
                "-pointsize", String(Math.round(r * 1.2)),
                "-draw", `text ${tx(s.x) - r / 3},${ty(s.y) + r / 3} '${esc(s.n || 1)}'`);
            break;
        }
        default:
            break;
        }
    }
    return args;
}

// Exports are appended at test-load time (see editor.test.mjs); in QML these
// functions are reached via the import namespace, e.g. EditorLogic.CommandStack().
