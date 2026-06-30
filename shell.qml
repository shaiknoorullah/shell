//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/clipboard"
import "modules/editor"
import "modules/pin"
import "modules/lock"
import "modules/tasks"
import qs.services
import Quickshell

ShellRoot {
    settings.watchFiles: true

    GSFLoader {}

    Background {}
    Drawers {}
    AreaPicker {}
    ModePicker {}
    Clipboard {}
    Editor {}
    Pin {}
    Lock {
        id: lock
    }

    ConfigToasts {}
    Shortcuts {}
    FocusPanel {}
    Variants { model: Screens.screens; LeftBar {} }
    TaskIpc {}
    // Variants { model: Screens.screens; BottomBar {} }   // optional; enable later
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
}
