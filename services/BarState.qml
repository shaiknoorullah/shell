pragma Singleton

// BAR STATE SINGLETON — shared UI state across the three bars
// (pattern: caelestia services/* singletons that hold cross-module UI flags,
//  e.g. its visibility / popout state singletons.)
//
// The mockup is a small state machine (body.state-{idle,left,focus,...}). The
// only cross-bar coupling the bottom + left bars need is "is the LEFT bar
// summoned?" — when it is, the bottom bar slides away (mockup:
// `body.state-left #bottom{opacity:0; transform:translateY(8px)}`).
//
// LeftBar binds its slide-in to `leftOpen`; BottomBar binds its slide-out to the
// same flag. A keybind / IPC handler / hover trigger flips it via toggleLeft().
// Kept deliberately tiny so any future trigger (Hyprland keybind -> qs ipc,
// edge-hover MouseArea, command-palette action) can drive it.
// IPC handlers live in TaskIpc.qml so they register their targets once.

import Quickshell
import QtQuick

Singleton {
    id: root

    // Is the summoned LEFT "what am I chasing" bar visible?
    property bool leftOpen: false

    function toggleLeft(): void {
        root.leftOpen = !root.leftOpen;
    }
    function openLeft(): void {
        root.leftOpen = true;
    }
    function closeLeft(): void {
        root.leftOpen = false;
    }

    // The dedicated centered "start a block" command palette (FocusPalette.qml),
    // summoned by $mod+Shift+Return → `qs ipc call palette open`.
    property bool paletteOpen: false

    function togglePalette(): void {
        root.paletteOpen = !root.paletteOpen;
    }
    function openPalette(): void {
        root.paletteOpen = true;
    }
    function closePalette(): void {
        root.paletteOpen = false;
    }
}
