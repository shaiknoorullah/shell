# ubuntu-dots — session handoff

> Read this to resume work on the ADHD-support Hyprland desktop. It captures the
> architecture, the **operational knowledge** (how to deploy/verify/iterate), the
> gotchas, and the open items. Repo: `~/ubuntu-dots` (chezmoi source) → pushed to
> `git@github.com:shaiknoorullah/ubuntu-dots.git` `main`. Everything is committed.

## What this is
Ubuntu 24.04 + **Hyprland 0.55.4 (Wayland)** ADHD-support desktop. Hard Dracula.
chezmoi-managed. A 3-bar **quickshell** shell + a multi-page taskwarrior front-end,
prayer-scaffolded focus blocks, wallpaper system. i3/X11 is the fallback session.

## ⚠️ The non-obvious facts that bite you (read first)
1. **Hyprland 0.55 dropped hyprlang for Lua.** The config is `hyprland.lua`
   (`private_dot_config/hypr/hyprland.lua.tmpl`). `.conf` is dead. Rules/dispatchers
   are Lua: `hl.window_rule{}`, `hl.dsp.focus({workspace=N})`, etc. Verify a config:
   `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua` → expect `config ok`.
2. **quickshell runs inside an Arch `distrobox`** (`arch`) — Ubuntu's Qt 6.4 < the
   6.6+ quickshell needs. Host Wayland/nvidia/fonts pass through. The QML is
   `private_dot_config/quickshell/`. It renders on the host Hyprland.
   Quickshell UI icons use Material Symbols Rounded; `quickshell-setup`
   installs that TTF into `~/.local/share/fonts`.
3. **quickshell's `Process` PATH must include `~/.local/bin`** (set in
   `quickshell-launch`). If it's missing, NO `eww-*.sh`/`adhd-*.sh`/`wall.sh` runs
   and every widget silently shows defaults. This caused hours of confusion.
4. **The container can't touch host taskwarrior (2.6.2 vs container 3.x) or swww.**
   So everything host-side is bridged through **shared `~/.cache/adhd/` files +
   systemd user path units**: quickshell writes a request file, a host watcher runs
   the real command. `distrobox-host-exec` is NON-functional here.
5. **chezmoi source prefixes:** `private_dot_config/`→`~/.config` (0700),
   `private_dot_local/`→`~/.local`, `dot_task/`→`~/.task`. `~/walls` is its OWN repo
   (`shaiknoorullah/walls`), NOT in dotfiles.

## How to make a change (the loop that works)
```bash
cd ~/ubuntu-dots
# 1. grab the live Hyprland env (Bash has none by default)
export XDG_RUNTIME_DIR=/run/user/1001
for d in $(ls -1dt $XDG_RUNTIME_DIR/hypr/*/); do s=$(basename "$d");
  HYPRLAND_INSTANCE_SIGNATURE="$s" hyprctl version >/dev/null 2>&1 && export HYPRLAND_INSTANCE_SIGNATURE="$s" && break; done
export PATH="$HOME/.local/bin:$PATH" WAYLAND_DISPLAY=wayland-1

# 2. edit the .tmpl/.qml source, then deploy
chezmoi apply --force

# 3a. Hyprland change → reload + verify
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua | tail -1   # config ok
hyprctl reload; hyprctl configerrors                                # expect none
# 3b. quickshell change → restart the shell + check for QML errors
systemctl --user restart quickshell-bar; sleep 6
journalctl --user -u quickshell-bar --since "8 seconds ago" | grep -iE 'error|is not a type' | grep -v 'workspace'

# 4. SEE it (host has no grim; screenshot from the container, write to shared $HOME)
~/.local/bin/qs-ipc call panel focus            # open a widget
distrobox enter arch -- bash -c "export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-1; grim ~/qs.png"
# then Read ~/qs.png
```
Bash needs `dangerouslyDisableSandbox: true` for anything touching docker/distrobox/network.
Commit only when asked; end commit msgs with the Co-Authored-By trailer. Push only when asked.

## The shell (what's built)
- **3 bars + right panel** (`bar/TopBar/BottomBar/LeftBar/RightPanel.qml`): top =
  context · workspaces · **Dynamic Island** (real MPRIS cover art,
  hover-peek/click-pin) · clickable clock/system pill; bottom = gamified stats;
  left drawer (`Super+A`) = BIG live focus timer + salah runway + tasks; right
  panel = End-4-style quick toggles/sliders · notifications · calendar.
- **FocusPanel** (`bar/FocusPanel.qml`) — now a Tuxedo-inspired task command center,
  not a tabbed page shell. It is a real **FloatingWindow** (Hyprland windowrules still
  match `title:focus-panel`). `Super+Shift+Return` → `qs ipc call panel focus`.
  Layout: filters left, task list center, selected task + active Timewarrior block
  right, status/mode bar bottom. Keyboard: `↑↓`, `Enter`, `n`, `e`, `x`, `s`, `dd`,
  `p`, `r`, `+`, `t`, `m`, `/`, `:`, `fp`, `ft`, `fs`, `?`, `Esc`, `q`.
  The command palette and help overlay render their key labels from YAML.
- **WallpaperPicker** (`bar/WallpaperPicker.qml`) — FloatingWindow thumbnail grid of
  `~/walls` (117 imgs, collection filter chips). `Super+Shift+W` → `qs ipc call
  wallpaper open`. `wall.sh` = swww manager (set/random/next/prev/restore/list,
  persists to `~/.cache/wall`).
- Services (`services/`, auto-registered singletons): `Tasks` (all/done/projects/
  tags from host snapshot), `TaskActions` (write API via host bridge, plus
  host-side stop block), `TaskUiConfig` (YAML theme/keybind profiles normalized by
  `qs-task-ui-config.sh`), `PanelState` (legacy IPC), `BarState` (open/close + IPC),
  `Wall`, `Theme` (global Dracula), `Focus`/`ActiveTask`/`Salah`/`Players`/`Ctx`/
  `Stats`/etc.
- Icon convention: quickshell text uses `Theme.fontMono`; shell/UI icons use
  `MaterialIcon { text: "material_symbol_name" }`. Rofi/app launcher icons are
  separate GTK icons and currently use Adwaita.
- Right panel: click the top-right pill or `~/.local/bin/qs-ipc call quickpanel
  toggle`. Audio/caffeine are native Quickshell services. Bluetooth and notification
  controls run through `adhd-bluetooth.sh`/`adhd-notifs.sh`, which call host tools
  with `systemd-run --user --pipe` because the Arch distrobox cannot see the host
  system bus directly. Notification backend order: SwayNC (current owner on this
  machine) → dunst → `Notifs.qml` native fallback.

## Host bridges (quickshell → host action)
| Request file (`~/.cache/adhd/`) | systemd path unit | actuator | does |
|---|---|---|---|
| `start-request` | `adhd-block.path` | `adhd-block-exec.sh` | start a focus block (task+timew) |
| `task-cmd` (JSON arg arrays) | `adhd-task-cmd.path` | `adhd-task-cmd.sh` | any `task` mutation |
| `wall-request` (path) | `adhd-wall.path` | `adhd-wall-exec.sh` | `wall.sh set` (swww) |
Per machine once: `systemctl --user enable --now adhd-block.path adhd-task-cmd.path adhd-wall.path`.
Host snapshot for reads: `adhd-tasks-export.sh` writes `~/.cache/adhd/{tasks,done}.json`
(refreshed by the taskwarrior on-modify hook `dot_task/hooks/`).

## ADHD focus loop (works end-to-end)
`Super+Shift+Return` → pick/type a task → block starts → BIG timer counts UP
(Flowtime, no pomodoro), prayer-scaffolded by **Iqamah** times (Hanafi, Hyderabad;
`adhd-prayer-times.sh`). taskwarrior 2.6.2 + timewarrior + on-modify hook + `adhd-focus.sh`.

Task command center config:
- Active file: `~/.config/quickshell/task-ui.yaml`
- Theme profiles: `~/.config/quickshell/task-ui/themes/{dracula,catppuccin-mocha}.yaml`
- Keybind profile: `~/.config/quickshell/task-ui/keybinds/default.yaml`
- Loader: `~/.local/bin/qs-task-ui-config.sh` → JSON for `TaskUiConfig.qml`

## System state
- **nvidia RTX 4090**: driver 595-open, GPU rendering (was the "slowness"). Auto-loads.
- **hyprlock** (`Super+Escape`) Dracula lock + **hypridle** auto-lock (10m lock, 12m
  screen-off), running + autostarted.
- quickshell this session = `systemctl --user` transient unit `quickshell-bar`;
  on login it autostarts from `hyprland.lua` via `quickshell-launch`. Single instance
  (launcher has a `pkill -x quickshell` guard).

## OPEN ITEMS (pick up here)
1. **PENDING TASTE DECISION — window opacity/blur.** Currently global windows are
   translucent (`active 0.82 / inactive 0.70`), blur `size 5 passes 2`, **kitty is
   `opaque`** (user: "don't make kitty translucent"). The effect is real but only
   visible on NON-kitty windows (proven: browser shows wallpaper through). The user
   was deciding: keep global translucency vs. opaque-exception content apps
   (zen/slack/teams/obsidian read busy with wallpaper bleed). **Ask which direction,
   then add `hl.window_rule({ match={class="…"}, opaque=true })` rules.**
2. The old `bar/pages/*.qml` files are no longer loaded by `FocusPanel`; keep them
   only as historical reference until the new command center has settled.
3. Hyprland 0.55 **dim** is broken (`dim_inactive` removed; `dim_around` rule renders
   weakly) — the focus panel has no strong modal darken. Find 0.55's replacement if wanted.
4. Bigger features still queued (from the design spec): **master AI agent** in the
   left drawer (model-switching), **VPS data plane** (Contabo), **work integrations**
   (Linear/Slack/email), §26 popups, visual polish of the bars.

## Pointers
- Design spec: `docs/superpowers/specs/2026-06-18-adhd-os-design.md`. Memory files
  (background, may be stale — verify before acting): `~/.claude/projects/-home-devsupreme-ubuntu-dots/memory/`
  (`hyprland-055-lua-config`, `nvidia-driver-broken-2026-06`, `quickshell-distrobox-runtime`).
- Security: defensive only; employer monitors; secrets age-encrypted; vault L2
  (addictions/scores) never leaves the machine.
