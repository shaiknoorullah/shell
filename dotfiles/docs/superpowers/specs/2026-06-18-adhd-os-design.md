# Context-Driven ADHD OS on i3 — Design

> Status: **DRAFT for review** · Date: 2026-06-18 · Owner: shaiknoorullah
> Repo: `ubuntu-dots` · Branch: `rice/adhd-os-design`

A desktop + workflow system for Ubuntu 24.04 / X11 / i3, whose primary goal is
**ADHD support**: protect attention, make work observable, and minimize the
number of decisions required to start and sustain focused work. Aesthetic and
"ricing" are in service of that goal, not the goal itself.

---

## 1. Why (research findings)

Gathered from this machine, both GitHub accounts, the Obsidian vault, and the
Aether repo (2026-06-17/18).

- **The operator profile.** DevOps-heavy engineer + manager at ProficientNow by
  day (`snoorullah`: pnow-ats-v2, ArgoCD/SigNoz/Entra admin, two k8s prod
  clusters, a 99-worktree monorepo); AI-agent-tooling builder by night
  (`shaiknoorullah`: opsbench, agenthive, Aether — 100 repos). Runs **~20 tmux
  sessions and ~49 Claude project dirs simultaneously.** GitHub stars cluster on
  ADHD/focus tooling — this system shares the thesis of his own projects.
- **Five systemic problems** (mapped to the operator's stated pains A–E + 1–6):
  1. Context sprawl with no boundaries — one undifferentiated browser profile
     holds work + Microsoft admin + personal + AI. (D, #1, #6)
  2. Zero surfacing — nothing shows what is live, what is next, or where time
     went. `taskwarrior` + `timewarrior` are installed but **unconfigured**;
     polybar shows only workspaces + a clock. (A, B, C, #2, #3)
  3. No capture path — ideas die for lack of a friction-free dump. (A)
  4. Recurring-work overload — ArgoCD checks, monitoring, PR reviews, incidents,
     notes — all manual, re-decided daily. (#4, #5)
  5. **The Life-OS paradox** — the `powerhouse` vault is exquisitely
     over-architected (1,184 notes, 7-layer meta-system, 25 agent specs,
     pre-registered research hypotheses) and **barely used as a daily tool**
     (3 daily notes ever, last 2026-03-22; runtime "blocked on a companion
     codebase that does not exist"). Designing the system has become a
     procrastination object. **This system must not feed that beast.**
- **Decided by research:**
  - The browser wants (fuzzy tab search, fuzzy profile/container switch,
    minimalism) need **no browser fork**: Zen + Tridactyl + Multi-Account
    Containers + a rofi profile launcher. Aether's grand features (Spectator,
    resident agents, per-project history) are correctly cut as YAGNI;
    ActivityWatch covers behavioral tracking if ever wanted.
  - Capture hook already exists: **Obsidian `local-rest-api` is live on
    `https://127.0.0.1:27124` with an API key** — an i3 keybind can POST a
    thought into the vault with zero context switch.

## 2. Goals / Non-goals

**Goals**
- Make starting and resuming work cheap (initiation + context-switch cost).
- Make the day observable: active task, live timer, live sessions, infra health,
  recurring rituals, time-spent — all glanceable.
- Frictionless capture so no idea or task is lost.
- Long-term time/activity data for later workflow optimization.
- One source of truth for theme (Dracula); one action to switch context.

**Non-goals (YAGNI)**
- No Wayland / Hyprland migration (stay i3/X11). Quickshell is therefore out.
- No browser fork; no Aether Spectator / resident agents / durable workflows.
- No extension of the vault meta-system. We integrate with it via the simplest
  stable surface (REST API + daily notes) and leave seams for later.
- No bespoke runtime for the vault's agent architecture.

## 3. The Context model (backbone)

A **Context** is the unit everything hangs off. Switching context is *one action*
that reconfigures the machine. Four contexts, each with a Dracula accent:

| Context | Accent | Browser | tmux sessions | taskwarrior project | Dirs / accounts |
|---|---|---|---|---|---|
| `work` | purple `#BD93F9` | Zen profile/container: ProficientNow (Google + Entra/M365) | pnow-*, pn-infra, pnats-*, fleet-*, ovh-*, rule-engine, automation-service, manageengine | `work.*` | `~/work`, snoorullah GH, clusters: ovh + prod-ap-south-2a |
| `lab` | pink `#FF79C6` | Zen profile/container: personal GitHub/OSS | dots, opsbench, nanoclaw, powerhouse, rofi, polybar | `lab.*` | `~/development`, shaiknoorullah GH |
| `agents` | cyan `#8BE9FD` | container: Claude/AI logins | pi, remote-cli-session, agent panes (pi-fleet) | `agents.*` | `~/.claude/projects`, pi-fleet |
| `personal` | green `#50FA7B` | profile: personal life (separate logins) | powerhouse (life), media | `personal.*` | `~/powerhouse`, finance/learning |

Two **cross-cutting pillars** (functions, not silos) surfaced on the dashboard
regardless of context: **Time/Task tracking** and **Learning tracking**
(spaced-repetition due, current courses from `~/powerhouse/learning/`).

> The context→(browser, tmux, task, accent) mapping above is the single most
> important artifact; it is the seed config every layer reads.

## 4. Architecture (layers)

```
CONTEXT  work · lab · agents · personal   — one keybind reconfigures all of:
         browser profile/containers · tmux group · taskwarrior project · accent · dashboard filter

L1 CAPTURE      $mod+key → 2s input → Obsidian REST (:27124) inbox  [+ optional task add]
L2 TIME+TASK    taskwarrior (ctx-namespaced) + timewarrior (auto-start on task start) +
                Flowtime deep-focus daemon (count-up, prayer-scaffolded) + "start ritual"
L3 SURFACING    eww BAR (context · task+timer · #live sessions/agents · argocd/signoz glyph ·
                PR count · next event) + eww DASHBOARD (Today / Live work / Infra / Rituals /
                Learning) + eww SWITCHER (fuzzy jump across tmux sessions + Claude projects)
L4 BROWSER      Zen (vertical tabs + compact + workspaces) · Tridactyl rc · Multi-Account
                Containers · rofi profile launcher · wifi/bt/system menus
L5 LOOK+HYGIENE Dracula token system → i3/rofi/polybar/kitty/picom · themed lock/login/wallpaper ·
                fix repo drift · secrets hygiene
```

**Design principles**
- Each layer is independently usable and testable; layers talk through small,
  documented interfaces (a file, a CLI, an HTTP endpoint), not shared internals.
- One palette source of truth (`themes/dracula.*`) feeds every component by
  generation/import — never hand-copied hex.
- The system decides; the operator executes. Defaults everywhere.

## 5. Aesthetic

**Dracula**, everywhere. The eww notification center is already Dracula and is
the reference. Everything else (i3, rofi, polybar→eww, kitty, picom tints) is
re-themed *to* Dracula. Per-context accent colors (§3) ride on top of the base
palette. Font stays JetBrainsMono Nerd Font.

## 6. Vault integration (capture-now, integrate-later)

- **Now:** desktop writes captures and daily-note entries through
  `local-rest-api` (`:27124`, API key as a chezmoi-managed encrypted secret).
  Target a single inbox
  surface — `journal/daily/DD-MM-YYYY.md` under an `## Inbox` heading (created
  from a Templater daily template if missing).
- **Seams for later:** captures carry a `context` tag and ISO timestamp so the
  eventual vault runtime can route them into the 7-layer model without rework.
- We do **not** touch `blueprint/`, `agents/`, or the meta-system spec.

## 7. Roadmap

| Phase | Delivers | Pains | Effort | Deps |
|---|---|---|---|---|
| **0 Foundation** | secrets hygiene · fix repo drift · Dracula token system + retheme i3/rofi/polybar/kitty · deploy script + README | "fix & finish" | ½–1d | — |
| **1 ADHD core** | taskwarrior+timewarrior · capture keybind→vault · Flowtime deep-focus daemon · idle-catch · start-ritual | A,B,C,#2,#3 | 1–2d | 0 |
| **2 Surfacing** | eww bar · control-center dashboard · session/agent switcher | #1,#4,D + pillars | 2–3d | 1 |
| **3 Browser** | Zen+Tridactyl+Containers · rofi profile launcher · wifi/system menus | #6,E | 1d | 0 |
| **4 Polish** | themed lock/login · wallpaper-per-context · animations | finish | ½d | 0–3 |

Each phase gets its own implementation plan and review gate.

---

## 8. Phase 0 spec — Foundation & hygiene

**Goal:** a clean, secure, single-theme base that every later phase inherits.

### 0.1 Secrets hygiene (via chezmoi)
- Rotate the OpenAI key currently plaintext in `~/.zshrc` (`CZ_OPENAI_API_KEY`)
  and the LiteLLM key. (Operator action — Claude cannot rotate provider keys.)
- Adopt **chezmoi** as the dotfiles manager (decision 2026-06-18). Store both
  keys + the Obsidian REST API key as chezmoi **encrypted** secrets (age or gpg),
  injected into a sourced env file via a `.tmpl` — never plaintext in a tracked
  file. `~/.zshrc` sources the rendered env file.
- Acceptance: `git grep` over the chezmoi source finds no `sk-` / API tokens
  (only encrypted blobs or template refs); new shell still has the env vars.

### 0.2 Fix repo drift (the "fix & finish" scope item)
- **Missing scripts** referenced by `i3/config` but absent: `rofilaunch.sh`,
  `rofi-style-selector.sh`, `rofi-websearch-v2.sh`, `zen-tab-popup.sh`,
  `zen-workspaces.sh`. For each: either commit the real script (if it exists on
  disk in `~/.config/rofi/scripts/`) or repoint the binding to the existing
  equivalent (e.g. `rofi-websearch.sh`) and update README + tests.
- **Failing tests:** reconcile `i3/config` ↔ `rofi/README.md` ↔
  `rofi/tests/test_i3_keybindings.bats` to one keybinding scheme; get the suite
  to **146/146**.
- **picom path bug:** `picom/launch.sh` loads `~/.config/picom.conf` but the file
  deploys to `~/.config/picom/picom.conf`; fix the path. Sync README's picom
  numbers (blur strength, opacity) to the actual config, or add the missing
  `class_g = 'Rofi'` opacity rule the blur trick documents.
- Acceptance: `cd rofi/tests && bats test_*.bats` → 0 failures; every script a
  binding references exists in-repo; picom launches from the deployed path.

### 0.3 Dracula token system
- Define the **single palette source** in chezmoi's `.chezmoidata.yaml`:
  base `#282A36`, bg-dark `#141313`, fg `#F8F8F2`, comment `#6272A4`,
  purple `#BD93F9`, pink `#FF79C6`, cyan `#8BE9FD`, green `#50FA7B`,
  orange `#FFB86C`, red `#FF5555`, yellow `#F1FA8C`, plus the four context accents.
- Each themed config becomes a chezmoi **template** (`.tmpl`) pulling colors from
  that data: i3 colors, rofi `themes/shared/dracula.rasi` (replacing
  catppuccin-mocha), polybar `[colors]`, kitty `current-theme.conf`, picom tint,
  eww `.scss`. No custom `gen-theme.sh` needed — `chezmoi apply` renders all.
- Acceptance: changing one hex in `.chezmoidata.yaml` + `chezmoi apply` updates
  every component; no rendered config contains a hand-typed Dracula hex.

### 0.4 Deploy mechanism + README (chezmoi)
- Migrate the repo into a chezmoi source layout (`dot_config/...`, `.tmpl` for
  themed/secret files, `.chezmoidata.yaml` for tokens). Provide a bootstrap
  (`chezmoi init` + `apply`) and a top-level `README.md` (install, layout, theme,
  phases). Note: this restructures `ubuntu-dots` from raw dirs to chezmoi source.
- Acceptance: `chezmoi apply` on a clean machine renders/links every config
  correctly, secrets decrypt, theme renders; documented in README.

## 9. Phase 1 spec — ADHD core

**Goal:** capture nothing-is-lost + a task/time engine that makes starting cheap
and the day observable.

### 1.1 taskwarrior
- `~/.taskrc` with context-namespaced projects (`work.*`, `lab.*`, `agents.*`,
  `personal.*`), urgency tuned for ADHD (small, near-term, "next" tag), and
  `task context` definitions matching the four contexts.
- Acceptance: `task add project:work.ats "x"`, `task work next` filters correctly.

### 1.2 timewarrior + hook
- Initialize timewarrior; install the `on-modify` taskwarrior hook so starting a
  task (`task start`) auto-starts a timew interval tagged with the project +
  context; stopping/done stops it.
- Acceptance: `task start <id>` produces a running `timew` interval with the
  right tags; `timew summary` shows per-context time.

### 1.3 Capture keybind
- `scripts/capture.sh`: pop a minimal rofi (or eww) single-line input; on submit,
  POST to Obsidian REST `:27124` appending to today's `## Inbox`; if the text
  starts with `t:` / `task:`, also `task add` it into the current context.
- Bind in i3 (e.g. `$mod+Shift+space`). Current context read from a state file
  `~/.cache/ctx` (written by the context switcher; defaults to `personal`).
- Acceptance: keybind → type → entry lands in today's daily note within ~1s;
  `t: …` also creates a task; works with no Obsidian window focused.

### 1.4 Deep-focus daemon (Flowtime + prayer-scaffold — NOT pomodoro)
> Supersedes any "pomodoro" wording elsewhere. Rationale + detail in §14.
- `scripts/focus.sh` runs a **Flowtime** session: counts **up** from 0 (no fixed
  box, overtime never force-stops), one task, tagged into timew. Breaks are
  **earned/scaffolded**, not forced — the big timer counts toward the **next
  salah**; a **gentle, dismissible** dunst nudge fires only if a single session
  exceeds ~90 min (operator decision 2026-06-18). Hard lock/dim stays opt-in.
- Acceptance: `focus start <task>` starts a count-up timew interval; the ~90-min
  nudge appears and is dismissible; no session is ever auto-terminated.

### 1.5 Start ritual
- `scripts/start.sh`: rofi-pick a `next` task → `task start` (→ timer) → switch to
  its context (browser profile group + tmux session) → begin. One command from
  "I should work" to "working."
- Acceptance: one invocation selects a task, starts the timer, and lands the
  operator in the right tmux session + browser context.

---

## 10. Open questions for review

1. **Context list final?** Four contexts (work/lab/agents/personal) with the
   tmux/dir mapping in §3 — correct, or split/merge any?
2. **Capture target:** daily-note `## Inbox` (chosen) vs a dedicated
   `journal/inbox.md` rolling file — preference?
3. ~~Break enforcement~~ — **RESOLVED 2026-06-18: prayer-scaffolded Flowtime with
   a gentle, dismissible ~90-min nudge** (no pomodoro, no forced break). See §14.
4. **Phase 0.2 scope:** if the five "missing" scripts genuinely don't exist on
   disk, are you OK with me repointing those bindings to existing equivalents
   rather than writing new menu scripts now (deferring new menus to later)?
5. ~~Stow vs symlink~~ — **RESOLVED 2026-06-18: chezmoi** (templating for theme
   tokens + encrypted secrets). Phase 0.4 restructures the repo to chezmoi source
   layout; confirm you're OK with that restructure.

---

## 11. Aesthetic & Motion system (cross-cutting; feeds Phases 0, 2, 3)

Derived from studying `haikal-hakim/athena-eww` (the eww blueprint),
`matteogini/dotfiles` (OLED-minimal), `caelestia-dots` (Material-3 token
discipline), and Brain Shell (`Brainitech/Brain_Shell`). **Palette = Dracula**
(operator decision 2026-06-18); we adopt their *structure*, skinned in Dracula.

### 11.1 Token scale (one source → chezmoi `.chezmoidata.yaml`)
- **Spacing / radius scale (shared):** `4 · 8 · 12 · 16 · 20 · 28 · 32 · 48`.
  Cards/popups radius `16`, floating bar `24`, pills/segments `99 (full)`,
  chips/buttons `8`. 1px borders everywhere.
- **Font scale:** `xs 10 · sm 12 · base 14 · lg 16 · xl 18`. Global
  JetBrainsMono Nerd Font; big clock 72px (letter-spacing −4). Optional: a
  glyph-safe sans (Rubik) for clock/workspace numerals to avoid broken glyphs.
- **Alpha-ladder (the whole look, cheap):** surfaces over base —
  `rgba(fg, .03–.05)`; borders `rgba(fg, .07–.12)`; hover `rgba(fg, .08–.12)`;
  accent (Dracula purple `#BD93F9`) state tints at `.12 / .18 / .35`. Glass
  panel `rgba(40,42,54,.85)`. Per-context accent rides the accent slot.
- **Semantic state colors (Dracula):** high/urgent `#FF5555`, med `#F1FA8C`,
  low/ok `#50FA7B`, info `#8BE9FD`.

### 11.2 Motion vocabulary
**Portable to eww/GTK-CSS on i3 (our entire motion budget):**
- Revealer reveals: `slideup / slideleft / slideright / slidedown`, ~`250ms`.
- GTK transitions: `transition: all .2s cubic-bezier(.25,1,.5,1)`; press
  micro-interaction `scale .95` over `.15s`; icon lift
  `-gtk-icon-transform: scale(1.1) translateY(-3px)` on hover.
- Springy reveal easing `cubic-bezier(.38,1.21,.22,1)` (overshoot) for accents.
- Workspace dot: width `10→24px` + a `@keyframes` breathing pulse on active.
- Toast auto-dismiss: a 5s linear width→0 progress bar (time-remaining without
  reading — strong ADHD affordance).
- Brain-Shell global motion duration ≈ `320ms` for panel expand/collapse.

**NOT portable (honest scope cut):** window open/close/workspace/morph
animations are compositor-level (Hyprland). i3 + picom give only fade/blur. All
window-level motion is out of scope; motion lives in eww widgets + browser CSS.

### 11.3 X11 tool substitutions (vs the Wayland references)
`hyprsunset → redshift/gammastep` · `hyprlock → i3lock-color/betterlockscreen` ·
`hyprctl → i3-msg` · Hyprland special-workspace pre-warm → **i3 scratchpad** ·
compositor blur → **picom** (already configured) · matugen wallpaper-derived →
**fixed Dracula** via chezmoi tokens.

## 12. Browser design (Phase 3 detail) — Aether Canvas, Dracula-skinned

**Goal:** literally no tabs, no chrome — full-bleed page; everything summoned.

### 12.1 Zero-chrome Canvas (`zen/userChrome.css`)
- Hide `#TabsToolbar`, `#nav-bar`, `#navigator-toolbox`, the sidebar, and
  `.titlebar-buttonbox-container`. Baseline = Zen **compact mode**; Canvas takes
  it to nothing. Bind one key to reveal chrome (`reveal_on: keybind`).
- Steal from `caelestia/zen/userChrome.css`: center idle urlbar
  (`#urlbar:not([focused]) .urlbar-input{text-align:center}`), 10px-round the
  urlbar/searchbar, dim unloaded tabs
  (`.tabbrowser-tab[pending]{filter:grayscale(1);opacity:.5}`), floating-urlbar
  reveal `@keyframes` (opacity 0→1, scale .8→1.02→1, 200ms ease-out), global
  `*{border:0;outline:0}` + `:active{scale:.95;transition:all .15s}`. Skin all to
  Dracula via chezmoi-templated CSS vars.

### 12.2 Summoned overlays (Tridactyl `.tridactylrc`, Aether keybinds)
| Action | Bind | Implementation |
|---|---|---|
| Command palette | `Space` | rofi command menu (themed Dracula) via Tridactyl `exclaim`, for the "beautiful overlay" look |
| Omni / URL | `g o` | `fillcmdline open` |
| Fuzzy tab switch | `Tab` | `:tabsearch` / `buffers` |
| Capture | `g c` | script: URL+selection → vault REST inbox (shares Phase 1 capture) |
| AI sidebar | `g a` | toggle sidebar panel |
| Focus mode | `g f` | extra chrome off + distraction blocklist on |
Tridactyl set to modal (Normal/Insert/Command). Overlays (tab search, workspace
/container pickers, palette) prefer **rofi** themed to Dracula for the polished
centered-fuzzy feel ("vim power without the ugliness").

### 12.3 Spatial model (mirror Aether's hierarchy)
Zen **Workspaces** = one per project (scoped tabs/state) · **Multi-Account
Containers** = identity/cookie isolation per context · tab folders/split = groups
· **rofi profile-launcher** (`firefox -P <ctx> --class <ctx>`) for full-isolation
switch. All switching via fuzzy overlay pickers. Pre-warm Zen on an i3
**scratchpad** at login so the browser keybind feels instant.

## 13. Dashboard & menus (Phase 2 detail)

Blueprint: `haikal-hakim/athena-eww` structure (yuck + `tokens.scss`). Reuse the
existing Dracula eww notif center.

### 13.1 Bar (floating pill, glass centerbox radius 24, 3 segments radius 99)
Near-monochrome; accent only on state. Widgets (Aether's set):
**context (color) · active task + live Timewarrior timer · #live tmux
sessions/agents · ArgoCD+SigNoz health glyph · open PRs (`gh`, `is:pr is:open
author:@me`) · next event · capture button.** Focus-mode collapses the bar to a
~6px strip (Brain-Shell idea).

### 13.2 Control center (slide-down/morph revealer, tabs)
- **Tasks (Kanban)** — To Do / Doing / Done, per-card urgency color, `←/→` to
  move. **Backed by taskwarrior** (`task export` → render; moves call `task`),
  NOT a separate json. Approximate Brain-Shell's drag (button-move + 100ms
  color-flash); **drop the QtQuick spring/3D-tilt** (not portable).
- **Deep-focus (Flowtime)** — count-up timer toward the next salah, one task/
  outcome, est-vs-actual, gentle 90-min nudge. The Phase-1 focus daemon's UI.
  (NOT pomodoro — see §14.)
- **QuickSettings** — optimistic toggles: **Caffeine** (`systemd-inhibit`),
  **DND** (`dunstctl set-paused`), Night Light (`gammastep`), WiFi/BT.
- **Live work** — the ~20 tmux sessions grouped by context + active Claude
  agents, each clickable to focus (`i3-msg` + `tmux switch/attach`). (Pain D/#1.)
- **Infra** — ArgoCD / SigNoz / cluster status at a glance (morning ritual in one
  panel, not five tabs).
- **Learning** — spaced-repetition due count + current courses from
  `~/powerhouse/learning/`.

### 13.3 Menu patterns (eww revealers + GTK CSS)
- **Hover-reveal dock launcher** (`slideup 250ms`, icons grow+lift on hover).
- **Two-click-confirm power menu** — one revealer; first click swaps icon to a
  `?` glyph + per-action accent, second executes. No separate dialog.
- **Gradient OSD sliders** — trough `rgba(fg,.1)`, fill gradient (volume
  cyan→purple, brightness yellow→orange), circular knob w/ soft shadow; reuse in
  bar OSD + control-panel sliders.
- **Edge slide-in popups** (network/audio/notifications) via per-popup `open` var
  + revealer; **auto-dismiss toast** with the 5s shrinking bar.

### 13.4 Reference repos to keep open while building
`haikal-hakim/athena-eww` (eww bar+menus blueprint) ·
`caelestia-dots/shell` + `caelestia/zen/userChrome.css` (M3 token discipline +
zero-chrome CSS) · `Brainitech/Brain_Shell` (kanban/timer/quicksettings UX).

---

# Addendum v2 (2026-06-18) — focus model, 3-bar UI, integrations, data plane

> Grounded in the operator's vault doctrine (`journal/manifesto.md`,
> `subject-profile.md`, `blueprint/research/domain/*`) and a Super Productivity
> study. Mockup: `docs/superpowers/mockups/` (HTML prototype + stills + video).
> **Hard design rule from the manifesto:** every capture/log is **≤2 actions**
> ("two-step vs five-step = adoption vs abandonment", `CLAUDE.md:27`).

## 14. Focus & life-tracking model (replaces pomodoro everywhere)

**Doctrine.** Friction-minimal · externalize at the point of performance
(Barkley) · interest/novelty/urgency, never "importance" (Dodson PINCH) ·
collapse delayed rewards into real-time visible progress (temporal discounting) ·
**never punish inconsistency** (RSD → shame-free, see §14.4).

**14.1 Deep-focus = Flowtime, scaffolded by salah.** Count-up, one outcome per
block, overtime never force-stopped. The day's architecture is the five prayers
(`04-islamic-productivity.md`): each inter-prayer window holds 2–3 sessions; the
big timer counts toward the **next salah**; salah *is* the prescribed recovery.
Gentle dismissible nudge only past ~90 min. Modes: Flowtime (default) ·
Countdown/timebox (opt-in) · **no pomodoro**.

**14.2 Idle-catch (highest-ADHD-value).** `xprintidle` daemon; on return from
>~10 min idle, a ≤2-tap eww popup: *assign the gap to the current task ·
discard · log as break/walk*. Stops silently-lost time. (From Super Productivity.)

**14.3 Tasks/time are decoupled (free architecture).** taskwarrior = tasks
(`+today` curated pull-list, projects = contexts, `estimate` UDA) · timewarrior =
intervals (est-vs-actual, per-context summaries) · a small JSON store =
metrics/streaks/reflections. No bespoke DB needed locally.

**14.4 Metrics = encouraging, never DORA.** Subjective daily reflection
(impact 1–4, energy 1–3 — already in the daily-note frontmatter) + **simple-
counter streaks** (consistency/focus-score, gamified with *variable* praise per
RPE) + time-trend bars (`timew summary`). Missed days are **silent, never red**.

**14.5 Life-tracking writes into the EXISTING daily-note schema.** The bottom-bar
trackers are one-tap toggles that PATCH today's `journal/daily/DD-MM-YYYY.md`
frontmatter via the Obsidian REST API (`:27124`): `salah{fajr..isha}`, `adhkar`,
`quran-minutes`, `mood`, `energy`, `sleep`, `selfcare`, `meals`, `triggers`,
`exercise`. **New fields to add:** `office{in,out}`, `time-categories` (work-at-
home / sleep / travel / travel-break / break / coffee / walk / washroom),
`time-per-project` (from timew). Each emits an append-only event for the VPS
(§17) so traffic/commute predictions and time analytics become possible.

**14.6 Learn-in-the-gaps.** Spaced-repetition (vault `obsidian-spaced-
repetition`, `learning/`) surfaces 1 tiny card on break/walk start (JITAI). Small
× many breaks × spacing = compounding. Depends on §17 data plane.

## 15. The 3-bar desktop (replaces the single-bar L3 surfacing)

Per the operator's layout and the mockup. All eww; near-monochrome + accent-on-
state; calm motion only.
- **TOP (always on, minimal):** workspaces · focused window · clock · now-playing
  · sound/notifications · context pill.
- **LEFT (summoned, "what am I chasing"):** big prayer-scaffolded timer · salah
  strip · **master AI agent** (§17) · now/next tasks · calendar · pending email ·
  yt-music · learn-in-the-gaps · focus-mode toggle. Hides the bottom bar when open.
- **BOTTOM (context bar):** project · context · branch · active task + elapsed ·
  encouraging stats (focus-score, streak, coffee, walks) · gamified, shame-free.
- **FOCUS MODE:** hides everything but the timer + one task + prayer runway.

## 16. Sub-project C — work integrations (issue-provider pattern)

One interface (Super Productivity's model): `search · getNewToBacklog ·
getFreshDiff · defaultProject/Tag/Note`. Each source = a thin adapter polled by a
**systemd timer / VPS poller** that writes into **taskwarrior** + surfaces in the
bars:
- **Linear** (GraphQL) → tickets as `+work` tasks, status badges.
- **Slack** (saved messages / reminders / mentions) → action items + left-bar count.
- **Email** (Gmail API / IMAP) → flagged mail as tasks + left-bar inbox count.
- **Calendar** (GCal / CalDAV) → events in the left bar + next-event in top bar.
These are "things you can't take home" surfaced locally without the work laptop.

## 17. Sub-project D — data plane, master AI agent & VPS self-hosting

This is the **companion runtime** the vault has been blocked on
(`blueprint/.../03-deployment-plan.md`: Postgres event-sourced L5 → Analyst L6).
NOTE: the vault's `powerhouse-system` runtime has been **ditched and replaced**;
the replacement is the orchestration substrate this data plane plugs into —
identify it before building D (open Q10).

**17.1 Master AI agent (left-bar "ask anything").** A small agent service holding
**full context** — vault (REST), taskwarrior/timew, ActivityWatch, git/k8s state,
the event store — and **routing across models via LiteLLM** (operator already
runs `litellm`): **Gemini** (Google subscription) · **Claude** · **local**
(Ollama/LM Studio, both installed) · **NotebookLM** (Drive corpus) for deep
research. Left bar posts a query → agent retrieves context → routes to the chosen
model → returns. Runs locally first; promotable to the VPS.

**17.2 VPS self-hosting stack (central server; Contabo Mumbai, `cntb`).**
| Concern | Tool | Notes |
|---|---|---|
| Reverse proxy / TLS | **Caddy** | per the blueprint deployment plan |
| Identity | Authelia or Entra SSO | the operator already uses Entra for infra |
| Event store | **PostgreSQL** (append-only) | L5 time-series per blueprint |
| Vault/journal sync | **Syncthing** (or git) | plain-file sync; no pfapi needed |
| Password manager | **Vaultwarden** (self-hosted Bitwarden) | also backs chezmoi secrets |
| Agent runtime | **Shahin** (LiteLLM 6-tier, Pi-engine) + **CORE** | replaces the ditched powerhouse-system; see §20–21. Deferred post-2026-08-02 |
| Integration pollers | systemd timers (Linear/Slack/email/cal) | §16 |
| Activity store | **ActivityWatch** server | aggregates per-host watchers |
| Health ingest | Amazfit/Zepp → Gadgetbridge/Zepp export → Postgres | §14.5 life data |
| Finance ingest | adapter → Postgres | life-goals dashboard |
| Secure access | **WireGuard** (or Tailscale) | reach the VPS privately |
| Backups | **restic → Google Drive via rclone**, daily systemd timer | `restic` present; add `rclone` |

**17.3 Backups.** Daily `restic` snapshot of Postgres + vault + configs, pushed to
**Google Drive** (rclone remote) — the operator's large Drive is the offsite. VPS
is primary; Drive is the daily backup target.

## 18. Revised roadmap (sub-projects)

The system is now explicitly multiple subsystems; each ships independently.

| Sub-project | Phases (this doc) | Near-term? |
|---|---|---|
| **A · Desktop UI** | 0 Foundation · 2 Surfacing(=3-bar §15) · 3 Browser | ✅ now |
| **B · Focus & life-tracking** | 1 ADHD core (§14) | ✅ now |
| **C · Work integrations** | issue-provider pollers (§16) | mid |
| **D · Data plane / AI agent / VPS** | §17 (agent local-first → VPS → backups) | mid/later |
| **E · Learn-in-the-gaps** | §14.6 (needs B + D) | later |

**Build order unchanged at the front:** Phase 0 → Phase 1, then the 3-bar (Phase
2) and browser (Phase 3). The master AI agent starts **local-first** in Phase 1/2
(LiteLLM routing, left-bar input) and graduates to the VPS in sub-project D.

## 19. New open questions (v2)

6. **VPN choice:** WireGuard (self-managed) vs Tailscale (easier mesh)?
7. **Password manager:** Vaultwarden (self-host, recommended) — confirm vs keeping
   an existing manager.
8. **Health data path:** does the Amazfit sync via Gadgetbridge (Android) or the
   Zepp web export? (Determines the ingest adapter.)
9. **AI agent home:** local-first now, VPS later (recommended) — or VPS from day 1?
10. ~~Orchestration runtime~~ — **RESOLVED 2026-06-18: Shahin + CORE** (+ kata),
    Pi-engine. Decided in `journal/career/specs/2026-06-04-fleet-consolidation-
    design.md`; **deferred to post-2026-08-02**. Detail in §20. The "master AI
    agent" = **CORE** (§21). Desktop integrates via stable contracts (§22), not
    the runtime directly.

---

# Addendum v3 (2026-06-18) — runtime resolved, contracts, sovereignty, island

> From the deep powerhouse read. Source of truth for the runtime is
> `journal/career/specs/2026-06-04-fleet-consolidation-design.md` (the vault's
> own `CLAUDE.md`/`01-tool-selection.md` are **stale** — they still say "Hermes";
> do not trust them for the runtime).

## 20. The orchestration runtime (resolves §17 "TBD")

`powerhouse-system` ("Hermes") is **ditched**. Current decided architecture:
- **Shahin** — code-orchestration runtime; a clean-room fork of `~/work/fleet-
  home/` (the ProficientNow platform). Pi-first multi-agent: **LiteLLM 6-tier
  routing**, YAML-DAG blueprints, Cedar policy gates, tmux+git-worktree, a Bun
  webhook, a Temporal worker. Repo: `shaiknoorullah/shahin` (private).
- **CORE** (`github.com/RedPlanetHQ/core`, AGPL-3.0) — personal-AI/coaching OS:
  **Neo4j temporal memory, 50+ MCP connectors, 4 surfaces (voice / scratchpad /
  messaging / chat), a Claude Code gateway.** All coaching delegated here.
- **kata** (`kenn-io/kata`) — agent ticket ledger (SQLite + HLC + SSE).
- **Bridge:** CORE dispatches code tasks to Shahin's HTTP API (HTTP-only seam).
- Engine = **Pi** (`@mariozechner/pi-coding-agent`) — this is the `pi-fleet` /
  `maestro-state` system already visible in this session's hooks.

**Deferred:** full build is post-`2026-08-02` (job landing); only a small
"Phase 0.5" backbone ships during the hunt. **Design consequence:** the desktop
must NOT depend on Shahin/CORE being up — it emits into the **stable contracts
(§22)** so data flows the moment they come online. Capture-now, integrate-later,
now concrete.

## 21. Master AI agent = CORE (revises §17.1)

The left-bar "master agent" is **not something we build** — it is a thin client
to **CORE** (full context via Neo4j memory + 50+ MCP; model routing via Shahin's
LiteLLM 6-tier: Gemini / Claude / local-Ollama / etc.). Until CORE is deployed,
the left-bar input routes to **LiteLLM directly** (already installed) with vault +
task context; NotebookLM stays a manual deep-research surface. **Build now:** the
left-bar agent UI + a pluggable backend interface (`LiteLLM` now → `CORE` later).

## 22. Integration contracts (stable seams — B/C/D emit here)

Already defined in the vault; the desktop just matches field names + a `source`
provenance tag. Three sinks:
- **(A) Obsidian REST → daily-note frontmatter** (`:27124`): `salah{}`, `adhkar`,
  `quran-minutes`, `mood`, `energy`, `sleep*`, `selfcare{}`, `meals{}`,
  `triggers[]`, `exercise`, `practices-completed[]`. New: `office{in,out}`,
  `time-categories`, `time-per-project`.
- **(B) Postgres `tracking.*`** (append-only, every row `source='<tracker>'`):
  `screen_time_logs`, `study_sessions`, `mood_energy_logs`, `trigger_logs`,
  `daily_logs`. Schema: `blueprint/archive/design/meta/04-data-model-deployment.md`.
- **(C) Event store `event_store`/`deliberation_events`** (typed L5 events:
  `MetricRecorded`, `MoodEnergyLogged`, `TriggerLogged`, `PracticeLogged`).

**Passive signal sources to run locally now:** **ActivityWatch** (`localhost:5600`
— window/afk/web), **Wakapi** (coding time), timewarrior/taskwarrior, dunst-DND,
hostctl (focus-profile). The vault's **Guardian** agent consumes ActivityWatch
every 5 min for trigger detection — so installing AW now directly serves the
operator's stated goals. (CORE's MCP connectors own Linear/Slack/email/cal later;
§16's thin taskwarrior pollers remain the near-term path.)

## 23. §20-bis Personal data sovereignty (NEW — backs the defensive-privacy ask)

Grounded in vault **Axiom 4** (`blueprint/design/01-philosophy-and-axioms.md`):
*"the subject owns their data absolutely… local and self-hosted whenever
feasible; data sovereignty is a design constraint, not a feature."* So the
defensive layer isn't a bolt-on — it's the system's first principle.
- **Sensitive processing on-device (Ollama)** — Guardian's trigger/screen-time
  data never leaves the machine (the vault already mandates this).
- **Terminal history** → **atuin**, E2E-encrypted, synced to the Contabo box →
  ciphertext to any DLP/Code42.
- **Browser history** → personal Zen profile ephemeral / daily `systemd` clear;
  **work** profile normal (monitoring sees work, not personal).
- **Passwords** → **Vaultwarden** (self-hosted).
- **Secrets/configs/dirs** → chezmoi + **age**; a **gocryptfs/fscrypt** encrypted
  personal volume.
- **Transport** → sync over **Tailscale** (the vault design's own choice, with
  Syncthing + Obsidian LiveSync) — encrypted on the wire. *(Revises my earlier
  WireGuard rec: align to the existing Tailscale standard; Headscale is the
  zero-third-party option if wanted.)*
- Rides the **Context** boundary. Caveat: keep within employer acceptable-use
  policy — defensive personal-data privacy only.

## 24. VPS = Contabo Mumbai (revises §17.2)

Actual deployed box: **`contabo-mum-1` · 217.217.251.84 · Mumbai**, already
running n8n / Postgres / Ghost / Astro / Uptime-Kuma / restic; RAM tight
(~5.5/8 GB worst-case; Hetzner CPX31 noted as fallback). Managed via **`cntb`**
(installed) + the `contabo-cntb` skill. Data plane adds CORE (Neo4j) + Shahin
HTTP + Vaultwarden + Obsidian LiveSync (CouchDB) + Wakapi + AW-sync. Backups:
**restic → Google Drive via rclone**, daily (operator pref; design had Backblaze B2).

## 25. Dynamic Island (revises §15 top bar)

Top-center = an **iOS-style Dynamic Island**: collapsed pill (album art + live EQ
+ track) that springs open (overshoot ease) into a full media player AND serves
as a **live-activity slot** cycling the highest-priority live signal — deep-block
timer · ArgoCD deploy finishing · incident firing · a Shahin/Claude agent
awaiting input. eww-portable (Brain-Shell notch→morph; revealer + CSS spring).
Mockup: `docs/superpowers/mockups/` (open `adhd-os.html`, press `m`).

## 26. Floating popup apps — master-agent console + music player (NEW)

Two **summoned, keyboard-first floating windows** that share ONE pattern (the same
"summoned overlay" language as the command palette §12 and the Dynamic Island
§25): Dracula, fast, dismiss-instantly, fully keyboard-driven, **persistent**
(toggled, state preserved). Sub-project A (UI); land in **Phase 2** after 0/1.
Mockups deferred (parked with the player polish).

**26.0 Shared popup framework.** An eww floating `defwindow` (stacking overlay,
`:focusable true`), summoned by a keybind, themed from the Dracula tokens, with: a
fuzzy search/command line, a content/result area, vim-style keyboard nav
(`j/k`, `/`, `Enter`, `Esc`, `Tab`), instant show/hide (i3 floating +
scratchpad-style toggle). Both apps are instances of this one framework.

**26.1 Master-agent console** (`$mod+<key>`). The full-window sibling of the
left-bar "ask anything" strip (§21) — same backend, richer surface:
- Multi-line **prompt input** + streaming response area.
- Fuzzy **search old conversations**, **tag** threads, **switch model** inline
  (Gemini / Claude / local-Ollama / NotebookLM).
- Backend: **CORE** (conversation store = Neo4j memory + 50+ MCP) when deployed;
  **LiteLLM** routing now. Threads + tags persisted (CORE → local SQLite seam).
- Depends on sub-project **D** (CORE/LiteLLM).

**26.2 Music player** (`$mod+<key>`). Keyboard-first, minimal, aesthetic ("my own
frontend, any backend"):
- Search across library + **yt-music + spotify**, play / queue / change, browse —
  all keyboard-driven.
- **Architecture:** one daemon = **mopidy** + **Mopidy-YTMusic** +
  **Mopidy-Spotify** (both backends behind one MPRIS/HTTP control surface); the
  popup is a **custom eww frontend** querying mopidy (HTTP/MPD) for search +
  control. The **notch** (§25) shows now-playing/mini-controls via MPRIS
  (`playerctl`); this popup is the full search/library app.
- Aesthetic target = the parked caelestia player (cover art · cava · calm) —
  `docs/superpowers/mockups/PLAYER-POLISH.md`.
- Adds one new daemon (mopidy) to sub-project A; no VPS dependency.
