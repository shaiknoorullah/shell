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
const dataUrl = "data:text/javascript," + encodeURIComponent(`${src}\nexport { parseList, detectType, relTime, fuzzy };`);
const { parseList, detectType, relTime, fuzzy } = await import(dataUrl);

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
