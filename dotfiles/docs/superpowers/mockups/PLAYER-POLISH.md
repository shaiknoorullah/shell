# Parked: notch media-player polish (do later, not now)

> Parked 2026-06-18 by deliberate choice — the notch *shape/morph* is good; only
> the **expanded player layout** needs the aesthetic pass. Captured here so it's
> not lost. Do NOT let this block Phase 0.

**What's wrong now:** placeholder gradient instead of real cover art; a weak
5-bar EQ that reads as generic.

**Target design — caelestia style** (refs: `caelestia-dots/shell`
`modules/dashboard/dash/Media.qml` + `modules/background/Visualiser.qml`):
- **Real square cover art** (a `cover.jpg` is already fetched in this dir) with a
  **wavy circular progress arc wrapping the cover** (`CircularProgress wavy:true
  waveFrequency:8`) — not a flat scrubber bar. This is the signature vibe.
- **Centered** title (primary) / album (outline) / artist (secondary) under cover.
- **Tonal round transport buttons** (skip_previous / play_arrow-pause / skip_next),
  round + `shapeMorph`, the play button fill-width/accent.
- **Cava visualiser where the spectrum bars MASK a blurred cover/wallpaper** (the
  bars are cut out of a blurred image — `MultiEffect` mask), rounded bar tops,
  `primary`/`inversePrimary` alpha 0.7. Replaces the 5-bar EQ.

eww translation: cover via `image`; blurred-cover-masked cava via a `cava` script
→ eww `graph`/canvas or a row of gradient bars over a blurred `background-image`;
circular arc via an SVG/`progress` ring. All eww-portable; just more work.
