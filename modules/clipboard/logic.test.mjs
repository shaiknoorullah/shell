import assert from "node:assert/strict";
import { test } from "node:test";
import { readFileSync } from "node:fs";

// logic.js is a QML JavaScript resource: its first line is the QML-only
// `.pragma library` directive, which is not valid ECMAScript, so it cannot be
// `import`ed directly. Load it the way a unit test must: read the source, strip
// the QML directive, append ES-module exports, and import it as a same-realm
// `data:` module so the objects it returns share this file's intrinsics (needed
// for deepStrictEqual prototype checks).
const src = readFileSync(new URL("./logic.js", import.meta.url), "utf8").replace(/^\s*\.pragma\s+library\s*$/m, "");
const dataUrl = "data:text/javascript," + encodeURIComponent(`${src}\nexport { parseList, detectType, relTime, fuzzy, detectSensitive, maskSecret, isExpired, prunable };`);
const { parseList, detectType, relTime, fuzzy, detectSensitive, maskSecret, isExpired, prunable } = await import(dataUrl);

test("parseList splits id and preview on first tab", () => {
    const out = parseList("12\thello world\n11\tbinary data image/png\n");
    assert.deepEqual(out, [
        { id: "12", raw: "12\thello world", preview: "hello world" },
        { id: "11", raw: "11\tbinary data image/png", preview: "binary data image/png" }
    ]);
});

test("parseList ignores blank lines", () => {
    assert.equal(parseList("\n\n").length, 0);
});

test("parseList keeps tabs inside the preview", () => {
    const out = parseList("7\ta\tb\tc");
    assert.deepEqual(out, [{ id: "7", raw: "7\ta\tb\tc", preview: "a\tb\tc" }]);
});

test("detectType classifies", () => {
    assert.equal(detectType("binary data image/png"), "image");
    assert.equal(detectType("[[ binary data 45 KiB png 1920x1080 ]]"), "image");
    assert.equal(detectType("https://example.com/x"), "link");
    assert.equal(detectType("#1e90ff"), "color");
    assert.equal(detectType("1e90ff"), "color");
    assert.equal(detectType("const x = () => 1"), "code");
    assert.equal(detectType("just a note"), "text");
});

test("relTime formats", () => {
    assert.equal(relTime(1000, 1000), "just now");
    assert.equal(relTime(1000, 1000 + 120), "2m ago");
    assert.equal(relTime(1000, 1000 + 7200), "2h ago");
    assert.equal(relTime(1000, 1000 + 2 * 86400), "2d ago");
});

test("fuzzy subsequence, case-insensitive", () => {
    const items = [{ p: "Hello World" }, { p: "goodbye" }];
    assert.deepEqual(fuzzy("hlo", items, i => i.p), [{ p: "Hello World" }]);
    assert.deepEqual(fuzzy("", items, i => i.p), items);
});

test("detectSensitive flags secrets + hint, not prose", () => {
    assert.equal(detectSensitive("", "secret"), true);
    assert.equal(detectSensitive("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.abc123DEFxyz", ""), true);
    assert.equal(detectSensitive("AKIA1234567890ABCDEF", ""), true);
    assert.equal(detectSensitive("ghp_" + "a".repeat(36), ""), true);
    assert.equal(detectSensitive("sk-" + "b".repeat(40), ""), true);
    assert.equal(detectSensitive("-----BEGIN OPENSSH PRIVATE KEY-----", ""), true);
    assert.equal(detectSensitive("Xk9$mP2qLz#7Wn4v", ""), true);
    assert.equal(detectSensitive("just a normal sentence here", ""), false);
    assert.equal(detectSensitive("hunter", ""), false);
    assert.equal(detectSensitive("https://example.com/path", ""), false);
});

test("maskSecret hides value, shows char count", () => {
    const m = maskSecret("abcdefghijklmnopqrstuvwx");
    assert.ok(m.includes("secret"));
    assert.ok(m.includes("24"));
    assert.ok(!m.includes("abcdef"));
});

test("isExpired boundary (strict >)", () => {
    const ttl = 1000;
    assert.equal(isExpired(0, ttl + 1, ttl), true);
    assert.equal(isExpired(0, ttl - 1, ttl), false);
    assert.equal(isExpired(0, ttl, ttl), false);
});

test("prunable returns only unpinned expired raws", () => {
    const now = 100000, ttl = 1000;
    const entries = [
        { raw: "pinned-old", ts: 0 },
        { raw: "old", ts: 0 },
        { raw: "fresh", ts: now - 10 },
        { raw: "no-ts" }
    ];
    assert.deepEqual(prunable(entries, new Set(["pinned-old"]), now, ttl), ["old"]);
});
