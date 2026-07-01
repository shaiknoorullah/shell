# ubuntu-dots

Personal **Ubuntu 24.04 / Hyprland (Wayland)** dotfiles — managed with
**chezmoi**, themed **Dracula**, built as a context-driven **ADHD-support
desktop**. i3/X11 remains as a fallback session.

> Full design: [`docs/superpowers/specs/2026-06-18-adhd-os-design.md`](docs/superpowers/specs/2026-06-18-adhd-os-design.md)
> Plans: [`docs/superpowers/plans/`](docs/superpowers/plans/) · Mockups: [`docs/superpowers/mockups/`](docs/superpowers/mockups/) · Hyprland migration notes: [`docs/HYPRLAND-MIGRATION.md`](docs/HYPRLAND-MIGRATION.md)

## What this is

A keyboard-driven, glass-aesthetic desktop whose #1 job is supporting ADHD:
deep-focus **Flowtime** blocks (no pomodoro) scaffolded by **Salah (prayer)
times**, shame-free gamified life-tracking, and a fast in-shell task command
center — all in hard **Dracula**.

- **Compositor** — Hyprland 0.55 (Wayland), configured in **Lua**
  (`hyprland.lua`; 0.55 dropped the old hyprlang `.conf`). Compositor blur gives
  real glass on the bars. NVIDIA (RTX 4090) proprietary driver.
- **Shell** — a **quickshell** (QtQuick) shell: a top bar
  (context · workspaces · **Dynamic Island** media notch · clock/system pill), a
  bottom context/stats bar, a summoned left "what am I chasing" drawer, and an
  End-4-inspired right system panel.
- **Focus engine** — taskwarrior + timewarrior + prayer-scaffolded Flowtime; a
  single-screen **task command center** (`Super+Shift+Return`) to start blocks
  and manage task fields without touching the mouse.

## Model

This repo **is** the chezmoi source dir; chezmoi renders/deploys it to `$HOME`.

| Source prefix | Deploys to | Notes |
|---|---|---|
| `private_dot_config/…` | `~/.config/…` (0700) | hypr, quickshell, eww, rofi, kitty, fontconfig, systemd/user |
| `private_dot_local/…` | `~/.local/…` (0700) | `bin/` — the ADHD + shell scripts |
| `dot_task/hooks/…` | `~/.task/hooks/…` | taskwarrior on-modify → timewarrior + snapshot |
| `encrypted_private_dot_secrets.age` | `~/.secrets` | age-decrypted on apply |
| `.chezmoidata.yaml` | — | the single **Dracula palette** every themed config templates from |
| `.chezmoiignore` | — | keeps `docs/`, `tests/`, `keyd/` out of `$HOME` |

`*.tmpl` files are Go templates (colors pulled from `.chezmoidata.yaml`).

## The shell (quickshell via distrobox)

quickshell needs **Qt 6.6+** but Ubuntu 24.04 ships Qt 6.4, so the shell runs
from an **Arch `distrobox`** container with host Wayland + NVIDIA + fonts passed
through. The QML config (`private_dot_config/quickshell/`) renders on the host
Hyprland as layer-shell surfaces.

- `~/.local/bin/quickshell-setup` — reproducibly (re)creates the Arch box and
  installs `quickshell` + Qt6 + `task`/`timew`/`jq`/`playerctl`/`grim`/`python-yaml`.
- `~/.local/bin/quickshell-launch` — launches it (wired into `hyprland.lua`
  autostart); `qs-ipc` forwards IPC into the container.
- **Host bridge:** the container's taskwarrior 3.x can't read the host's 2.6.2
  data, so reads go through host-exported JSON (`~/.cache/adhd/tasks.json`) and
  writes are queued to `~/.cache/adhd/{start-request,task-cmd}` and run by host
  **systemd user path units** (`adhd-block.path`, `adhd-task-cmd.path`).

## ADHD focus system

- **Prayer-scaffolded Flowtime** — offline prayer times (adhanpy, Hanafi,
  Hyderabad) using **Iqamah** (congregation) times; deep blocks count *up* and
  never scold (`adhd-focus.sh`, `adhd-prayer-times.sh`).
- **Task command center** (`Super+Shift+Return`) — Tuxedo-inspired single
  surface: filters left, task list center, detail/active block right, mode/status
  bar bottom. Keyboard: `↑↓` move, `Enter` starts selected block, `n` creates +
  starts, `e` edits, `x` completes, `s` starts/stops, `dd` deletes with
  confirmation, `/` searches, `:` opens the command palette, `?` shows help.
  `Esc` clears overlay/search/filter before closing.
- **Task UI config** — `~/.config/quickshell/task-ui.yaml` selects YAML profiles
  in `~/.config/quickshell/task-ui/themes/` and `.../keybinds/`. The helper
  `qs-task-ui-config.sh` normalizes YAML to JSON for QML, so full palettes
  (Dracula, Catppuccin, custom) and keybinds are user-editable.
- **Left drawer** (`Super+A`) — BIG live block timer, salah runway, task list.
- **Right system panel** — click the top-right pill, or run
  `qs-ipc call quickpanel toggle`. Layout follows End-4's right sidebar pattern:
  quick toggles/sliders at top, notifications in the middle, calendar at bottom.
  Audio/caffeine use native Quickshell services; Bluetooth and notification controls run
  through host-side `systemd-run --user --pipe` bridges because Quickshell itself
  runs in a distrobox. Notifications prefer host SwayNC, then host `dunstctl`,
  then Quickshell's native notification server.

### Key bindings (Hyprland)
| Key | Action |
|---|---|
| `Super+Shift+Return` | open the focus/task panel |
| `Super+A` | toggle the left "what am I chasing" drawer |
| `Super+Shift+A` | quick-capture |
| `Super+Return` | terminal (kitty) · `Super+Space` rofi launcher |
| `Super+Escape` | hyprlock |

## Install on a new machine

```bash
# 1. chezmoi + age
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
sudo apt-get install -y age
# restore the age key to ~/.config/chezmoi/key.txt (from your password manager)

# 2. deploy dotfiles
chezmoi init git@github.com:shaiknoorullah/ubuntu-dots.git
chezmoi diff      # preview every change first
chezmoi apply

# 3. system pieces (need sudo / one-time)
#  - Hyprland (cppiber PPA) + NVIDIA proprietary driver
#  - enable the host actuators:
systemctl --user enable --now adhd-block.path adhd-task-cmd.path
#  - build the quickshell runtime container:
quickshell-setup
```

`~/.config/chezmoi/chezmoi.toml` sets `sourceDir`, `encryption = "age"`, and the
key path/recipient.

## Theme

**Dracula** (operator variant — base `#1a1a2e`, fg `#f8f8f2`, purple `#bd93f9`,
pink `#ff79c6`, cyan `#8be9fd`, green `#50fa7b`, orange `#ff9e3b`, red `#ff4d4d`,
yellow `#f5d547`), defined once in `.chezmoidata.yaml`. Context accents:
work=purple · lab=pink · agents=cyan · personal=green. Change a hex + `chezmoi
apply` → every templated config (hyprland.lua borders, quickshell theme, kitty)
updates. Fonts: **JetBrainsMono Nerd Font** for shell text, **Material Symbols
Rounded** for quickshell UI icons, Noto for CJK/emoji. GTK/app icons remain
separate: rofi currently uses **Adwaita** via `icon-theme`.

The task command center has its own runtime YAML theme profiles so you can test
full palettes without editing QML:

```yaml
# ~/.config/quickshell/task-ui.yaml
theme: task-ui/themes/catppuccin-mocha.yaml
keybinds: task-ui/keybinds/default.yaml
```

## Secrets

API keys live in `~/.secrets` (sourced by `~/.zshrc`), **age-encrypted** by
chezmoi. The decrypt key is `~/.config/chezmoi/key.txt` — **never committed;
back it up to your password manager** (losing it = unrecoverable secrets).

## Status

- ✅ **Foundation** — chezmoi adopted, secrets encrypted, Dracula palette.
- ✅ **Hyprland (Wayland)** — Lua config, blur/glass, NVIDIA fixed, JetBrainsMono.
- ✅ **quickshell 3-bar shell** — top/bottom/left bars, Dynamic Island (real
  cover art), right system panel, live data via native services/host bridges.
- ✅ **ADHD focus loop** — prayer-scaffolded Flowtime, live BIG timer.
- ✅ **Task command center** — keyboard-first taskwarrior/timewarrior surface,
  YAML-configurable palette/keybinds, command palette and help overlay.
- ⏭️ Next — master AI agent (model-switching), VPS data plane, work integrations,
  visual polish.

### Known
The top-level `tests/` bats suite targets the legacy rofi scripts and is not
maintained against the current shell.
