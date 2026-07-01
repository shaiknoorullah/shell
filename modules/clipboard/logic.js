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

// Shannon entropy (bits/char) — used by the secret heuristic below.
function shannonEntropy(s) {
    const freq = {};
    for (const c of s)
        freq[c] = (freq[c] || 0) + 1;
    let e = 0;
    const n = s.length;
    for (const k in freq) {
        const p = freq[k] / n;
        e -= p * Math.log2(p);
    }
    return e;
}

// Is `text` likely a secret (password / API key / token / private key)?
// `hint` is an explicit clipboard mime hint (e.g. "secret" from a password
// manager); when present it wins. Otherwise fall back to shape + entropy checks.
// Pure + node-tested; drives masking in the overlay.
function detectSensitive(text, hint) {
    if (hint === "secret" || hint === "password" || hint === "sensitive")
        return true;
    const s = String(text);
    if (!s)
        return false;
    if (/-----BEGIN [A-Z ]*PRIVATE KEY-----/.test(s))
        return true;
    const t = s.trim();
    if (/^eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(t))
        return true; // JWT
    if (/\b(AKIA|ASIA)[0-9A-Z]{16}\b/.test(s))
        return true; // AWS access key id
    if (/\bgh[pousr]_[A-Za-z0-9]{36,}\b/.test(s))
        return true; // GitHub token
    if (/\bglpat-[A-Za-z0-9_-]{20,}\b/.test(s))
        return true; // GitLab PAT
    if (/\bsk-[A-Za-z0-9]{20,}\b/.test(s))
        return true; // OpenAI-style key
    if (/\bxox[baprs]-[A-Za-z0-9-]{10,}\b/.test(s))
        return true; // Slack token
    // Heuristic: a single whitespace-free token of decent length with mixed
    // character classes and high entropy looks like a random secret, not prose
    // (prose has spaces → excluded).
    if (!/\s/.test(t) && t.length >= 12 && t.length <= 256) {
        const classes = [/[a-z]/, /[A-Z]/, /[0-9]/, /[^A-Za-z0-9]/].filter(re => re.test(t)).length;
        if (classes >= 3 && shannonEntropy(t) >= 3.5)
            return true;
    }
    return false;
}

// A masked label for a secret — never exposes the value.
function maskSecret(text) {
    return "•••••••• · secret · " + String(text).length + " chars";
}

// Has an entry copied at `tsMs` outlived its TTL as of `nowMs`? Strict > so an
// entry exactly at the TTL boundary is not yet expired.
function isExpired(tsMs, nowMs, ttlMs) {
    return (nowMs - tsMs) > ttlMs;
}

// Select the raws to delete: unpinned entries whose recorded ts is older than
// the TTL. Entries without a numeric ts are skipped (safe — unknown age is never
// pruned; the prune script backfills their ts on first sighting). `pinned` may be
// a Set or an array of pinned raws.
function prunable(entries, pinned, nowMs, ttlMs) {
    const isPinned = raw => pinned instanceof Set ? pinned.has(raw) : Array.isArray(pinned) ? pinned.indexOf(raw) >= 0 : false;
    const out = [];
    for (const e of (entries || [])) {
        if (isPinned(e.raw))
            continue;
        if (typeof e.ts !== "number")
            continue;
        if (isExpired(e.ts, nowMs, ttlMs))
            out.push(e.raw);
    }
    return out;
}
