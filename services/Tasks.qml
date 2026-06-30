pragma Singleton

// TASKS SINGLETON — the panel's read model, from the HOST-exported snapshots
// (the container's taskwarrior 3.x can't read the host's 2.6.2 data, so
// adhd-tasks-export.sh writes JSON the host side and we just `cat` it).
//
//   tasks.json  -> all PENDING tasks, full fields (id, description, project,
//                  tags[], priority, due, scheduled, urgency, annotations[], start?)
//   done.json   -> recently completed (for Reports)
//
// Exposes:
//   all       — full pending task objects (active-first, then urgency desc)
//   items     — left-bar subset { id, description, active, project, urgency } capped
//   done      — completed task objects
//   projects  — [{ name, count }]  derived
//   tags      — [{ name, count }]  derived

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var all: []
    property var items: []
    property var done: []

    readonly property var projects: root._group(root.all, t => t.project)
    readonly property var tags: {
        const counts = ({});
        for (const t of root.all)
            for (const tag of (t.tags || []))
                counts[tag] = (counts[tag] || 0) + 1;
        return Object.keys(counts).map(k => ({ name: k, count: counts[k] }))
            .sort((a, b) => b.count - a.count);
    }

    function _group(arr: var, keyFn: var): var {
        const counts = ({});
        for (const t of arr) {
            const k = keyFn(t);
            if (k)
                counts[k] = (counts[k] || 0) + 1;
        }
        return Object.keys(counts).map(k => ({ name: k, count: counts[k] }))
            .sort((a, b) => b.count - a.count);
    }

    function refresh(): void {
        pendingProc.running = true;
        doneProc.running = true;
    }

    Process {
        id: pendingProc
        command: ["sh", "-c", "cat \"$HOME/.cache/adhd/tasks.json\" 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(text.trim() || "[]");
                    arr.sort((a, b) => {
                        const aa = a.start != null, ba = b.start != null;
                        if (aa !== ba)
                            return aa ? -1 : 1;
                        return (b.urgency || 0) - (a.urgency || 0);
                    });
                    root.all = arr;
                    root.items = arr.map(t => ({
                        id: t.id,
                        description: t.description ?? "",
                        active: t.start != null,
                        project: t.project ?? "",
                        urgency: t.urgency ?? 0
                    })).slice(0, 6);
                } catch (e) {
                    root.all = [];
                    root.items = [];
                }
            }
        }
    }

    Process {
        id: doneProc
        command: ["sh", "-c", "cat \"$HOME/.cache/adhd/done.json\" 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.done = JSON.parse(text.trim() || "[]");
                } catch (e) {
                    root.done = [];
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
