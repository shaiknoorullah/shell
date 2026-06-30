pragma Singleton

// ACTIVE-TASK SINGLETON — current taskwarrior task + live timewarrior elapsed
// (pattern: caelestia Process + Timer poll, see services/Weather.qml)
//
// Wraps `qs-active.sh` which prints:  {"task":"boolgen otel","elapsed":"0:42:11"}
// `task` is "—" when nothing is active; `elapsed` is "0:00:00" when idle.
// Polled every 1 s so the elapsed clock in the bottom + left bars ticks live
// (timewarrior owns the true duration; we just re-read it).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string task: "—"
    property string elapsed: "0:00:00"
    readonly property bool active: task !== "—" && task.length > 0

    function refresh(): void {
        proc.running = true;
    }

    Process {
        id: proc

        command: ["sh", "-c", "qs-active.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text.trim());
                    root.task = o.task ?? "—";
                    root.elapsed = o.elapsed ?? "0:00:00";
                } catch (e) {
                    // keep last good
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
