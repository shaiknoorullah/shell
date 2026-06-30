pragma Singleton

// STATS SINGLETON — shame-free daily consistency stats
// (pattern: caelestia Process + Timer poll, see services/Weather.qml)
//
// Wraps `qs-stats.sh` which prints (all keys always present):
//   {"focus_score":84,"streak":12,"coffee":2,"walks":3,"encourage":"…"}
//
// SHAME-FREE CONTRACT: the script guarantees non-negative numbers and warm,
// never-scolding `encourage` copy (a streak of 0 => "a fresh start today").
// This service NEVER recomputes or reframes — it surfaces the script verbatim.
// The bottom bar renders these positively (a focus RING, a STREAK count with a
// flame, coffee/walks tallies, an encouragement line) — no red, no penalties.
//
// Polled every 30 s — these move slowly and there is no urgency to them.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int focusScore: 0
    property int streak: 0
    property int coffee: 0
    property int walks: 0
    property string encourage: "✦ a fresh start today"

    function refresh(): void {
        proc.running = true;
    }

    Process {
        id: proc

        command: ["sh", "-c", "qs-stats.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text.trim());
                    root.focusScore = o.focus_score ?? 0;
                    root.streak = o.streak ?? 0;
                    root.coffee = o.coffee ?? 0;
                    root.walks = o.walks ?? 0;
                    if (o.encourage)
                        root.encourage = o.encourage;
                } catch (e) {
                    // keep last good
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
