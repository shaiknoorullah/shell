pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "shapes" as Shapes
import "editor.js" as EditorLogic

// The editor working area: base PNG (zoom-to-fit) + an ordered annotation model
// rendered as QML shapes, driven by a ToolController + a routing MouseArea, with
// an editor.js-backed undo/redo command stack.
Item {
    id: root

    property string path: ""

    signal requestClose
    signal requestExport(var source)

    // --- annotation model + history -----------------------------------------
    property var model: []
    property var draft: null
    property string selectedId: ""
    readonly property var stack: EditorLogic.CommandStack()
    property bool canUndo: false
    property bool canRedo: false

    function syncHistoryFlags(): void {
        root.canUndo = root.stack.canUndo;
        root.canRedo = root.stack.canRedo;
    }
    function commitModel(next: var): void {
        root.model = next;
        root.stack.push(next);
        root.syncHistoryFlags();
    }
    function undo(): void {
        root.model = root.stack.undo();
        root.selectedId = "";
        root.syncHistoryFlags();
    }
    function redo(): void {
        root.model = root.stack.redo();
        root.selectedId = "";
        root.syncHistoryFlags();
    }
    function deleteSelected(): void {
        if (!root.selectedId)
            return;
        root.commitModel(root.model.filter(s => s.id !== root.selectedId));
        root.selectedId = "";
    }
    function moveSelected(dx: real, dy: real): void {
        if (!root.selectedId)
            return;
        root.model = root.model.map(s => {
            if (s.id !== root.selectedId)
                return s;
            const o = Object.assign({}, s);
            if (o.x !== undefined)
                o.x += dx;
            if (o.y !== undefined)
                o.y += dy;
            if (o.x2 !== undefined)
                o.x2 += dx;
            if (o.y2 !== undefined)
                o.y2 += dy;
            if (o.points)
                o.points = o.points.map(p => ({ x: p.x + dx, y: p.y + dy }));
            return o;
        });
    }

    // --- geometry / zoom-to-fit ---------------------------------------------
    readonly property real fitMargin: 112 // headroom for the toolbar
    readonly property real availW: Math.max(1, width - fitMargin)
    readonly property real availH: Math.max(1, height - fitMargin)
    readonly property real imgW: baseImage.sourceSize.width
    readonly property real imgH: baseImage.sourceSize.height
    readonly property real fitScale: (imgW > 0 && imgH > 0) ? Math.min(availW / imgW, availH / imgH, 1) : 1

    readonly property alias captureTarget: imageContainer
    // Hide editor-only chrome (selection box, crop border/handles) during the
    // export grab so it is not baked into the output PNG. Toggled by Editor.qml
    // around CUtils.saveItem (grabToImage) and reset in the save callback.
    property bool grabbing: false

    // --- crop (non-destructive). null => full image. ------------------------
    property var cropRect: null // normalised {x,y,x2,y2} in container coords

    function exportRect(): rect {
        if (root.cropRect) {
            const x = Math.min(root.cropRect.x, root.cropRect.x2);
            const y = Math.min(root.cropRect.y, root.cropRect.y2);
            return Qt.rect(x, y, Math.abs(root.cropRect.x2 - root.cropRect.x), Math.abs(root.cropRect.y2 - root.cropRect.y));
        }
        return Qt.rect(0, 0, imageContainer.width, imageContainer.height);
    }
    function setCropCorner(i: int, nx: real, ny: real): void {
        if (!root.cropRect)
            return;
        const c = Object.assign({}, root.cropRect);
        if (i === 0) {
            c.x = nx;
            c.y = ny;
        } else if (i === 1) {
            c.x2 = nx;
            c.y = ny;
        } else if (i === 2) {
            c.x = nx;
            c.y2 = ny;
        } else {
            c.x2 = nx;
            c.y2 = ny;
        }
        root.cropRect = c;
    }
    function normaliseCrop(): void {
        if (!root.cropRect)
            return;
        const c = root.cropRect;
        root.cropRect = {
            x: Math.min(c.x, c.x2),
            y: Math.min(c.y, c.y2),
            x2: Math.max(c.x, c.x2),
            y2: Math.max(c.y, c.y2)
        };
    }

    // --- export helpers consumed by Editor.qml ------------------------------
    function basePath(): string {
        return root.path;
    }
    function baseRect(): rect {
        return Qt.rect(0, 0, root.imgW, root.imgH);
    }
    // The model expressed in native base-image pixels (for the IM fallback).
    function nativeModel(): var {
        const s = root.fitScale > 0 ? 1 / root.fitScale : 1;
        const sp = p => ({ x: p.x * s, y: p.y * s });
        return (root.model || []).map(sh => {
            const o = Object.assign({}, sh);
            if (o.x !== undefined)
                o.x *= s;
            if (o.y !== undefined)
                o.y *= s;
            if (o.x2 !== undefined)
                o.x2 *= s;
            if (o.y2 !== undefined)
                o.y2 *= s;
            if (o.points)
                o.points = o.points.map(sp);
            return o;
        });
    }

    // --- text entry ---------------------------------------------------------
    property bool editingText: false
    property real textX: 0
    property real textY: 0

    function beginText(x: real, y: real): void {
        root.textX = x;
        root.textY = y;
        textField.text = "";
        root.editingText = true;
        textField.forceActiveFocus();
    }
    function commitText(): void {
        if (root.editingText && textField.text.length > 0) {
            root.commitModel(root.model.concat([{
                        id: controller.newId(),
                        type: "text",
                        x: root.textX,
                        y: root.textY,
                        color: String(controller.color),
                        width: controller.width,
                        text: textField.text
                    }]));
        }
        root.editingText = false;
        textField.text = "";
        root.forceActiveFocus();
    }
    function addStep(x: real, y: real): void {
        root.commitModel(root.model.concat([{
                    id: controller.newId(),
                    type: "step",
                    x: x,
                    y: y,
                    color: String(controller.color),
                    width: controller.width,
                    n: EditorLogic.nextStep(root.model)
                }]));
    }

    // --- shape component dispatch -------------------------------------------
    function componentFor(t: string): Component {
        switch (t) {
        case "arrow":
            return arrowComp;
        case "box":
            return boxComp;
        case "ellipse":
            return ellipseComp;
        case "line":
            return lineComp;
        case "pen":
            return penComp;
        case "highlight":
            return highlightComp;
        case "blur":
            return blurComp;
        case "text":
            return textComp;
        case "step":
            return stepComp;
        default:
            return null;
        }
    }
    function bindShape(item: var, data: var): void {
        if (!item)
            return;
        item.shape = data;
        if (data.type === "blur")
            item.sourceItem = baseImage;
    }
    function bindDraft(item: var): void {
        if (!item)
            return;
        item.shape = Qt.binding(() => root.draft ?? ({}));
        if (root.draft && root.draft.type === "blur")
            item.sourceItem = baseImage;
    }

    // --- keyboard -----------------------------------------------------------
    function handleKey(event: var): void {
        if (root.editingText)
            return;
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_Z && (event.modifiers & Qt.ShiftModifier)) {
                root.redo();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Z) {
                root.undo();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Y) {
                root.redo();
                event.accepted = true;
                return;
            }
        }
        switch (event.key) {
        case Qt.Key_Escape:
            root.requestClose();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.requestExport(root);
            break;
        case Qt.Key_V:
            controller.tool = "select";
            break;
        case Qt.Key_A:
            controller.tool = "arrow";
            break;
        case Qt.Key_R:
            controller.tool = "box";
            break;
        case Qt.Key_E:
            controller.tool = "ellipse";
            break;
        case Qt.Key_L:
            controller.tool = "line";
            break;
        case Qt.Key_P:
            controller.tool = "pen";
            break;
        case Qt.Key_T:
            controller.tool = "text";
            break;
        case Qt.Key_H:
            controller.tool = "highlight";
            break;
        case Qt.Key_B:
            controller.tool = "blur";
            break;
        case Qt.Key_C:
            controller.tool = "crop";
            break;
        case Qt.Key_S:
            controller.tool = "step";
            break;
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            root.deleteSelected();
            break;
        }
        event.accepted = true;
    }

    focus: true
    Component.onCompleted: root.forceActiveFocus()
    Keys.onPressed: event => root.handleKey(event)

    ToolController {
        id: controller
    }

    // dim backdrop
    StyledRect {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim, 0.85)
    }

    Item {
        id: imageContainer

        width: root.imgW * root.fitScale
        height: root.imgH * root.fitScale
        anchors.centerIn: parent

        Image {
            id: baseImage

            anchors.fill: parent
            source: root.path ? Qt.resolvedUrl(root.path) : ""
            fillMode: Image.Stretch
            cache: false
            smooth: true
            asynchronous: false
        }

        // committed shapes (drawn in model order, bottom→top)
        Repeater {
            model: root.model

            delegate: Loader {
                required property var modelData

                anchors.fill: parent
                sourceComponent: root.componentFor(modelData.type)
                onLoaded: root.bindShape(item, modelData)
            }
        }

        // live draft (in-progress drag)
        Loader {
            id: draftLoader

            anchors.fill: parent
            active: root.draft !== null
            sourceComponent: root.draft ? root.componentFor(root.draft.type) : null
            onLoaded: root.bindDraft(item)
        }

        // selection outline
        Item {
            id: selOverlay

            anchors.fill: parent
            visible: root.selectedId !== "" && !root.grabbing

            readonly property var sel: visible ? (root.model.find(s => s.id === root.selectedId) ?? null) : null
            readonly property var b: sel ? EditorLogic.boundsOf(sel) : ({ x: 0, y: 0, x2: 0, y2: 0 })

            StyledRect {
                visible: selOverlay.sel !== null
                x: selOverlay.b.x - 4
                y: selOverlay.b.y - 4
                width: (selOverlay.b.x2 - selOverlay.b.x) + 8
                height: (selOverlay.b.y2 - selOverlay.b.y) + 8
                color: "transparent"
                radius: 3
                border.width: 1
                border.color: Colours.palette.m3primary
            }
        }

        // crop region border
        StyledRect {
            readonly property var c: root.cropRect ?? ({ x: 0, y: 0, x2: 0, y2: 0 })

            visible: root.cropRect !== null && !root.grabbing
            x: Math.min(c.x, c.x2)
            y: Math.min(c.y, c.y2)
            width: Math.abs(c.x2 - c.x)
            height: Math.abs(c.y2 - c.y)
            color: "transparent"
            border.width: 2
            border.color: Colours.palette.m3primary
        }

        // routing MouseArea
        MouseArea {
            id: ma

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: controller.isSelect() ? Qt.ArrowCursor : Qt.CrossCursor

            property bool movingSel: false
            property real lastX: 0
            property real lastY: 0

            onPressed: event => {
                root.forceActiveFocus();
                if (controller.isCrop()) {
                    root.cropRect = { x: event.x, y: event.y, x2: event.x, y2: event.y };
                    return;
                }
                if (controller.isSelect()) {
                    root.selectedId = EditorLogic.hitTest(root.model, event.x, event.y) ?? "";
                    ma.movingSel = root.selectedId !== "";
                    ma.lastX = event.x;
                    ma.lastY = event.y;
                    return;
                }
                if (controller.isDrag())
                    root.draft = controller.createDraft(event.x, event.y);
            }

            onPositionChanged: event => {
                if (controller.isCrop() && root.cropRect) {
                    root.cropRect = { x: root.cropRect.x, y: root.cropRect.y, x2: event.x, y2: event.y };
                    return;
                }
                if (ma.movingSel) {
                    root.moveSelected(event.x - ma.lastX, event.y - ma.lastY);
                    ma.lastX = event.x;
                    ma.lastY = event.y;
                    return;
                }
                if (root.draft)
                    root.draft = controller.updateDraft(root.draft, event.x, event.y);
            }

            onReleased: event => {
                if (controller.isCrop()) {
                    root.normaliseCrop();
                    return;
                }
                if (ma.movingSel) {
                    ma.movingSel = false;
                    root.stack.push(root.model);
                    root.syncHistoryFlags();
                    return;
                }
                if (controller.isClickTool()) {
                    if (controller.tool === "text")
                        root.beginText(event.x, event.y);
                    else if (controller.tool === "step")
                        root.addStep(event.x, event.y);
                    return;
                }
                if (root.draft) {
                    const d = root.draft;
                    const tiny = d.points ? d.points.length < 2 : (Math.abs((d.x2 ?? 0) - (d.x ?? 0)) < 2 && Math.abs((d.y2 ?? 0) - (d.y ?? 0)) < 2);
                    if (!tiny)
                        root.commitModel(root.model.concat([d]));
                    root.draft = null;
                }
            }
        }

        // crop corner handles (above the routing MouseArea so they win events)
        Repeater {
            model: (root.cropRect && !root.grabbing) ? 4 : 0

            delegate: Rectangle {
                id: handle

                required property int index
                readonly property var c: root.cropRect ?? ({ x: 0, y: 0, x2: 0, y2: 0 })
                readonly property real hx: (index === 1 || index === 3) ? c.x2 : c.x
                readonly property real hy: (index === 2 || index === 3) ? c.y2 : c.y

                x: hx - 7
                y: hy - 7
                width: 14
                height: 14
                radius: 7
                color: Colours.palette.m3primary
                border.width: 2
                border.color: Colours.palette.m3onPrimary

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    onPositionChanged: mouse => {
                        const p = mapToItem(imageContainer, mouse.x, mouse.y);
                        root.setCropCorner(handle.index, p.x, p.y);
                    }
                    onReleased: root.normaliseCrop()
                }
            }
        }

        // in-canvas text editor
        StyledTextField {
            id: textField

            visible: root.editingText
            x: root.textX
            y: root.textY
            width: Math.max(120, implicitWidth)
            color: controller.color
            font: Qt.font({
                family: Tokens.font.body.large.family,
                pixelSize: Math.max(14, controller.width * 6),
                bold: true
            })
            onAccepted: root.commitText()
            Keys.onEscapePressed: {
                root.editingText = false;
                text = "";
                root.forceActiveFocus();
            }
            onActiveFocusChanged: {
                if (!activeFocus && root.editingText)
                    root.commitText();
            }
        }
    }

    Toolbar {
        id: toolbar

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Tokens.padding.large

        controller: controller
        canUndo: root.canUndo
        canRedo: root.canRedo
        hasCrop: root.cropRect !== null
        onRequestUndo: root.undo()
        onRequestRedo: root.redo()
        onRequestExport: root.requestExport(root)
        onRequestCancel: root.requestClose()
        onRequestClearCrop: root.cropRect = null
    }

    // --- shape component instances ------------------------------------------
    Component {
        id: arrowComp
        Shapes.Arrow {}
    }
    Component {
        id: boxComp
        Shapes.Box {}
    }
    Component {
        id: ellipseComp
        Shapes.Ellipse {}
    }
    Component {
        id: lineComp
        Shapes.Line {}
    }
    Component {
        id: highlightComp
        Shapes.Highlight {}
    }
    Component {
        id: blurComp
        Shapes.Blur {}
    }
    Component {
        id: textComp
        Shapes.TextShape {}
    }
    Component {
        id: stepComp
        Shapes.StepMarker {}
    }
    // "pen" has no owned shape file → render freehand inline.
    Component {
        id: penComp

        Shape {
            property var shape: ({})

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            asynchronous: false

            ShapePath {
                strokeColor: shape.color ?? "#ff3b30"
                strokeWidth: shape.width ?? 4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: (shape.points ?? []).map(p => Qt.point(p.x, p.y))
                }
            }
        }
    }
}
