# Notch Music Widget Redesign — Design

> Redesign the Dynamic Island (`bar/Island.qml`) music widget: a richer
> collapsed pill, a polished expanded player, and a **real reactive cava
> visualizer** with **symmetric (mirrored) bars**. Replaces the current basic
> collapsed layer (17px art · fake top-only "eq" · title) and the no-frills
> expanded player.

- **Date:** 2026-06-19
- **Status:** Approved layout, pending implementation plan
- **Repo area:** `private_dot_config/quickshell/`

## Problem

The collapsed notch is "very very basic and has no controls": a 17px circle,
a faked equaliser whose bars only grow upward (bottom edge pinned via
`anchors.bottom`), and a truncated title. The expanded player exists (hover/
click) but reads as plain. The user wants a researched, good-looking redesign of
both states with a real audio-reactive visualizer that moves up **and** down.

## Decisions (from brainstorming)

- **Scope:** full redesign of BOTH states.
- **Visualizer:** **real cava** (reactive to actual audio), mirrored bars.
- **Collapsed layout:** info-forward — art+progress-ring · title · cava;
  on hover the cava cross-fades into prev/play-pause/next.
- **Expanded extras:** shuffle + repeat (in addition to prev/play-pause/next).
- **Collapsed height:** 32px (uniform with the floating glass pills).
- **Expanded height:** 210px (up from 194 to fit the cava band).

## Feasibility (verified)

- Host runs **pipewire + wireplumber**; `cava` is installed on the host.
- The `arch` distrobox **already sees** `pipewire-0` and `pulse` sockets via the
  shared `XDG_RUNTIME_DIR` (`/run/user/1001`).
- `cava` is **not yet installed in the container** — install it there
  (`distrobox enter arch -- sudo pacman -S --noconfirm cava`).
- MPRIS already works in-container (the current island shows live cover art +
  title), so transport/shuffle/repeat/seek bind to the native
  `Quickshell.Services.Mpris` service directly — **no host bridge** needed for
  controls. Only the audio spectrum needs cava.

## Layout (approved)

### Collapsed (height 32, width content-driven, morphs on hover)
```
RESTING                                   HOVER (cava ⇄ controls crossfade)
╭──────────────────────────────────╮      ╭────────────────────────────────────╮
│ ◉  Bohemian Rhapsody  ▃▅█▆▄▂▄▆ │      │ ◉  Bohemian Rhapsody  ⏮ ⏯ ⏭ │
╰──────────────────────────────────╯      ╰────────────────────────────────────╯
  20px art + 2px progress ring     ~7 mirrored cava bars (real audio)
```
- Art 20px circle wrapped by a 2px **progress ring** (playback fraction).
- Title elided, max ~150px.
- ~7 mirrored cava bars (grow up+down from centre), accent-coloured.
- On hover: cava cross-fades out, prev/play-pause/next fade in.

### Expanded (396 × 210, click-pin / hover-peek)
```
╭──────────────────────────────────────────────────────╮
│  ┌────────┐   Bohemian Rhapsody                       │
│  │  ART   │   Queen · A Night at the Opera            │
│  │  64px  │   ╭● deep block · 47m → ʿAsr ╮            │
│  └────────┘   ╰────────────────────────────╯          │
│  ▁▂▃▅▇█▇▅▃▂▁  mirrored cava band (full width)  ▂▃▅▇  │
│  0:47 ●────────────────────────────────────  3:21    │
│      ⇄     ⏮      ⏯ 40px      ⏭     🔀            │
╰──────────────────────────────────────────────────────╯
```
- Row 1: 64px rounded art · title (bold) · artist·album (dim) · live-activity
  pill (focus/salah — kept).
- A faint **blurred album-art backdrop** behind the body for art-driven ambiance
  (cheaper and richer than dominant-colour extraction).
- Full-width mirrored cava band (~24px tall) — hero motion element.
- Seekable scrub: elapsed · draggable track · total.
- Transport: shuffle (⇄ left) · prev · play-pause (40px) · next · repeat (🔀 right).

## Architecture

The current `Island.qml` mixes morph state, both layers, and an inline
`CoverArt` in one file. Split into focused, independently-understandable units
(the morph shell composes two dumb layers; the visualizer is data-driven; the
audio source is a singleton service):

### New / changed files
| File | Role | Depends on |
|---|---|---|
| `bar/Island.qml` | Morph shell: state (`open`/`hovered`/`pinned`), sizing/morph animation, body `Rectangle`, MouseArea, layer cross-fade. Composes `MiniPlayer` + `FullPlayer`. | MiniPlayer, FullPlayer, Theme |
| `bar/components/MiniPlayer.qml` | Collapsed layer: art+ring · title · (cava ⇄ transport on hover). | CoverArt, ProgressRing, Visualizer, MediaButton, Players, Cava, Theme |
| `bar/components/FullPlayer.qml` | Expanded layer: art backdrop, row 1, cava band, scrub, transport (incl. shuffle/repeat). | CoverArt, Visualizer, MediaButton, Players, Focus, Cava, Theme |
| `components/CoverArt.qml` | Extracted from Island: rounded MPRIS art tile with Dracula-gradient fallback. | (none beyond Theme) |
| `components/ProgressRing.qml` | Thin circular arc showing `value` (0..1), via `QtQuick.Shapes`. | Theme |
| `components/Visualizer.qml` | Data-driven mirrored bar renderer: `values: var` (array 0..1), `bars`, `barWidth`, `gap`, `maxH`, `minH`, `color`, `mirrored`. Bars anchored to `verticalCenter`. Replaces `components/Eq.qml`. | Theme |
| `services/Cava.qml` | Singleton `CavaProvider`: launches in-container `cava` (raw ascii stdout), parses each frame into a normalized `values` array property; exposes `bars` (configurable) and `active`. | Quickshell.Io (Process) |
| `components/MediaButton.qml` | Reusable transport/toggle button (glyph, enabled, active state, hover, clicked). Generalises the existing inline `IslandButton`. | Theme |

### Removed
- `components/Eq.qml` (superseded by `Visualizer.qml`; only consumer is the island).

## Component contracts

**`services/Cava.qml` (singleton `Cava`)**
- `property int bars` — number of frequency bands (default 24; collapsed asks for ~7 via its own Visualizer slice or a second instance).
- `readonly property var values` — array of `bars` reals in 0..1, updated each frame.
- `readonly property bool active` — true while the cava Process is running.
- Implementation: a `Process` runs `cava -p <generated-config>` inside the
  container. Config writes raw **ascii** to stdout (`method=raw`,
  `data_format=ascii`, `ascii_max_range=1000`, `bars=<N>`, framerate ~60,
  `[input] method=pulse` or `pipewire`). A `SplitParser { splitMarker: "\n" }`
  on stdout parses each `;`-separated line → normalized array → `values`.
  Process auto-restarts if cava dies. When no audio/idle, cava emits zeros, so
  bars settle flat (calm, not frozen).
- **Single source, single instance** — one `Cava` service runs with `bars: 24`.
  Both layers read the same `Cava.values`; the collapsed `Visualizer` renders
  fewer bars (~7) by bucket-averaging the 24-length array down (no second cava
  process). Gate the Process `running` on `Players.active !== null && isPlaying`
  to avoid capturing audio needlessly.

**`components/Visualizer.qml`**
- Pure presentation. Renders `values` as a `Row` of `Rectangle` bars, each
  `height: minH + value*(maxH-minH)`, `anchors.verticalCenter: parent` →
  symmetric growth up+down. Smooths via `Behavior on height` (short, ~80ms).
  `mirrored` optionally reflects low→high→low across the band.

**`components/ProgressRing.qml`**
- `property real value` (0..1), `property int ringWidth`, `color`, `track`.
  Draws a background ring + an accent arc `0 → 360*value` using
  `QtQuick.Shapes` (`PathAngleArc`). Holds a `CoverArt` (or any item) via a
  `default property alias content` so it wraps the album art.

**`components/MediaButton.qml`**
- `glyph` (Material Symbol / Nerd glyph), `enabled`, `active` (for shuffle/repeat
  on-state highlight), `size`; emits `clicked`. Dims when `!enabled`, accent
  when `active`.

## Data flow

- **Metadata/art/state/controls** → `Players.active` (native MPRIS
  `MprisPlayer`): `trackTitle/Artist/Album`, `trackArtUrl`, `position`,
  `length`, `isPlaying`, `canGoNext/Previous/Seek/Control`, `shuffle` (r/w),
  `loopState` (r/w None/Track/Playlist), `next()/previous()/togglePlaying()`.
  Position self-ticks via the existing 1s `positionChanged()` timer while open.
- **Seek** → drag on the scrub track sets `player.position = frac*player.length`
  when `canSeek`.
- **Spectrum** → `Cava.values` (the new service).
- **Live-activity pill** → `Focus` service (unchanged).
- **Accent** → `Theme.ctxAccent` (unchanged), plus the blurred art backdrop.

## Theme changes (`services/Theme.qml`)
- `notchH: 30 → 32`.
- `notchOpenH: 194 → 210`.
- `notchW` / `notchHoverW`: collapsed width becomes **content-driven** (mini
  layer implicit width + padding, clamped to a max ~320) so variable title
  lengths don't need hardcoded pixels; the morph `Behavior on width` animates
  transitions. Keep `notchOpenW: 396` fixed. (Existing tokens may be repurposed
  as the max-width clamp.)

## Motion
- Keep the existing Emphasized morph curves for width/height/radius.
- Visualizer bars: short `Behavior on height` (~80ms, OutSine) for smooth,
  non-jittery reaction.
- Collapsed hover cross-fade (cava ⇄ transport): opacity Behavior ~`durFast`.
- Layer cross-fade (mini ⇄ full): unchanged.

## Risks & validation
1. **In-container cava capturing host audio** — sockets are visible but must be
   verified at runtime. Validation: install cava in `arch`, run
   `cava -p <cfg>` in-container while audio plays, confirm non-zero output.
   **Fallback** (only if it fails): run cava on the host writing raw frames to a
   FIFO/file in `~/.cache/adhd/`, read via quickshell `FileView` — matching the
   repo's existing host-bridge pattern.
2. **Seek precision** — `position` units. Confirm `MprisPlayer.position`/`length`
   are seconds (the current `fmtTime` treats them as seconds) before wiring drag.
3. **Cava CPU** — gate the Process on a player being present/playing; ~60fps raw
   ascii of 24 bars is cheap, but don't run it with nothing playing.
4. **Art backdrop blur** — use Qt6 `MultiEffect` (or a pre-blurred low-opacity
   `Image`); verify it renders under software fallback if GPU path regresses.

## Out of scope
- Synced lyrics (caelestia has them; not requested).
- Dominant-colour extraction (using blurred-art backdrop instead).
- Volume slider / like button (deferred per the extras decision).

## Verification (per change, the repo loop)
`chezmoi apply --force` → restart `quickshell-bar` → check journal for QML
errors → screenshot collapsed (resting + hover) and expanded (pinned) from the
container; confirm bars move up+down, controls work, seek works, shuffle/repeat
toggle, ring tracks position.
