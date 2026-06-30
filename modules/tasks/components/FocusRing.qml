// FOCUS RING — a small conic "progress" ring (mockup .ring / #focus .fring)
//
// The mockup paints the focus score as a CSS conic-gradient ring:
//   background:conic-gradient(var(--green) calc(var(--p)*1%), var(--s2) 0)
// Quickshell/QML has no conic-gradient, so we draw it on a Canvas: a full track
// arc in `trackColor`, then a foreground arc from 12 o'clock sweeping clockwise
// for `value`% in `color`. A hole in the middle makes it a ring, not a pie.
//
// SHAME-FREE: this is a calm progress indicator, never a deficit gauge — there
// is no "empty/red" framing; an unfilled remainder is just the muted track.

import QtQuick
import qs.services

Canvas {
    id: root

    property real value: 84          // 0..100
    property color color: Theme.green
    property color trackColor: Theme.s2
    property real thickness: Math.max(2, width * 0.22)

    width: 16
    height: 16
    antialiasing: true

    onValueChanged: requestPaint()
    onColorChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const cx = width / 2;
        const cy = height / 2;
        const r = Math.min(width, height) / 2 - 0.5;
        const start = -Math.PI / 2;                 // 12 o'clock
        const frac = Math.max(0, Math.min(1, value / 100));

        // track
        ctx.beginPath();
        ctx.lineWidth = root.thickness;
        ctx.strokeStyle = root.trackColor;
        ctx.arc(cx, cy, r - root.thickness / 2, 0, 2 * Math.PI);
        ctx.stroke();

        // value arc
        if (frac > 0) {
            ctx.beginPath();
            ctx.lineCap = "round";
            ctx.lineWidth = root.thickness;
            ctx.strokeStyle = root.color;
            ctx.arc(cx, cy, r - root.thickness / 2, start, start + frac * 2 * Math.PI);
            ctx.stroke();
        }
    }
}
