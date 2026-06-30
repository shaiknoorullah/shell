// Unit tests for modules/pin/pin.js — run with:  node --test modules/pin/pin.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import {
    clamp,
    nextId,
    addPin,
    removePin,
    stripFileScheme,
    fitScale,
    dimensions,
    scaleFromCorner,
    sliderToOpacity,
    opacityToSlider,
    centerOffset,
    clampPosition
} from "./pin.js";

test("clamp keeps value in range", () => {
    assert.equal(clamp(5, 0, 10), 5);
    assert.equal(clamp(-1, 0, 10), 0);
    assert.equal(clamp(11, 0, 10), 10);
    assert.equal(clamp(5, 0, 0), 0);
    // tolerates inverted range
    assert.equal(clamp(5, 10, 0), 10);
});

test("nextId is monotonic and handles empty/gappy lists", () => {
    assert.equal(nextId([]), 1);
    assert.equal(nextId([{ id: 1 }, { id: 2 }]), 3);
    assert.equal(nextId([{ id: 7 }, { id: 3 }]), 8); // max + 1, not length + 1
    assert.equal(nextId([{ path: "x" }]), 1); // ignores entries without numeric id
});

test("addPin appends an {id,path} object and is immutable", () => {
    const a = [];
    const b = addPin(a, "/tmp/one.png", 1);
    assert.deepEqual(a, []); // original untouched
    assert.deepEqual(b, [{ id: 1, path: "/tmp/one.png" }]);
    const c = addPin(b, "/tmp/two.png", 2);
    assert.equal(c.length, 2);
    // existing object reference is preserved (Variants delegate stability)
    assert.equal(c[0], b[0]);
});

test("addPin supports the same path pinned twice with distinct ids", () => {
    let pins = [];
    pins = addPin(pins, "/tmp/dup.png", nextId(pins));
    pins = addPin(pins, "/tmp/dup.png", nextId(pins));
    assert.equal(pins.length, 2);
    assert.notEqual(pins[0].id, pins[1].id);
    assert.notEqual(pins[0], pins[1]); // distinct object identities
});

test("removePin removes only the matching id and preserves others", () => {
    const pins = [{ id: 1, path: "a" }, { id: 2, path: "b" }, { id: 3, path: "c" }];
    const out = removePin(pins, 2);
    assert.deepEqual(out.map(p => p.id), [1, 3]);
    assert.equal(out[0], pins[0]); // reference preserved
    assert.equal(out[1], pins[2]);
    // removing a non-existent id is a no-op (new array, same contents)
    assert.deepEqual(removePin(pins, 99).map(p => p.id), [1, 2, 3]);
});

test("stripFileScheme handles bare paths and file URIs", () => {
    assert.equal(stripFileScheme("/tmp/a.png"), "/tmp/a.png");
    assert.equal(stripFileScheme("file:///tmp/a.png"), "/tmp/a.png");
    assert.equal(stripFileScheme("file://localhost/tmp/a.png"), "/tmp/a.png");
    assert.equal(stripFileScheme(""), "");
    assert.equal(stripFileScheme(null), "");
});

test("fitScale never upscales and preserves aspect", () => {
    // image smaller than bounds -> stays 1:1
    assert.equal(fitScale(100, 100, 800, 600), 1);
    // wide image limited by width
    assert.equal(fitScale(2000, 1000, 1000, 1000), 0.5);
    // tall image limited by height
    assert.equal(fitScale(1000, 2000, 1000, 1000), 0.5);
    // degenerate inputs -> safe default
    assert.equal(fitScale(0, 0, 800, 600), 1);
    assert.equal(fitScale(100, 100, 0, 600), 1);
});

test("dimensions rounds and never goes below 1px", () => {
    assert.deepEqual(dimensions(1920, 1080, 0.5), { width: 960, height: 540 });
    assert.deepEqual(dimensions(3, 3, 0.1), { width: 1, height: 1 }); // floor would be 0; clamped to 1
});

test("scaleFromCorner uses larger axis, preserves aspect, clamps", () => {
    // pointer at natural bottom-right => scale 1
    assert.equal(scaleFromCorner(1000, 500, 1000, 500, 0.1, 4), 1);
    // dragging mostly along x grows by x
    assert.equal(scaleFromCorner(2000, 500, 1000, 500, 0.1, 4), 2);
    // clamps to max
    assert.equal(scaleFromCorner(99999, 99999, 1000, 500, 0.1, 4), 4);
    // clamps to min
    assert.equal(scaleFromCorner(1, 1, 1000, 500, 0.25, 4), 0.25);
    // degenerate natural size -> min
    assert.equal(scaleFromCorner(100, 100, 0, 0, 0.2, 4), 0.2);
});

test("slider <-> opacity mapping is consistent", () => {
    assert.equal(sliderToOpacity(1), 1);
    assert.equal(sliderToOpacity(0), 0.15);
    assert.ok(Math.abs(sliderToOpacity(0.5) - 0.575) < 1e-9);
    // clamps out-of-range slider values
    assert.equal(sliderToOpacity(2), 1);
    assert.equal(sliderToOpacity(-1), 0.15);
    // round trip
    for (const op of [0.15, 0.4, 0.8, 1]) {
        assert.ok(Math.abs(sliderToOpacity(opacityToSlider(op)) - op) < 1e-9);
    }
    assert.equal(opacityToSlider(1), 1);
    assert.equal(opacityToSlider(0.15), 0);
});

test("centerOffset centers and never returns negative margins", () => {
    assert.deepEqual(centerOffset(800, 600, 1920, 1080), { x: 560, y: 240 });
    // window larger than screen -> clamped to 0
    assert.deepEqual(centerOffset(4000, 4000, 1920, 1080), { x: 0, y: 0 });
});

test("clampPosition keeps top-left on-screen as non-negative ints", () => {
    assert.deepEqual(clampPosition(100, 100, 400, 300, 1920, 1080), { x: 100, y: 100 });
    // negative -> 0 (layer-shell margins are non-negative)
    assert.deepEqual(clampPosition(-50, -50, 400, 300, 1920, 1080), { x: 0, y: 0 });
    // beyond right/bottom -> clamped so keepVisible px remain reachable
    assert.deepEqual(clampPosition(5000, 5000, 400, 300, 1920, 1080, 64), { x: 1856, y: 1016 });
    // fractional input is rounded
    assert.deepEqual(clampPosition(10.6, 20.4, 400, 300, 1920, 1080), { x: 11, y: 20 });
});
