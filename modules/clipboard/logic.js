.pragma library

// Pure, QML-JS-safe helpers for the clipboard overlay.
//
// This file follows caelestia's JavaScript-resource convention (see
// utils/scripts/fuzzysort.js + fzf.js): `.pragma library` on the first line and
// plain top-level function declarations. QML consumes it with
// `import "logic.js" as Logic` and calls `Logic.parseList(...)` etc.
//
// It is unit-tested by logic.test.mjs (`node --test`), which loads this file in
// a sandbox after stripping the QML-only `.pragma library` directive. Keep every
// function free of QML/Qt/node APIs so it stays valid in both environments.

// Split `cliphist list` output into entries. Each line is `<id>\t<preview>`.
// Returns [{ id, raw, preview }]. `raw` is the full original line, which is what
// `cliphist decode`/`cliphist delete` expect on stdin.
function parseList(text) {
    const out = [];
    for (const line of String(text).split("\n")) {
        if (!line)
            continue;
        const tab = line.indexOf("\t");
        if (tab < 0)
            continue;
        out.push({
            id: line.slice(0, tab),
            raw: line,
            preview: line.slice(tab + 1)
        });
    }
    return out;
}

// Classify a preview string into a coarse content type used to pick rendering +
// actions. Order matters: image > link > color > code > text.
function detectType(preview) {
    const p = String(preview);
    // cliphist renders binaries as "binary data image/png" (older) or
    // "[[ binary data 45 KiB png 1920x1080 ]]" (newer). Treat any binary blob as
    // an image — that is by far the common clipboard binary, and the preview pane
    // degrades gracefully if a decode is not actually an image.
    if (/^\s*(\[\[\s*)?binary data\b/i.test(p))
        return "image";
    const t = p.trim();
    if (/^https?:\/\/\S+$/.test(t))
        return "link";
    if (/^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(t))
        return "color";
    if (/[;{}=]|=>|\bfunction\b|\bconst\b|\bdef\b/.test(p))
        return "code";
    return "text";
}

// Human-friendly relative time. `t` and `now` are unix seconds.
function relTime(t, now) {
    const d = Math.max(0, Math.floor(now - t));
    if (d < 45)
        return "just now";
    if (d < 3600)
        return Math.round(d / 60) + "m ago";
    if (d < 86400)
        return Math.round(d / 3600) + "h ago";
    return Math.round(d / 86400) + "d ago";
}

// Case-insensitive subsequence fuzzy filter. Empty query returns items as-is.
// `keyFn(item)` yields the string to match against.
function fuzzy(query, items, keyFn) {
    const q = String(query).toLowerCase();
    if (!q)
        return items;
    return items.filter(it => {
        const s = String(keyFn(it)).toLowerCase();
        let i = 0;
        for (const ch of s)
            if (ch === q[i])
                i++;
        return i === q.length;
    });
}
