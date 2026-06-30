// Unit tests for the screenshot logic module.
// Run:  node --test modules/areapicker/shot.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";

import {
    monitorRect,
    clampRect,
    shotPath,
    notifyArgs,
    grimGeometry,
    grimCommand,
    dirOf
} from "./shot.js";

test("monitorRect: scale 1 returns physical size as screen-local origin", () => {
    assert.deepEqual(monitorRect({ x: 100, y: 50, width: 2560, height: 1440, scale: 1 }), { x: 0, y: 0, w: 2560, h: 1440 });
});

test("monitorRect: fractional scale converts physical -> logical pixels", () => {
    // 2560 / 1.25 = 2048 ; 1440 / 1.25 = 1152
    assert.deepEqual(monitorRect({ x: 0, y: 0, width: 2560, height: 1440, scale: 1.25 }), { x: 0, y: 0, w: 2048, h: 1152 });
});

test("monitorRect: missing scale defaults to 1", () => {
    assert.deepEqual(monitorRect({ width: 1920, height: 1080 }), { x: 0, y: 0, w: 1920, h: 1080 });
});

test("clampRect: rect fully inside is unchanged", () => {
    assert.deepEqual(clampRect({ x: 10, y: 20, w: 30, h: 40 }, { width: 1920, height: 1080 }), { x: 10, y: 20, w: 30, h: 40 });
});

test("clampRect: negative origin is clamped edge-based (right/bottom edges preserved)", () => {
    // left/top -> 0, right edge stays at 40/40 => w=h=40
    assert.deepEqual(clampRect({ x: -10, y: -10, w: 50, h: 50 }, { width: 100, height: 100 }), { x: 0, y: 0, w: 40, h: 40 });
});

test("clampRect: overflow past right/bottom is trimmed", () => {
    assert.deepEqual(clampRect({ x: 80, y: 90, w: 50, h: 50 }, { width: 100, height: 100 }), { x: 80, y: 90, w: 20, h: 10 });
});

test("clampRect: a rect entirely off-screen collapses to zero area", () => {
    assert.deepEqual(clampRect({ x: 200, y: 200, w: 50, h: 50 }, { width: 100, height: 100 }), { x: 100, y: 100, w: 0, h: 0 });
});

test("shotPath(0) -> default ~/Pictures/Screenshots, UTC epoch filename", () => {
    const p = shotPath(0);
    assert.equal(p, "~/Pictures/Screenshots/screenshot-19700101-000000.png");
    assert.ok(p.endsWith("/Pictures/Screenshots/screenshot-19700101-000000.png"));
});

test("shotPath: explicit pictures dir + zero-padded UTC timestamp", () => {
    const ms = Date.UTC(2026, 5, 30, 4, 5, 9); // 2026-06-30 04:05:09 UTC
    assert.equal(shotPath(ms, "/home/dev/Pictures"), "/home/dev/Pictures/Screenshots/screenshot-20260630-040509.png");
});

test("shotPath: trailing slash on pictures dir is normalised", () => {
    assert.equal(shotPath(0, "/home/dev/Pictures/"), "/home/dev/Pictures/Screenshots/screenshot-19700101-000000.png");
});

test("notifyArgs(path,true): includes all action buttons + image hint + copied body", () => {
    const args = notifyArgs("/home/dev/Pictures/Screenshots/x.png", true);
    assert.equal(args[0], "notify-send");
    assert.ok(args.includes("--action=open=Open"));
    assert.ok(args.includes("--action=edit=Edit"));
    assert.ok(args.includes("--action=copy=Copy path"));
    assert.ok(args.includes("--action=delete=Delete"));
    assert.ok(args.includes("/home/dev/Pictures/Screenshots/x.png"));
    assert.ok(args.includes("string:image-path:/home/dev/Pictures/Screenshots/x.png"));
    assert.ok(args.some(a => /copied/i.test(a)));
});

test("notifyArgs(path,false): saved-only body, still actionable", () => {
    const args = notifyArgs("/p/x.png", false);
    assert.ok(args.includes("--action=open=Open"));
    assert.ok(!args.some(a => /copied/i.test(a)));
    assert.ok(args.some(a => /saved/i.test(a)));
});

test("grimGeometry: '<x>,<y> <w>x<h>' with rounding", () => {
    assert.equal(grimGeometry({ x: 10.4, y: 20.6, w: 100.9, h: 50.1 }), "10,21 101x50");
});

test("grimCommand: mkdir -p parent then grim -g to outPath", () => {
    const cmd = grimCommand({ x: 0, y: 0, w: 1920, h: 1080 }, "/home/dev/Pictures/Screenshots/s.png");
    assert.deepEqual(cmd, ["sh", "-c", "mkdir -p '/home/dev/Pictures/Screenshots' && grim -g '0,0 1920x1080' '/home/dev/Pictures/Screenshots/s.png'"]);
});

test("dirOf: returns parent directory", () => {
    assert.equal(dirOf("/a/b/c.png"), "/a/b");
    assert.equal(dirOf("/c.png"), "/");
});
