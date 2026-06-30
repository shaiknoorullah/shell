pragma Singleton

// CONTEXT SINGLETON — current ADHD context + Dracula accent
// (pattern: caelestia Process + Timer poll, see services/Weather.qml)
//
// Wraps `qs-ctx.sh` which prints:  {"ctx":"work","accent":"#bd93f9"}
// Exposes `ctx` (string) and `accent` (color). The accent is also resolvable
// from Theme.accentFor(ctx) — we prefer the script's value but fall back to the
// Theme map so the bar always has a sane colour.
//
// Poll cadence: context changes rarely (on adhd-start/adhd-capture), so 5 s is
// plenty; a future deflisten on the ctx file could replace the Timer.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property string ctx: "personal"
    property color accent: Theme.green

    function refresh(): void {
        proc.running = true;
    }

    Process {
        id: proc

        command: ["sh", "-c", "qs-ctx.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text.trim());
                    if (o.ctx)
                        root.ctx = o.ctx;
                    // Prefer the script's accent; fall back to the Theme map.
                    root.accent = o.accent ? o.accent : Theme.accentFor(root.ctx);
                } catch (e) {
                    // Malformed output: keep last known good values.
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
