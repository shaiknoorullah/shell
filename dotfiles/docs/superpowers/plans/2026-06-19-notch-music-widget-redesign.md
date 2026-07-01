# Notch Music Widget Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the basic Dynamic Island music widget with a richer collapsed pill (art+progress-ring · title · real cava visualizer, hover-reveals transport) and a polished expanded player (blurred art backdrop, full-width mirrored cava band, seekable scrub, prev/play/next + shuffle/repeat).

**Architecture:** Split the monolithic `Island.qml` into a morph **shell** that composes two dumb layer components (`MiniPlayer`, `FullPlayer`), backed by small reusable components (`Visualizer`, `ProgressRing`, `CoverArt`, `MediaButton`) and a new `Cava` singleton service that streams real audio spectrum data from an in-container `cava` process. Controls bind directly to the native MPRIS `Players.active`.

**Tech Stack:** QML / Qt6, Quickshell (`Quickshell.Io` Process+SplitParser, `Quickshell.Services.Mpris`, `Quickshell.Widgets`, `QtQuick.Shapes`, `QtQuick.Effects`), `cava` (raw ascii output), chezmoi, Hyprland 0.55, Arch distrobox runtime.

## Global Constraints

- **Branch first:** work on `feat/notch-music-redesign` (repo is on `main`). Commit per task **locally**; do **NOT** push, and do not commit to `main`. Commit messages end with the trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Source vs deploy:** edit files under the chezmoi source `private_dot_config/quickshell/`; they deploy to `~/.config/quickshell/` via `chezmoi apply --force`. Never edit `~/.config/quickshell` directly.
- **No unit-test harness for QML:** there is no pytest/jest here. "Test" = the repo loop: deploy → check journal for QML errors → screenshot and visually confirm. Each task ends with that verification.
- **Colors via `Theme` only**, never raw hex. Icons via `MaterialIcon` (Material Symbols Rounded). Text font `Theme.fontMono`.
- **Singletons** auto-register by basename via `pragma Singleton` (no qmldir). Components are referenced via `import qs.components`, services via `import qs.services`.
- **cava bar count is 24** and must match the deployed cava config exactly.

## Deploy & Inspect (referenced by every task's verify step)

Run this from `/home/devsupreme/ubuntu-dots`. Bash has no Hyprland env by default; pick the LIVE instance (the newest socket may be stale — test each):

```bash
export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-1
for d in $XDG_RUNTIME_DIR/hypr/*/; do s=$(basename "$d"); \
  HYPRLAND_INSTANCE_SIGNATURE="$s" hyprctl version >/dev/null 2>&1 && export HYPRLAND_INSTANCE_SIGNATURE="$s" && break; done
export PATH="$HOME/.local/bin:$PATH"

chezmoi apply --force
systemctl --user restart quickshell-bar && sleep 6
# QML errors (must be empty):
journalctl --user -u quickshell-bar --since "8 seconds ago" | grep -iE 'error|is not a type|cannot assign|unable' | grep -v workspace
# screenshot from the container (host has no grim), then Read the PNG:
distrobox enter arch -- bash -c "export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-1; grim ~/qs.png"
convert ~/qs.png -crop 520x230+700+0 +repage -resize 220% ~/qs-notch.png   # centre notch region
```
Bash calls touching distrobox need `dangerouslyDisableSandbox: true`.
To screenshot the **expanded** player during dev, temporarily set `pinned: true` as the default in `Island.qml` (or click the notch on the live desktop), screenshot, then revert.

## Interaction model change (applies to Task 7)

Today `Island.open = hovered || pinned` — hovering auto-expands. The approved design shows a **collapsed hover** state (cava → transport). So the new model is:
- **resting:** art+ring · title · cava
- **hover:** stays collapsed; cava cross-fades to prev/play/next (and the pill may widen slightly)
- **click:** pins open the full expanded player (`open = pinned`)

---

## File Structure

| File (chezmoi source) | Create/Modify | Responsibility |
|---|---|---|
| `private_dot_config/quickshell/assets/cava-raw.conf` | Create | Static cava config: raw ascii, 24 bars, pulse input. |
| `private_dot_config/quickshell/services/Cava.qml` | Create | Singleton: stream cava → normalized `values` array (0..1). |
| `private_dot_config/quickshell/components/Visualizer.qml` | Create | Data-driven **mirrored** bar renderer (grows up+down). |
| `private_dot_config/quickshell/components/ProgressRing.qml` | Create | Circular progress arc wrapping content. |
| `private_dot_config/quickshell/components/CoverArt.qml` | Create | Rounded MPRIS art tile (extracted from Island). |
| `private_dot_config/quickshell/components/MediaButton.qml` | Create | Reusable transport/toggle button. |
| `private_dot_config/quickshell/bar/components/MiniPlayer.qml` | Create | Collapsed layer composition. |
| `private_dot_config/quickshell/bar/components/FullPlayer.qml` | Create | Expanded layer composition. |
| `private_dot_config/quickshell/bar/Island.qml` | Modify | Morph shell; compose MiniPlayer/FullPlayer; interaction model. |
| `private_dot_config/quickshell/services/Theme.qml` | Modify | `notchH 30→32`, `notchOpenH 194→210`. |
| `private_dot_config/quickshell/components/Eq.qml` | Delete | Superseded by Visualizer. |

---

## Task 1: Cava config + service (real spectrum data)

**Files:**
- Create: `private_dot_config/quickshell/assets/cava-raw.conf`
- Create: `private_dot_config/quickshell/services/Cava.qml`

**Interfaces:**
- Produces: singleton `Cava` with `readonly property int bars` (24), `property var values` (array of 24 reals 0..1), `property bool enabled` (consumer sets true to run cava), `readonly property bool active`.

- [ ] **Step 1: Install cava in the arch container and verify it captures host audio**

Run (needs `dangerouslyDisableSandbox`):
```bash
distrobox enter arch -- sudo pacman -S --noconfirm cava
# with music playing on the host, confirm non-zero frames:
printf '[output]\nmethod=raw\nraw_target=/dev/stdout\ndata_format=ascii\nascii_max_range=1000\nbars=24\nbar_delimiter=59\n[input]\nmethod=pulse\n' > /tmp/cava-test.conf
distrobox enter arch -- bash -c "timeout 2 cava -p /tmp/cava-test.conf | head -3"
```
Expected: lines of 24 `;`-separated ints, non-zero while audio plays. **If all zero / errors:** switch `[input] method` to `pipewire` and retry; if still failing, STOP and use the host-FIFO fallback from the spec (out of scope for this plan — escalate).

- [ ] **Step 2: Create the deployed cava config**

`private_dot_config/quickshell/assets/cava-raw.conf`:
```ini
# Raw-ascii spectrum feed for quickshell's Cava service (24 bars, host audio).
# Deploys to ~/.config/quickshell/assets/cava-raw.conf (shared into the arch
# distrobox where quickshell — and therefore cava — runs).
[general]
mode = normal
framerate = 60
bars = 24
autosens = 1

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
```

- [ ] **Step 3: Create the Cava service**

`private_dot_config/quickshell/services/Cava.qml`:
```qml
pragma Singleton

// CAVA SPECTRUM SINGLETON — real audio-reactive visualiser data
// (pattern: caelestia services + Quickshell.Io streaming Process, cf. Focus.qml)
//
// Streams `cava` raw-ascii output (one frame per line: 24 ';'-separated ints
// 0..1000) and normalises each frame into `values` (length 24, each 0..1).
// cava runs INSIDE the arch distrobox (where quickshell lives); the host
// pipewire/pulse sockets are visible there, so it captures host audio. The
// process only runs while `enabled` is true (the island sets it from the
// player presence) so we never capture audio needlessly.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int bars: 24
    readonly property int maxRange: 1000
    property var values: root._zeros()
    property bool enabled: false
    readonly property bool active: proc.running

    function _zeros(): var {
        const a = [];
        for (let i = 0; i < root.bars; i++)
            a.push(0);
        return a;
    }

    Process {
        id: proc

        running: root.enabled
        // sh -c so $HOME expands to the (shared) config path; exec keeps the
        // tree clean so SplitParser reads cava's own stdout.
        command: ["sh", "-c", "exec cava -p \"$HOME/.config/quickshell/assets/cava-raw.conf\""]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const t = line.trim();
                if (!t)
                    return;
                const parts = t.split(";");
                const out = [];
                for (let i = 0; i < root.bars; i++) {
                    const v = parseInt(parts[i]);
                    out.push(isNaN(v) ? 0 : Math.min(1, v / root.maxRange));
                }
                root.values = out;
            }
        }

        onRunningChanged: if (!running) root.values = root._zeros()
    }
}
```

- [ ] **Step 4: Deploy and verify the service loads + runs**

Temporarily force it on for the check: in `Cava.qml` set `property bool enabled: true` (revert in Step 5). Deploy (see Deploy & Inspect). Then:
```bash
journalctl --user -u quickshell-bar --since "10 seconds ago" | grep -iE 'error|Cava'   # no QML errors
distrobox enter arch -- bash -c "pgrep -ax cava"                                        # cava is running
```
Expected: no QML errors; a `cava` process present. (Add a `onValuesChanged: console.log("cava", values[0])` line temporarily if you want to see frames in the journal, then remove it.)

- [ ] **Step 5: Revert the temporary `enabled: true` back to `enabled: false`, then commit**

```bash
git checkout -b feat/notch-music-redesign   # first task only
git add private_dot_config/quickshell/assets/cava-raw.conf private_dot_config/quickshell/services/Cava.qml
git commit -m "feat(island): cava spectrum service + raw config

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Visualizer component (mirrored bars) + retire Eq

**Files:**
- Create: `private_dot_config/quickshell/components/Visualizer.qml`
- Modify: `private_dot_config/quickshell/bar/Island.qml` (swap the collapsed `Eq` for `Visualizer` fed by `Cava`)
- Delete: `private_dot_config/quickshell/components/Eq.qml`

**Interfaces:**
- Produces: `Visualizer` with `property var values` (array 0..1), `property real barWidth`, `property int maxH`, `property int minH`, `property color color`. Renders one bar per `values` entry, each centered vertically so it grows **up and down**.

- [ ] **Step 1: Create the Visualizer**

`private_dot_config/quickshell/components/Visualizer.qml`:
```qml
// VISUALIZER — data-driven mirrored spectrum bars (replaces Eq.qml)
// Each bar grows UP AND DOWN from the vertical centre (the old Eq pinned the
// bottom via anchors.bottom, so it only grew up — the bug we're fixing).
// Pure presentation: feed it `values` (array of magnitudes 0..1).

import QtQuick
import qs.services

Row {
    id: root

    property var values: []
    property real barWidth: 3
    property int maxH: 14
    property int minH: 2
    property color color: Theme.green

    spacing: 2
    height: maxH

    Repeater {
        model: root.values.length

        Rectangle {
            id: bar
            required property int index

            width: root.barWidth
            radius: width / 2
            color: root.color
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(root.minH, (root.values[bar.index] ?? 0) * root.maxH)

            Behavior on height {
                NumberAnimation { duration: 80; easing.type: Easing.OutSine }
            }
        }
    }
}
```

- [ ] **Step 2: Swap Eq → Visualizer in the collapsed layer of `Island.qml`**

In `bar/Island.qml`, find the collapsed `Eq { ... }` block and replace it with:
```qml
            // Live spectrum — mirrored bars from the real cava feed.
            Visualizer {
                Layout.preferredHeight: 14
                values: root._bucket(Cava.values, 7)
                barWidth: 3
                maxH: 14
                color: Theme.ctxAccent
            }
```
Add this helper function inside the `Island` root `Item` (near the other `function`s):
```qml
    // Bucket-average an array down to n values (24-band cava -> ~7 mini bars).
    function _bucket(arr: var, n: int): var {
        if (!arr || arr.length === 0)
            return [];
        const out = [];
        const size = arr.length / n;
        for (let i = 0; i < n; i++) {
            let sum = 0, c = 0;
            for (let j = Math.floor(i * size); j < Math.floor((i + 1) * size); j++) {
                sum += arr[j];
                c++;
            }
            out.push(c ? sum / c : 0);
        }
        return out;
    }
```
Drive cava from the island: add to the `Island` root `Item` body:
```qml
    // Run the cava capture only while a player exists.
    Binding {
        target: Cava
        property: "enabled"
        value: root.hasPlayer
    }
```
Add `import qs.services` is already present; ensure `Cava` resolves (it's a singleton in that import).

- [ ] **Step 3: Delete Eq.qml**

```bash
git rm private_dot_config/quickshell/components/Eq.qml
```

- [ ] **Step 4: Deploy and verify bars move up AND down**

Deploy (see Deploy & Inspect) with music playing. Screenshot the notch; Read `~/qs-notch.png`.
Expected: no QML errors; the bars in the collapsed pill extend both above and below their centre line and react to audio (compare two screenshots a second apart — heights differ).

- [ ] **Step 5: Commit**

```bash
git add private_dot_config/quickshell/components/Visualizer.qml private_dot_config/quickshell/bar/Island.qml
git commit -m "feat(island): mirrored cava Visualizer, retire Eq

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Extract CoverArt component

**Files:**
- Create: `private_dot_config/quickshell/components/CoverArt.qml`
- Modify: `private_dot_config/quickshell/bar/Island.qml` (remove the inline `component CoverArt`, rely on the import)

**Interfaces:**
- Produces: `CoverArt` with `property url source`, `property int rad`. Rounded album-art tile with a Dracula-gradient fallback until the image is Ready.

- [ ] **Step 1: Create the component (verbatim move of the inline one)**

`private_dot_config/quickshell/components/CoverArt.qml`:
```qml
// COVER ART — rounded MPRIS album-art tile w/ Dracula-gradient fallback.
// (extracted from Island.qml so both player layers can reuse it.)

import QtQuick
import Quickshell.Widgets
import qs.services

ClippingRectangle {
    id: cov

    property url source: ""
    property int rad: 13

    radius: rad
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        visible: art.status !== Image.Ready
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.purple }
            GradientStop { position: 0.5; color: Theme.pink }
            GradientStop { position: 1.0; color: Theme.orange }
        }
    }

    Image {
        id: art
        anchors.fill: parent
        source: cov.source
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        sourceSize.width: width
        sourceSize.height: height
    }
}
```

- [ ] **Step 2: Remove the inline `component CoverArt: ClippingRectangle { ... }` block from `Island.qml`**

Delete the whole `component CoverArt: ...` definition near the bottom of `Island.qml`. The existing `CoverArt { ... }` usages now resolve to the imported component (`import qs.components` is already present). If `Quickshell.Widgets` import is now unused in Island, leave it — the file still uses it elsewhere; remove only if a journal warning flags it.

- [ ] **Step 3: Deploy and verify art still renders**

Deploy. Screenshot. Expected: no QML errors; the collapsed album art still shows (real cover or gradient fallback).

- [ ] **Step 4: Commit**

```bash
git add private_dot_config/quickshell/components/CoverArt.qml private_dot_config/quickshell/bar/Island.qml
git commit -m "refactor(island): extract CoverArt component

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: ProgressRing component

**Files:**
- Create: `private_dot_config/quickshell/components/ProgressRing.qml`

**Interfaces:**
- Produces: `ProgressRing` with `property real value` (0..1), `property int ringWidth`, `property color color`, `property color track`, and a `default property alias content` slot (child item is centered inside the ring).

- [ ] **Step 1: Create the component**

`private_dot_config/quickshell/components/ProgressRing.qml`:
```qml
// PROGRESS RING — thin circular arc (value 0..1) wrapping its content.
// Used to ring the collapsed album art with playback progress.

import QtQuick
import QtQuick.Shapes
import qs.services

Item {
    id: root

    property real value: 0
    property int ringWidth: 2
    property color color: Theme.ctxAccent
    property color track: Theme.withAlpha(Theme.fg, 0.15)
    default property alias content: holder.data

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.track
            strokeWidth: root.ringWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.ringWidth) / 2
                radiusY: (root.height - root.ringWidth) / 2
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.ringWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.ringWidth) / 2
                radiusY: (root.height - root.ringWidth) / 2
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, root.value))

                Behavior on sweepAngle {
                    NumberAnimation { duration: 400; easing.type: Easing.OutSine }
                }
            }
        }
    }

    Item {
        id: holder
        anchors.centerIn: parent
        width: parent.width - root.ringWidth * 2 - 2
        height: width
    }
}
```

- [ ] **Step 2: Deploy and verify it loads (no consumer yet)**

Deploy. Expected: no QML errors (the component compiles even though nothing uses it yet). If the journal complains `QtQuick.Shapes is not installed`, the Qt6 Shapes module is missing in the container — install it (`distrobox enter arch -- sudo pacman -S --noconfirm qt6-quick3d || qt6-declarative` provides Shapes; verify with the next task).

- [ ] **Step 3: Commit**

```bash
git add private_dot_config/quickshell/components/ProgressRing.qml
git commit -m "feat(components): ProgressRing (Shapes arc)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: MediaButton component

**Files:**
- Create: `private_dot_config/quickshell/components/MediaButton.qml`

**Interfaces:**
- Produces: `MediaButton` with `property string icon` (Material Symbol ligature), `property bool enabled`, `property bool active` (on-state highlight), `property int size`; emits `clicked()`.

- [ ] **Step 1: Create the component**

`private_dot_config/quickshell/components/MediaButton.qml`:
```qml
// MEDIA BUTTON — reusable transport / toggle control (Material Symbol glyph).
// Dims when disabled, accents when `active` (shuffle/repeat on-state).

import QtQuick
import qs.services

Item {
    id: root

    property string icon: ""
    property bool enabled: true
    property bool active: false
    property int size: 22
    signal clicked

    implicitWidth: size
    implicitHeight: size

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        font.pixelSize: root.size
        color: !root.enabled ? Theme.comment
             : root.active ? Theme.ctxAccent
             : Theme.fg
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
```
Note: `MaterialIcon` resolves via `import qs.components` (auto-imported within the components dir). If the journal flags `MaterialIcon is not a type`, add `import qs.components`.

- [ ] **Step 2: Deploy and verify it loads**

Deploy. Expected: no QML errors.

- [ ] **Step 3: Commit**

```bash
git add private_dot_config/quickshell/components/MediaButton.qml
git commit -m "feat(components): reusable MediaButton

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: MiniPlayer (collapsed layer)

**Files:**
- Create: `private_dot_config/quickshell/bar/components/MiniPlayer.qml`

**Interfaces:**
- Consumes: `ProgressRing`, `CoverArt`, `Visualizer`, `MediaButton`, `Cava.values`, MPRIS player props.
- Produces: `MiniPlayer` with `property var player` (the MprisPlayer), `property bool hovered`. Lays out: art+ring · title · (cava ⇄ transport crossfade keyed on `hovered`).

- [ ] **Step 1: Create the component**

`private_dot_config/quickshell/bar/components/MiniPlayer.qml`:
```qml
// MINI PLAYER — collapsed island layer.
// art (ringed by playback progress) · title · cava bars that cross-fade into
// prev/play/next on hover (the island stays collapsed; click opens FullPlayer).

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

RowLayout {
    id: root

    property var player: null
    property bool hovered: false

    spacing: 9

    // ---- Album art wrapped by a thin progress ring --------------------------
    ProgressRing {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        ringWidth: 2
        color: Theme.ctxAccent
        value: {
            const len = root.player?.length ?? 0;
            return len > 0 ? (root.player?.position ?? 0) / len : 0;
        }

        CoverArt {
            anchors.fill: parent
            rad: width / 2
            source: root.player?.trackArtUrl ?? ""
        }
    }

    // ---- Track title --------------------------------------------------------
    StyledText {
        Layout.maximumWidth: 150
        text: root.player?.trackTitle ?? "—"
        color: Theme.withAlpha(Theme.fg, 0.85)
        font.family: Theme.fontMono
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    // ---- cava ⇄ transport crossfade slot (fixed width to limit morph jitter) -
    Item {
        Layout.preferredWidth: 80
        Layout.preferredHeight: 20

        Visualizer {
            anchors.centerIn: parent
            opacity: root.hovered ? 0 : 1
            visible: opacity > 0
            values: Island._bucket(Cava.values, 7)   // see note below
            barWidth: 3
            maxH: 14
            color: Theme.ctxAccent
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 10
            opacity: root.hovered ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

            MediaButton {
                icon: "skip_previous"
                size: 18
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player?.previous()
            }
            MediaButton {
                icon: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow"
                size: 20
                enabled: root.player?.canTogglePlaying ?? false
                onClicked: root.player?.togglePlaying()
            }
            MediaButton {
                icon: "skip_next"
                size: 18
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player?.next()
            }
        }
    }

    // Bucket-average cava's 24 bands down to n bars.
    function bucket(arr: var, n: int): var {
        if (!arr || arr.length === 0)
            return [];
        const out = [];
        const size = arr.length / n;
        for (let i = 0; i < n; i++) {
            let sum = 0, c = 0;
            for (let j = Math.floor(i * size); j < Math.floor((i + 1) * size); j++) {
                sum += arr[j];
                c++;
            }
            out.push(c ? sum / c : 0);
        }
        return out;
    }
}
```
**Note:** the `values:` line above must call THIS component's own `bucket`, not `Island._bucket`. Use `values: root.bucket(Cava.values, 7)`. (The `_bucket` added to Island in Task 2 is removed in Task 7 when Island stops owning the mini layout — see Task 7 Step 3.)

- [ ] **Step 2: Fix the `values:` binding to use the local helper**

Ensure the Visualizer line reads exactly:
```qml
            values: root.bucket(Cava.values, 7)
```

- [ ] **Step 3: Deploy and verify in isolation**

This component isn't wired into Island yet (Task 7 does that), so just confirm it compiles: deploy and check the journal has no `MiniPlayer` parse errors. (No visual change yet.)
Expected: no QML errors.

- [ ] **Step 4: Commit**

```bash
git add private_dot_config/quickshell/bar/components/MiniPlayer.qml
git commit -m "feat(island): MiniPlayer collapsed layer

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: FullPlayer (expanded layer) + Island shell rewire + Theme tokens

**Files:**
- Create: `private_dot_config/quickshell/bar/components/FullPlayer.qml`
- Modify: `private_dot_config/quickshell/bar/Island.qml` (compose Mini/Full; interaction model; remove inline mini/full + `_bucket`)
- Modify: `private_dot_config/quickshell/services/Theme.qml` (`notchH 30→32`, `notchOpenH 194→210`)

**Interfaces:**
- Consumes: `CoverArt`, `Visualizer`, `MediaButton`, `Cava.values`, `Focus`, MPRIS player props (`shuffle`, `loopState`, `canSeek`, `position`, `length`).
- Produces: `FullPlayer` with `property var player`. Full media player layout.

- [ ] **Step 1: Bump Theme tokens**

In `services/Theme.qml`:
```qml
    readonly property int notchH: 32        // #notch collapsed height (was 30; uniform with pills)
    readonly property int notchOpenH: 210   // #notch.open height (was 194; room for the cava band)
```

- [ ] **Step 2: Create FullPlayer**

`private_dot_config/quickshell/bar/components/FullPlayer.qml`:
```qml
// FULL PLAYER — expanded island layer (click-pinned).
// blurred art backdrop · [art | title/artist/album | live-activity pill]
// · full-width mirrored cava band · seekable scrub · transport+shuffle/repeat.

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs.components
import qs.services

Item {
    id: root

    property var player: null

    // ---- Blurred album-art backdrop (art-driven ambiance) -------------------
    Image {
        id: backdropSrc
        anchors.fill: parent
        source: root.player?.trackArtUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        visible: false
        asynchronous: true
        cache: true
    }
    MultiEffect {
        anchors.fill: parent
        source: backdropSrc
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        opacity: backdropSrc.status === Image.Ready ? 0.18 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durBase } }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.bottomMargin: 14
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 0

        // ---- Row 1: art + meta + live-activity ------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 13

            CoverArt {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                rad: 13
                source: root.player?.trackArtUrl ?? ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle ?? "Nothing playing"
                    color: Theme.fg
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const a = root.player?.trackArtist ?? "";
                        const al = root.player?.trackAlbum ?? "";
                        return al ? `${a} · ${al}` : a;
                    }
                    color: Theme.comment
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                // Live-activity pill (focus/salah) — kept from the old design.
                Rectangle {
                    Layout.topMargin: 4
                    implicitWidth: liveRow.implicitWidth + 18
                    implicitHeight: liveRow.implicitHeight + 6
                    radius: height / 2
                    color: Theme.a12

                    RowLayout {
                        id: liveRow
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            Layout.preferredWidth: 5
                            Layout.preferredHeight: 5
                            radius: width / 2
                            color: Theme.ctxAccent

                            SequentialAnimation on opacity {
                                running: true
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }

                        StyledText {
                            text: {
                                const state = Focus.running ? `deep block · ${Focus.blockMinutes}m` : "idle";
                                const next = Focus.nextPrayerName ? ` → ${Focus.nextPrayerName} ${Focus.nextPrayerTime}` : "";
                                return state + next;
                            }
                            color: Theme.ctxAccent
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // ---- Full-width mirrored cava band ----------------------------------
        Visualizer {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            Layout.topMargin: 6
            values: Cava.values
            barWidth: 4
            maxH: 24
            minH: 2
            color: Theme.ctxAccent
        }

        // ---- Seekable scrub -------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 9

            StyledText {
                text: root.fmtTime(root.player?.position ?? 0)
                color: Theme.comment
                font.family: Theme.fontMono
                font.pixelSize: 10
            }

            Rectangle {
                id: track
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Theme.withAlpha(Theme.fg, 0.12)

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * root.progressFrac
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.purple }
                        GradientStop { position: 1.0; color: Theme.pink }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.player?.canSeek ?? false
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: mouse => {
                        const len = root.player?.length ?? 0;
                        if (len > 0)
                            root.player.position = (mouse.x / width) * len;
                    }
                }
            }

            StyledText {
                text: root.fmtTime(root.player?.length ?? 0)
                color: Theme.comment
                font.family: Theme.fontMono
                font.pixelSize: 10
            }
        }

        // ---- Transport: shuffle · prev · play/pause · next · repeat ---------
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.alignment: Qt.AlignHCenter
            spacing: 20

            MediaButton {
                icon: "shuffle"
                size: 18
                enabled: root.player?.shuffleSupported ?? false
                active: root.player?.shuffle ?? false
                onClicked: if (root.player) root.player.shuffle = !root.player.shuffle
            }

            MediaButton {
                icon: "skip_previous"
                size: 22
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player?.previous()
            }

            // Big filled play/pause.
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: width / 2
                color: Theme.fg

                MaterialIcon {
                    anchors.centerIn: parent
                    text: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow"
                    color: Theme.oled
                    font.pixelSize: 22
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.player?.canTogglePlaying ?? false
                    onClicked: root.player?.togglePlaying()
                }
            }

            MediaButton {
                icon: "skip_next"
                size: 22
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player?.next()
            }

            MediaButton {
                // none → repeat_on, Playlist → repeat, Track → repeat_one
                icon: (root.player?.loopState === MprisLoopState.Track) ? "repeat_one" : "repeat"
                size: 18
                enabled: root.player?.canControl ?? false
                active: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                onClicked: {
                    if (!root.player) return;
                    const s = root.player.loopState;
                    root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist
                        : s === MprisLoopState.Playlist ? MprisLoopState.Track
                        : MprisLoopState.None;
                }
            }
        }
    }

    readonly property real progressFrac: {
        const len = root.player?.length ?? 0;
        if (len <= 0) return 0;
        return Math.max(0, Math.min(1, (root.player?.position ?? 0) / len));
    }

    function fmtTime(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return `${m}:${r < 10 ? "0" + r : r}`;
    }
}
```

- [ ] **Step 3: Rewire `Island.qml` to compose the two layers + new interaction model**

In `bar/Island.qml`:
1. Change the open rule so hover no longer auto-expands:
```qml
    // Click PINS the full player open; hover only reveals inline mini controls.
    readonly property bool open: root.pinned
```
2. Replace the inline collapsed `RowLayout { id: mini ... }` with:
```qml
        MiniPlayer {
            id: mini
            anchors.centerIn: parent
            player: root.player
            hovered: root.hovered
            opacity: root.open ? 0 : 1
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.calmBezier.concat([1, 1]) }
            }
        }
```
3. Replace the inline open `ColumnLayout { id: full ... }` with:
```qml
        FullPlayer {
            id: full
            anchors.fill: parent
            anchors.margins: 0
            player: root.player
            opacity: root.open ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.calmBezier.concat([1, 1]) } }
        }
```
4. Delete the now-unused `_bucket` function, the `fmtTime` function, the `progressFrac` property, the position-tick `Timer` ... **except** keep the position tick — move it to fire while `open`:
```qml
    Timer {
        running: (root.player?.isPlaying ?? false) && root.open
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }
```
   (The mini progress ring updates fine on metadata changes; the precise scrub only needs ticking while open. If you want the ring to advance smoothly while collapsed too, change `&& root.open` to `&& root.hasPlayer`.)
5. Keep the `Binding { target: Cava; property: "enabled"; value: root.hasPlayer }` from Task 2.
6. Add `import qs.bar.components` if the bar components dir needs explicit import; if `MiniPlayer`/`FullPlayer` resolve via the existing `bar/` co-location, no import is needed (they're siblings). Verify against the journal.

- [ ] **Step 4: Deploy and verify both states + controls**

Deploy with music playing.
- Collapsed resting: screenshot → art with progress ring, title, mirrored cava bars.
- Collapsed hover: move the mouse over the notch on the live desktop (or temporarily set `hovered: true` default) → cava cross-fades to prev/play/next; the island does NOT expand.
- Expanded: click the notch (or temporarily `pinned: true`) → screenshot the full player. Confirm: blurred art backdrop, title/artist·album, live pill, full-width mirrored band, scrub with times, shuffle/prev/play/next/repeat.
- Click prev/next/play, drag-click the scrub, toggle shuffle and repeat → verify they affect playback (check `playerctl status`/`playerctl metadata` on host, or watch the track change).

Expected: no QML errors; all controls work; seek jumps position; shuffle/repeat highlight when active.

- [ ] **Step 5: Commit**

```bash
git add private_dot_config/quickshell/bar/components/FullPlayer.qml private_dot_config/quickshell/bar/Island.qml private_dot_config/quickshell/services/Theme.qml
git commit -m "feat(island): FullPlayer + compose layers, click-to-open model

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Final pass — comments, morph width, cleanup

**Files:**
- Modify: `private_dot_config/quickshell/bar/Island.qml` (header comment accuracy; optional content-driven collapsed width)

- [ ] **Step 1: Make the collapsed width fit the new mini layout**

The mini layer is wider than the old 226. Either bump the tokens in `Theme.qml` or make the collapsed body width track the mini layer's implicit width. Simplest robust option — content-driven collapsed width with the open width fixed. In `Island.qml`, change the body `width` binding:
```qml
        width: root.open ? Theme.notchOpenW
            : mini.implicitWidth + 28   // mini content + horizontal padding
```
Remove `notchHoverW` usage (hover no longer changes size; the crossfade is in-place). Keep `Behavior on width` so collapse↔open still animates.

- [ ] **Step 2: Update the `Island.qml` header comment**

Update the top comment block to describe: collapsed = MiniPlayer (art+ring · title · cava⇄transport), open = FullPlayer (click-pinned), real cava feed, click-to-open (hover reveals mini controls). Remove stale "circular art + live eq bars + truncated title" wording.

- [ ] **Step 3: Deploy and verify the full morph end-to-end**

Deploy. Verify the collapse↔open morph is smooth, the collapsed pill is sized correctly (no clipped bars/title, no big empty gap), and no QML errors. Take final screenshots of all three states.
Expected: clean morph, correct sizing, no errors.

- [ ] **Step 4: Commit**

```bash
git add private_dot_config/quickshell/bar/Island.qml
git commit -m "polish(island): content-driven collapsed width, doc cleanup

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (completed during authoring)

**Spec coverage:** collapsed art+ring+title+cava (T6), hover→transport (T6/T7), expanded big art/meta/live-pill (T7), full-width mirrored band (T2 component, T7 band), seekable scrub (T7), shuffle+repeat (T7), real cava (T1), mirrored up+down bars (T2), blurred art backdrop (T7), Theme tokens 32/210 (T7), component split incl. extracted CoverArt + retired Eq (T2/T3), in-container cava feasibility + fallback note (T1). All covered.

**Type consistency:** `Cava.values`/`Cava.enabled`/`Cava.bars` consistent across T1/T2/T6/T7. `Visualizer.values/barWidth/maxH/minH/color` consistent T2/T6/T7. `MediaButton.icon/enabled/active/size/clicked` consistent T5/T6/T7. `ProgressRing.value/ringWidth/color/content` T4/T6. `MiniPlayer.player/hovered/bucket` T6/T7. `FullPlayer.player` T7. MPRIS props (`shuffleSupported/shuffle/loopState/canSeek/position/length/canControl`) match `Players.qml`'s documented surface and `MprisLoopState` enum.

**Known verification points (flagged in steps, not blockers):**
- In-container cava capturing host audio (T1 Step 1 gates this; pipewire fallback inline).
- `QtQuick.Shapes` / `QtQuick.Effects` (MultiEffect) present in the container (T4 Step 2 / T7 — install qt6 modules if a journal "not installed" appears).
- MPRIS `position` writable for seek (T7 Step 4 verifies; if it doesn't seek, fall back to `player.seek(targetSeconds - player.position)`).
- `bar.components` import resolution for MiniPlayer/FullPlayer (T7 Step 3 point 6).
