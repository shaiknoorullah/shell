# Phase 2 — Surfacing (3-bar eww desktop) Implementation Plan

> **For agentic workers:** Execution is **Workflow/subagent-team driven**. Subagents author eww widgets + backing data scripts into the chezmoi source; the main loop gates `chezmoi apply` + `eww reload`. Steps use checkbox (`- [ ]`).

**Goal:** Externalize the ADHD engine onto the screen — a top bar (with the Dynamic-Island notch), a summoned left "what am I chasing" bar, and a bottom context bar — all eww, Dracula, calm, reading the live taskwarrior/timewarrior/i3/git state from Phase 1.

**Architecture:** One eww config (`~/.config/eww/`, extending the existing Dracula notification center). Each bar is a `defwindow`; reactive state comes from small `deflisten`/`defpoll` backend scripts (`~/.local/bin/eww-*`). Styling is SCSS templated from `.chezmoidata.yaml` (one palette → all widgets). The mockup `docs/superpowers/mockups/adhd-os.html` is the **exact visual spec** — port its layout, the alpha-ladder, radii (card 16 / bar 24 / pill 99), and motion (revealer slides ~250ms, no bounce) into eww GTK CSS.

**Tech Stack:** eww 0.6.0 (GTK/X11), SCSS, bash backends, i3 (`i3-msg -t subscribe`), taskwarrior/timewarrior (Phase 1), playerctl (media), git, jq, chezmoi (deploy + SCSS template), bats (backend-script tests).

## Global Constraints

- **Dracula from one source** — `eww.scss` is a chezmoi `.tmpl` pulling every color from `.chezmoidata.yaml`. No hand-typed hex in widget styles.
- **Calm motion only** — revealer slides/fades ≤300ms, no overshoot on ambient widgets (the Dynamic Island morph may use a gentle spring; nothing else does). ADHD-first.
- **Reads Phase 1** — active task + elapsed from `task`/`timew` (via `/usr/bin/task`, go-task shadows PATH); the left-bar big timer reads `adhd-focus.sh status`; context from `~/.cache/ctx`.
- **Shame-free stats** — the bottom bar shows consistency/focus-score/streak/encouragement; never red "broken streak."
- **Backends are testable** — each `eww-*` data script emits JSON/text and gets a bats test with mocked `task`/`timew`/`i3-msg`/`playerctl`/`git`.
- **Authored in chezmoi source** (`dot_config/eww/...`, `dot_local/bin/executable_eww-*`); deploy via gated `chezmoi apply` + `eww reload`. Never write live eww config directly.
- Keep the existing Dracula **notification center** working; add bars alongside it.

## File Structure

```
dot_config/eww/
  eww.yuck                      # top-level: defwindows + defpolls/deflistens + includes
  eww.scss.tmpl                 # Dracula tokens (from .chezmoidata) + all widget styles
  widgets/{topbar,island,bottombar,leftbar}.yuck   # one file per bar (kept focused)
dot_local/bin/
  executable_eww-ctx.sh         # current context (name+accent) from ~/.cache/ctx
  executable_eww-active.sh      # active task + live elapsed (task+timew) -> JSON
  executable_eww-workspaces.sh  # i3 workspaces (deflisten on i3-msg subscribe) -> JSON
  executable_eww-media.sh       # playerctl now-playing -> JSON (for the island)
  executable_eww-stats.sh       # focus-score/streak/coffee/walks (from a small JSON log)
  executable_eww-sessions.sh    # tmux sessions grouped by context -> JSON (left bar)
```

---

### Task 1: eww scaffold + Dracula SCSS tokens

**Files:** Create `dot_config/eww/eww.yuck`, `dot_config/eww/eww.scss.tmpl`.

- [ ] **Step 1: Write `eww.scss.tmpl`** — define SCSS vars from the palette, then the alpha-ladder helpers. Header:

```scss
// Generated from .chezmoidata.yaml — do not hand-edit hex.
$base: #{{ .dracula.base }}; $fg: #{{ .dracula.fg }}; $comment: #{{ .dracula.comment }};
$purple: #{{ .dracula.purple }}; $pink: #{{ .dracula.pink }}; $cyan: #{{ .dracula.cyan }};
$green: #{{ .dracula.green }}; $red: #{{ .dracula.red }}; $yellow: #{{ .dracula.yellow }};
$surface0: #{{ .dracula.surface0 }}; $surface1: #{{ .dracula.surface1 }};
$glass: rgba(40,42,54,.72);
* { all: unset; font-family: "JetBrainsMono Nerd Font"; }
.barpill { background:$glass; border:1px solid rgba(248,248,242,.09); border-radius:99px; }
// …port the rest from the mockup CSS (alpha-ladder, radii 16/24/99)…
```

- [ ] **Step 2: Write a minimal `eww.yuck`** with one trivial `defwindow probe` (a label) to prove eww opens.

- [ ] **Step 3: Verify render (gated, main loop)** — `chezmoi apply && eww open probe && sleep 1 && eww close probe`. Expected: a labeled window appears. Then remove `probe`.

- [ ] **Step 4: Commit** — `git add dot_config/eww && git commit -m "feat(eww): scaffold + Dracula SCSS tokens"`.

---

### Task 2: Backend data scripts (with bats tests)

**Files:** Create the `dot_local/bin/executable_eww-*.sh` listed above; `tests/test_eww_backends.bats`.

- [ ] **Step 1: Write the failing test** — for each backend, assert it emits valid JSON with the expected keys (mock `task`/`timew`/`i3-msg`/`playerctl`). Example:

```bash
@test "eww-active: emits task + elapsed json" {
  run bash "$BATS_TEST_DIRNAME/../dot_local/bin/executable_eww-active.sh"
  echo "$output" | jq -e '.task and .elapsed' >/dev/null
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement each backend** — e.g. `eww-active.sh`:

```bash
#!/usr/bin/env bash
TASK="${TASK_BIN:-/usr/bin/task}"
id=$("$TASK" +ACTIVE ids 2>/dev/null | head -1)
desc=$("$TASK" _get "$id".description 2>/dev/null)
elapsed=$(timew get dom.active.duration 2>/dev/null || echo "0:00")
printf '{"task":"%s","elapsed":"%s"}\n' "${desc:-—}" "$elapsed"
```
(Similarly `eww-ctx`, `eww-workspaces` via `i3-msg -t get_workspaces | jq`, `eww-media` via `playerctl metadata --format`, `eww-stats` from a `~/.local/share/adhd/stats.json`, `eww-sessions` via `tmux list-sessions`.)

- [ ] **Step 4: Run tests, verify pass.**
- [ ] **Step 5: Commit** — `git add dot_local/bin/executable_eww-* tests/test_eww_backends.bats && git commit -m "feat(eww): backend data scripts + tests"`.

---

### Task 3: Top bar (workspaces · window · clock · controls)

**Files:** Create `dot_config/eww/widgets/topbar.yuck`; include it in `eww.yuck` with a `defwindow topbar` (anchored top, two flanking pills per the mockup). Port layout/spacing from the mockup's `#top` + `.barpill`.

- [ ] Steps: write the `defwidget topbar` (left pill: ctx pill + `eww-workspaces` + focused window; right pill: clock + `eww-media` mini + vol/notif). Wire `defpoll`/`deflisten` to the Task-2 backends. Verify with `chezmoi apply && eww open topbar`. Commit.

---

### Task 4: Dynamic Island (notch) on the top bar

**Files:** Create `dot_config/eww/widgets/island.yuck`; CSS in `eww.scss.tmpl`. Port the mockup's `#notch` (OLED top-edge carve, rounded bottom, self-morph) + the `.full` player. Collapsed = album art + cava-ish bars + track; open = media player + live-activity row (reads `adhd-focus.sh status`).

- [ ] Steps: build the notch as an eww window/widget centered at top:0; `revealer`/state var for open; `eww-media` + `adhd-focus.sh status` backends; toggle on click. Honest cut: full caelestia cava-over-blurred-cover is the parked polish (`mockups/PLAYER-POLISH.md`) — ship a clean gradient-bar version first. Verify, commit.

---

### Task 5: Bottom context bar

**Files:** `dot_config/eww/widgets/bottombar.yuck` + `defwindow bottombar` (anchored bottom). Port the mockup `#bottom`: left = project · context · branch (git); center = active task + elapsed (`eww-active`); right = focus-score · streak · coffee · walks · encouragement (`eww-stats`). Shame-free.

- [ ] Steps: build widget, wire `eww-active`/`eww-stats`/git branch poll. Verify, commit.

---

### Task 6: Left bar (summoned "what am I chasing")

**Files:** `dot_config/eww/widgets/leftbar.yuck` + `defwindow leftbar` (slide-in from left, `revealer slideright 250ms`, hidden by default). Port the mockup `#left`: big timer (`adhd-focus.sh status`), salah strip (today's daily-note frontmatter), now/next tasks (`task +today`/`+next`), calendar (today's events — stub or `khal`/ical later), learning (spaced-rep due — vault), master-agent strip (LiteLLM input → Phase D). Hides the bottom bar when open.

- [ ] Steps: build widget + a state var `leftbar_open`; wire backends; bottom-bar hides when open. Verify, commit.

---

### Task 7: i3 integration (autostart + toggles + focus mode)

**Files:** Modify `dot_config/i3/config.tmpl`.

- [ ] Add `exec_always --no-startup-id eww daemon && eww open topbar bottombar` (replace polybar autostart, or run both during transition).
- [ ] Bindings: a key to toggle the left bar (`eww update leftbar_open=...`), a key for focus mode (collapse bars). Avoid taken combos.
- [ ] Verify `chezmoi apply` + reload i3; bars appear, left bar toggles. Commit.

---

## Self-Review

- **Spec coverage:** §15 three bars → T3/T5/T6; §25 Dynamic Island → T4; backends surface Phase-1 engine (§14) → T2; Dracula token system → T1. Dashboard/control-center, session-switcher popup, menus (launcher/power/OSD), and the §26 floating popup apps (master-agent console, music player) are **deferred to Phase 3**.
- **Continuity:** the left-bar timer + bottom-bar task read Phase 1's `adhd-focus.sh`/`task`/`timew` — Phase 2 makes Phase 1 observable. ✓
- **Risk:** eww widgets aren't unit-testable; mitigated by testing the **backends** (T2) and gating each `eww open` render review. ✓
- **Polybar→eww:** T7 transitions the bar; keep polybar runnable during the swap, retire once eww bars are stable.

## Deferred to Phase 3 (own plan)

Control-center dashboard (kanban from taskwarrior, pomodoro→Flowtime card, QuickSettings) · session/agent switcher · menus (hover-dock launcher, two-click power, gradient OSD) · floating popups: master-agent console + music player (§26) · player polish (`mockups/PLAYER-POLISH.md`).
