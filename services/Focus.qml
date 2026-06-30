pragma Singleton

// FOCUS SINGLETON — Flowtime deep-block status (count-up, prayer-scaffolded)
// (pattern: caelestia Process + Timer poll, see services/Weather.qml)
//
// Wraps `adhd-focus.sh status` which prints PLAIN TEXT, one line:
//   idle · → Dhuhr 13:30
//   block 47m · → ʿAsr 16:42
//
// We surface the raw line (`status`) plus parsed pieces the LEFT bar's big
// timer needs:
//   * running        — true when a block is open ("block …" vs "idle …")
//   * blockMinutes    — minutes elapsed in the current block (0 when idle)
//   * nextPrayerName  — e.g. "ʿAsr"  (or "Fajr (tmrw)")
//   * nextPrayerTime  — e.g. "16:42"
//
// There is NO pomodoro and NO force-stop — blocks count UP. The big timer in
// the left bar is informational + calming, never a countdown that scolds.
// The precise live elapsed (HH:MM:SS) comes from ActiveTask.elapsed; this
// service supplies the salah runway + the idle/running state.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string status: "idle"
    property bool running: false
    property int blockMinutes: 0
    property string nextPrayerName: ""
    property string nextPrayerTime: ""

    function refresh(): void {
        proc.running = true;
    }

    Process {
        id: proc

        command: ["sh", "-c", "adhd-focus.sh status"]

        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                if (!line)
                    return;
                root.status = line;

                // "block 47m · → ʿAsr 16:42"  or  "idle · → Dhuhr 13:30"
                root.running = line.indexOf("block") === 0;

                const mins = line.match(/block\s+(\d+)m/);
                root.blockMinutes = mins ? parseInt(mins[1]) : 0;

                // Everything after the arrow is "<Name> <HH:MM>" (Name may have
                // a trailing "(tmrw)"). Split on the last whitespace before a
                // HH:MM, else keep the whole tail as the name.
                const arrow = line.split("→");
                if (arrow.length > 1) {
                    const tail = arrow[1].trim();
                    const t = tail.match(/(\d{1,2}:\d{2})\s*$/);
                    if (t) {
                        root.nextPrayerTime = t[1];
                        root.nextPrayerName = tail.slice(0, tail.length - t[1].length).trim();
                    } else {
                        root.nextPrayerName = tail;
                        root.nextPrayerTime = "";
                    }
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
