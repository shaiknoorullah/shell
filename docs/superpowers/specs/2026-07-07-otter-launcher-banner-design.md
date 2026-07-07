# otter-launcher "banner-top otter" appearance — Design

**Date:** 2026-07-07
**Status:** Approved (design), pending implementation plan
**Scope:** Visual redesign of the user's otter-launcher (Super+D) on Hyprland/kitty, modeled on the official otter-launcher demo designs. Appearance and rendering only — the module set (`c` / `ws` / `sh` / `wp`) and their behavior are unchanged.

## Goal

Turn the current bare text launcher into a rich, intentional TUI that matches the quality of the upstream demos (`assets/foot.png`, `assets/fastfetch.png`, etc.): a full-width image banner, an icon-labeled system-info line, a Dracula color scheme, and nerd-font module rows — rendered crisp via kitty's image protocol.

## Approved decisions

| Decision | Choice |
|---|---|
| Layout archetype | **Banner-top** — full-width hero image across the top; info + module list beneath (the `foot.png` style) |
| Banner image | **Tasteful dark, Dracula-tinted otter** — static, curated, work-safe (no anime mascot) |
| Header info | **One rich stat line** — `user@host` + CPU-load + memory + uptime + WM |
| Color theme | **Dracula** (matches the existing hyprland border/theme data) |

## Target layout

```
╭──────────────────────────────────────────────╮
│  ▓▓▓▓▓▓▓▓  dark otter banner (Dracula-tint) ▓▓ │  ← chafa -f kitty, full-width, ~8 rows
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
│                                                │
│   devsupreme@dev    2.1%   4.6G   2h   hypr │  ← stat line, nerd-font icons
│    type a prefix                             │  ← ❯ prompt (purple)
│   ────────────────────────────────            │  ← thin Dracula divider
│     c   project context                      │
│     ws  web search                           │
│   ▌ sh  shell                                 │  ← ▌ selection marker (pink)
│    󰸉 wp  wallpaper                             │
╰──────────────────────────────────────────────╯
```

## Components

Each maps to a section of `~/.config/otter-launcher/config.toml` (`private_dot_config/otter-launcher/config.toml` in the chezmoi source).

### 1. Banner (`[interface].header_cmd`)
- Render the otter image with **`chafa -f kitty`** (kitty image protocol → crisp, unlike the ANSI/sixel in the demos). Size to the window width, ~8 rows tall.
- `header_cmd_trimmed_lines` trims any trailing blank rows chafa emits so the layout doesn't drift.
- `[general].delay_startup` set high enough (start ~30ms, tune down) that the image is drawn before the TUI paints — otherwise the banner skews (documented upstream behavior).

### 2. Stat line (`[interface].header`, last line = the input prompt)
- Single line: `<icon> devsupreme@<host>   <heart> <cpu-load>%   <mem-icon> <mem>   <up-icon> <uptime>   <wm-glyph> hypr`.
- Values via shell substitution inside the header string: CPU load from `mpstat`, memory from `free -h`, uptime from `uptime`/`/proc`. (Same technique as the upstream `foot`/`cover2` headers.)
- The header's final line carries the **input prompt** `❯ ` (purple) — otter renders the typed text/placeholder immediately after the header's last characters.
- Icons: nerd-font glyphs from JetBrainsMono Nerd Font (already installed).

### 3. Separator (`[interface].separator`)
- A thin Dracula-comment (`#6272a4`) divider between the input line and the module list, aligned to the list gutter.

### 4. Module list (`[[modules]]` + list styling)
- Rows unchanged in behavior; restyled: `<nerd icon>  <prefix>  <description>`.
- Proposed icons: `c` = , `ws` = , `sh` = , `wp` = 󰸉 (adjustable).
- `list_prefix` / `selection_prefix`: prefix in **purple `#bd93f9`**, description in fg, active-row marker **`▌` in pink `#ff79c6`**.
- `suggestion_lines = 4` (exactly the module count — no phantom row).

### 5. Color palette (Dracula)
| Role | Hex | ANSI use |
|---|---|---|
| Background | `#282a36` | (kitty translucency preserved) |
| Foreground | `#f8f8f2` | descriptions, user@host |
| Purple | `#bd93f9` | prefixes, `❯` prompt, accents |
| Pink | `#ff79c6` | `▌` selection marker |
| Comment | `#6272a4` | stat values, separator |
| Current line | `#44475a` | selected-row background (optional) |

### 6. Window (Hyprland rule, `class = "^(otter)$"`)
- Banner-top ⇒ **wide and short**. Rows ≈ banner(8) + stat(1) + prompt(1) + separator(1) + list(4) + margins ≈ 16.
- Start from a proportion that hugs this (candidate ~640×420) and tune against a screenshot. Float + center + rounding as today; launched through the clean `otter.conf` kitty surface.

## Tooling

| Tool | Status | Use |
|---|---|---|
| `chafa` 1.18.2 | Installed (brew) | `-f kitty` banner rendering |
| kitty image protocol | Available | crisp banner target |
| JetBrainsMono Nerd Font | Installed | all icons |
| `fastfetch` | Installed but **not used** | a lean custom `header_cmd` is faster and avoids the palette strip (declined) |

## Image sourcing

Deliver 2-3 candidate otter stills during implementation — the repo's own otter art (GPL, in `assets/`) plus one CC-licensed painterly otter — each pre-processed dark and Dracula-tinted (chafa can tint / pick an already-dark source). User selects one; the chosen file is committed into the chezmoi source under `private_dot_config/otter-launcher/images/`.

## Constraints

- **Work machine (Code42-monitored):** work-safe imagery only; no anime mascot. No exfiltration — image candidates are public/CC and stored locally in the repo.
- **kitty + Hyprland:** rendering assumes kitty (image protocol) and the existing `class="otter"` float rule.
- **chezmoi-managed:** all edits land in `~/.config/...` live, then are re-added to the chezmoi source (`~/src/caelestia-shell/dotfiles/...`) and pushed to `github-personal:shaiknoorullah/dotfiles` (branch `feat/caelestia-widgets`).
- **Escape encoding:** the TOML stores ANSI as literal `` (not raw ESC, not `\x1b`) — edits go through the Python-writer pattern, not the Edit tool.

## Non-goals

- No change to module behavior or the module set.
- No fastfetch palette strip, no two-line stat block (declined).
- No animated/rotating banner; no wallpaper-matching (a static otter was chosen).
- Not touching the wallpaper picker or `ctx` (separate tools).

## Verification

Interactive, so verified by the user on-screen via the working image-paste screenshot loop:
1. `Super+D` → banner renders crisp, not skewed; stat line populated; alignment consistent on the 4-col gutter.
2. Window hugs content (no dead space, no clipping).
3. Typing filters the list; `▌` marks the active row; `?` opens the cheatsheet.
4. Once dialed in, the final config + image are re-added to the chezmoi source and pushed.
