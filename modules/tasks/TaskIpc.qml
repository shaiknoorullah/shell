import Quickshell
import Quickshell.Io
import qs.services

Scope {
    IpcHandler {
        target: "panel"
        function focus(): void    { PanelState.go("focus");    BarState.openPalette() }
        function tasks(): void    { PanelState.go("tasks");    BarState.openPalette() }
        function projects(): void { PanelState.go("projects"); BarState.openPalette() }
        function tags(): void     { PanelState.go("tags");     BarState.openPalette() }
        function reports(): void  { PanelState.go("reports");  BarState.openPalette() }
    }
    IpcHandler {
        target: "leftbar"
        function toggle(): void { BarState.toggleLeft() }
        function open(): void   { BarState.openLeft() }
        function close(): void  { BarState.closeLeft() }
    }
}
