pragma Singleton

// TASK ACTIONS SINGLETON — the panel's write API. Every mutation is queued as a
// JSON arg-array to ~/.cache/adhd/task-cmd; the host actuator (adhd-task-cmd.path
// → adhd-task-cmd.sh) runs `task <args>` with the host's 2.6.2 DB and re-exports
// the snapshot. Args are positional (never shell-parsed) so they're injection-safe.
//
//   TaskActions.modify(5, ["project:work", "+urgent", "due:tomorrow"])
//   TaskActions.done(3)        TaskActions.remove(7)
//   TaskActions.add("reply to Slack", ["project:work", "priority:H"])
//   TaskActions.annotate(5, "waiting on review")
//   TaskActions.startBlock("5")   // or "new:<description>"
//   TaskActions.stopBlock()

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    Process { id: proc }

    // Queue a raw taskwarrior command (array of string args).
    function cmd(args: var): void {
        const json = JSON.stringify(args);
        proc.command = ["sh", "-c",
            "printf '%s\\n' \"$1\" >> \"$HOME/.cache/adhd/task-cmd\"", "sh", json];
        proc.running = true;
    }

    // ── Convenience wrappers (extra = array of extra "key:val"/"+tag" args) ──
    function add(desc: string, extra: var): void {
        root.cmd(["add", desc].concat(extra || []));
    }
    function modify(id: int, fields: var): void {
        root.cmd(["modify", String(id)].concat(fields || []));
    }
    function done(id: int): void        { root.cmd(["done", String(id)]); }
    function remove(id: int): void      { root.cmd(["delete", String(id)]); }
    function annotate(id: int, text: string): void { root.cmd(["annotate", String(id), text]); }
    function setProject(id: int, p: string): void  { root.cmd(["modify", String(id), "project:" + (p || "")]); }
    function addTag(id: int, t: string): void      { root.cmd(["modify", String(id), "+" + t]); }
    function removeTag(id: int, t: string): void   { root.cmd(["modify", String(id), "-" + t]); }
    function setPriority(id: int, p: string): void { root.cmd(["modify", String(id), "priority:" + (p || "")]); }
    function setDue(id: int, d: string): void      { root.cmd(["modify", String(id), "due:" + (d || "")]); }

    // Start a deep-focus block (special path: sets the focus STATE via
    // adhd-focus.sh). req is a task id string, or "new:<description>".
    Process { id: blockProc }
    function startBlock(req: string): void {
        blockProc.command = ["sh", "-c",
            "printf '%s' \"$1\" > \"$HOME/.cache/adhd/start-request\"", "sh", req];
        blockProc.running = true;
    }

    Process { id: stopProc }
    function stopBlock(): void {
        stopProc.command = ["sh", "-c",
            "systemd-run --user --quiet --wait --pipe --collect /bin/bash -lc 'export PATH=\"$HOME/.local/bin:$PATH\"; adhd-focus.sh stop >/dev/null 2>&1; adhd-tasks-export.sh >/dev/null 2>&1' >/dev/null 2>&1 || true"];
        stopProc.running = true;
    }
}
