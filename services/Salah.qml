pragma Singleton

// SALAH SINGLETON — the five daily prayers + their done/now/next state
// (pattern: caelestia FileView watch + a SystemClock tick, see Time.qml; plus
//  a small Process to read the conf without baking a path-walk into QML.)
//
// Source of truth: ~/.config/adhd/prayer-times.conf — IQAMAH (congregation)
// times the focus daemon scaffolds blocks around. Format (one prayer/line):
//   Fajr 05:12    # adhan 05:01 · absolute
//   Dhuhr 13:30   # ...
//   Asr 16:42     # ...
//   Maghrib 19:08 # ...
//   Isha 20:30    # ...
// (comments after `#` ignored; we take the first two whitespace tokens.)
//
// We expose `prayers` as a list of { name, time, state } where state ∈
// {"done","next","upcoming"} computed against the wall clock:
//   * the FIRST prayer still in the future is "next"
//   * everything before it today is "done"
//   * everything after "next" is "upcoming"
// Recomputed on every minute tick (SystemClock) and whenever the conf changes.
//
// Display name note: the mockup writes ʿAsr with the ʿayn; the conf stores
// plain "Asr". We pretty-print Asr -> "ʿAsr" for the strip only.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Each entry: { name: string, time: string("HH:MM"), minutes: int, state: string }
    property var prayers: []
    readonly property var nextPrayer: {
        for (const p of root.prayers)
            if (p.state === "next")
                return p;
        return null;
    }

    function prettyName(n: string): string {
        return n === "Asr" ? "ʿAsr" : n;
    }

    // Parse the raw conf text into ordered {name,time,minutes} (no state yet).
    function parse(raw: string): void {
        const out = [];
        const order = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
        const byName = {};
        for (const lineRaw of raw.split("\n")) {
            const line = lineRaw.trim();
            if (!line || line[0] === "#")
                continue;
            const toks = line.split(/\s+/);
            const name = toks[0];
            const time = toks[1];
            if (!name || !time || !/^\d{1,2}:\d{2}$/.test(time))
                continue;
            const hm = time.split(":");
            byName[name] = {
                name: name,
                time: time,
                minutes: parseInt(hm[0]) * 60 + parseInt(hm[1])
            };
        }
        for (const n of order)
            if (byName[n])
                out.push(byName[n]);
        root._parsed = out;
        root.recompute();
    }

    property var _parsed: []

    // Apply done/next/upcoming against the current minute-of-day.
    function recompute(): void {
        const now = new Date();
        const nowMin = now.getHours() * 60 + now.getMinutes();
        let nextFound = false;
        const out = [];
        for (const p of root._parsed) {
            let state;
            if (p.minutes <= nowMin) {
                state = "done";
            } else if (!nextFound) {
                state = "next";
                nextFound = true;
            } else {
                state = "upcoming";
            }
            out.push({
                name: p.name,
                display: root.prettyName(p.name),
                time: p.time,
                minutes: p.minutes,
                state: state
            });
        }
        root.prayers = out;
    }

    // Read the conf (cat is enough; avoids a path-walk in QML). Re-read when the
    // FileView fires onFileChanged (daily regeneration by the timer).
    Process {
        id: proc

        command: ["sh", "-c", "cat \"$HOME/.config/adhd/prayer-times.conf\" 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function reload(): void {
        proc.running = true;
    }

    FileView {
        path: `${Quickshell.env("HOME")}/.config/adhd/prayer-times.conf`
        watchChanges: true
        onFileChanged: root.reload()
        onLoaded: root.reload()
    }

    // Recompute the done/next split every minute so the strip advances.
    SystemClock {
        precision: SystemClock.Minutes
        onDateChanged: root.recompute()
    }

    Component.onCompleted: root.reload()
}
