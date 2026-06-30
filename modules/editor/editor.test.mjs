import assert from "node:assert/strict";
import { test } from "node:test";
import {
    CommandStack,
    hitTest,
    arrowHead,
    nextStep,
    toMagickArgs,
    boundsOf
} from "./editor.js";

// ---------------------------------------------------------------------------
// CommandStack — undo/redo round trips
// ---------------------------------------------------------------------------

test("CommandStack starts empty with no undo/redo", () => {
    const s = CommandStack();
    assert.equal(s.canUndo, false);
    assert.equal(s.canRedo, false);
    assert.deepEqual(s.current(), []);
});

test("CommandStack push enables undo and round-trips", () => {
    const s = CommandStack();
    s.push([{ id: "1" }]);
    assert.equal(s.canUndo, true);
    assert.equal(s.canRedo, false);
    s.push([{ id: "1" }, { id: "2" }]);

    assert.deepEqual(s.undo(), [{ id: "1" }]);
    assert.equal(s.canRedo, true);
    assert.deepEqual(s.redo(), [{ id: "1" }, { id: "2" }]);

    assert.deepEqual(s.undo(), [{ id: "1" }]);
    assert.deepEqual(s.undo(), []); // back to the initial empty state
    assert.equal(s.canUndo, false);

    assert.deepEqual(s.redo(), [{ id: "1" }]); // redo still works after full undo
});

test("CommandStack push truncates the redo future", () => {
    const s = CommandStack();
    s.push([{ id: "a" }]);
    s.push([{ id: "b" }]);
    s.undo(); // now at [{a}]
    assert.equal(s.canRedo, true);
    s.push([{ id: "c" }]); // diverge -> redo future dropped
    assert.equal(s.canRedo, false);
    assert.deepEqual(s.current(), [{ id: "c" }]);
});

test("CommandStack returns clones (callers cannot corrupt history)", () => {
    const s = CommandStack();
    s.push([{ id: "x", points: [{ x: 1, y: 2 }] }]);
    const snap = s.current();
    snap[0].points[0].x = 999; // mutate the returned copy
    assert.deepEqual(s.current(), [{ id: "x", points: [{ x: 1, y: 2 }] }]);
});

// ---------------------------------------------------------------------------
// hitTest
// ---------------------------------------------------------------------------

test("hitTest returns id when point is inside a box, null when outside", () => {
    const model = [{ id: "b1", type: "box", x: 10, y: 10, x2: 50, y2: 40, color: "#f00", width: 3 }];
    assert.equal(hitTest(model, 30, 25), "b1");
    assert.equal(hitTest(model, 500, 500), null);
});

test("hitTest handles a box drawn bottom-right to top-left (unnormalised)", () => {
    const model = [{ id: "b1", type: "box", x: 50, y: 40, x2: 10, y2: 10 }];
    assert.equal(hitTest(model, 30, 25), "b1");
});

test("hitTest returns the topmost (last) overlapping shape", () => {
    const model = [
        { id: "under", type: "box", x: 10, y: 10, x2: 50, y2: 50 },
        { id: "over", type: "box", x: 20, y: 20, x2: 60, y2: 60 }
    ];
    assert.equal(hitTest(model, 30, 30), "over");
});

test("hitTest works on points-based (pen) shapes via bounding box", () => {
    const model = [{ id: "p1", type: "pen", points: [{ x: 0, y: 0 }, { x: 5, y: 30 }, { x: 40, y: 10 }] }];
    assert.equal(hitTest(model, 20, 15), "p1");
    assert.equal(hitTest(model, -100, -100), null);
});

// ---------------------------------------------------------------------------
// arrowHead geometry
// ---------------------------------------------------------------------------

test("arrowHead returns a 3-point barb with the tip at (x2,y2)", () => {
    const h = arrowHead(0, 0, 10, 0, 16, Math.PI / 7);
    assert.equal(h.length, 3);
    // tip is exact
    assert.deepEqual(h[1], { x: 10, y: 0 });
    // barbs are mirror images about the arrow axis (horizontal here)
    assert.ok(Math.abs(h[0].x - h[2].x) < 1e-9);
    assert.ok(Math.abs(h[0].y + h[2].y) < 1e-9);
    // barbs sit behind the tip
    assert.ok(h[0].x < h[1].x);
    // each barb is `size` away from the tip
    assert.ok(Math.abs(Math.hypot(h[0].x - 10, h[0].y - 0) - 16) < 1e-9);
    assert.ok(Math.abs(Math.hypot(h[2].x - 10, h[2].y - 0) - 16) < 1e-9);
});

test("arrowHead respects direction (vertical arrow)", () => {
    const h = arrowHead(0, 0, 0, 10, 16, Math.PI / 7);
    assert.deepEqual(h[1], { x: 0, y: 10 });
    // barbs mirror about the vertical axis and sit below the tip (smaller y)
    assert.ok(Math.abs(h[0].x + h[2].x) < 1e-9);
    assert.ok(h[0].y < h[1].y);
});

// ---------------------------------------------------------------------------
// nextStep
// ---------------------------------------------------------------------------

test("nextStep starts at 1 and increments past the max", () => {
    assert.equal(nextStep([]), 1);
    assert.equal(nextStep([{ type: "step", n: 1 }, { type: "step", n: 2 }]), 3);
    // ignores gaps + non-step shapes, uses max+1
    assert.equal(nextStep([{ type: "step", n: 1 }, { type: "step", n: 3 }, { type: "box" }]), 4);
});

// ---------------------------------------------------------------------------
// toMagickArgs
// ---------------------------------------------------------------------------

test("toMagickArgs emits -draw for a line and -blur for a blur region", () => {
    const model = [
        { type: "line", x: 1, y: 2, x2: 3, y2: 4, color: "#ff0000", width: 5 },
        { type: "blur", x: 0, y: 0, x2: 10, y2: 10 }
    ];
    const args = toMagickArgs(model, { x: 0, y: 0, width: 100, height: 100 });
    assert.ok(args.includes("-draw"), "should emit a -draw op");
    assert.ok(args.includes("-blur"), "should emit a -blur op");
    assert.ok(args.includes("#ff0000"), "should carry the stroke colour through");
    assert.ok(args.some(a => /^line \d/.test(a)), "should emit an IM 'line x,y x2,y2' draw");
});

test("toMagickArgs offsets coordinates by baseRect origin (crop-relative)", () => {
    const model = [{ type: "line", x: 30, y: 40, x2: 50, y2: 60, color: "#fff", width: 2 }];
    const args = toMagickArgs(model, { x: 10, y: 20, width: 100, height: 100 });
    assert.ok(args.includes("line 20,20 40,40"), "coords should be shifted by the baseRect origin");
});

test("toMagickArgs emits an arrow as a line plus a polyline head", () => {
    const model = [{ type: "arrow", x: 0, y: 0, x2: 20, y2: 0, color: "#0f0", width: 3 }];
    const args = toMagickArgs(model, { x: 0, y: 0 });
    assert.ok(args.some(a => /^line /.test(a)), "arrow shaft");
    assert.ok(args.some(a => /^polyline /.test(a)), "arrow head");
});

test("toMagickArgs renders a numbered step as a circle + the number text", () => {
    const model = [{ type: "step", x: 100, y: 100, color: "#00f", width: 3, n: 2 }];
    const args = toMagickArgs(model, { x: 0, y: 0 });
    assert.ok(args.some(a => /^circle /.test(a)), "step circle");
    assert.ok(args.some(a => /text .*'2'/.test(a)), "step number text");
});

// ---------------------------------------------------------------------------
// boundsOf (exported helper used by both hit-test and the QML selection box)
// ---------------------------------------------------------------------------

test("boundsOf normalises a reversed rectangle", () => {
    assert.deepEqual(boundsOf({ type: "box", x: 50, y: 40, x2: 10, y2: 10 }), { x: 10, y: 10, x2: 50, y2: 40 });
});
