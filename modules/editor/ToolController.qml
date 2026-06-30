pragma ComponentBehavior: Bound

import QtQuick

// Holds the active tool + colour + stroke width, and builds the in-progress
// "draft" shape for drag tools. createDraft/updateDraft return NEW objects so
// QML's reactive bindings on `shape` re-evaluate (never mutate in place).
QtObject {
    id: root

    property string tool: "pen"
    property color color: "#ff3b30"
    property real width: 4

    readonly property var dragTools: ["pen", "line", "arrow", "box", "ellipse", "highlight", "blur"]

    function isDrag(): bool {
        return root.dragTools.indexOf(root.tool) >= 0;
    }
    function isClickTool(): bool {
        return root.tool === "text" || root.tool === "step";
    }
    function isSelect(): bool {
        return root.tool === "select";
    }
    function isCrop(): bool {
        return root.tool === "crop";
    }

    function newId(): string {
        return Date.now().toString(36) + "-" + Math.floor(Math.random() * 1e6).toString(36);
    }

    // Seed a new draft shape for the current drag tool at (x,y).
    function createDraft(x: real, y: real): var {
        const base = {
            id: root.newId(),
            type: root.tool,
            color: String(root.color),
            width: root.width
        };
        if (root.tool === "pen" || root.tool === "highlight") {
            base.points = [{ x, y }];
        } else {
            base.x = x;
            base.y = y;
            base.x2 = x;
            base.y2 = y;
        }
        return base;
    }

    // Return a NEW draft reflecting the drag's current point.
    function updateDraft(draft: var, x: real, y: real): var {
        if (!draft)
            return null;
        if (draft.type === "pen" || draft.type === "highlight")
            return Object.assign({}, draft, { points: draft.points.concat([{ x, y }]) });
        return Object.assign({}, draft, { x2: x, y2: y });
    }
}
