# i3 Configuration

i3 window manager configured with Catppuccin Mocha theme, Hyprland-like aesthetics (gaps, transparency, blur), and deep rofi integration for a unified desktop experience.

## Architecture

### Display Setup

Dual-monitor extended desktop:

- **HDMI-2** (left, primary) — 1920x1080
- **HDMI-1** (right, extended) — 1920x1080

Arranged at startup via xrandr in the i3 config. Wallpaper is managed by feh (persisted via `~/.fehbg`).

### Compositor Integration (picom)

picom provides the visual layer on top of i3:

| Feature | Setting |
|---|---|
| Backend | GLX (`glx-no-stencil`, `vsync`) |
| Blur | `dual_kawase`, strength 5 |
| Active opacity | 95% |
| Inactive opacity | 85% |
| Frame opacity | 90% |
| Fullscreen | 100% (opacity-rule) |
| Corners | Rounded (radius 12); excluded for dock/desktop/fullscreen |
| Blur exclude | dock, desktop, GTK frame extents |
| Fallback | xrender config when no direct rendering (see `launch.sh`) |

Config: `~/.config/picom/picom.conf`

### Theme

Catppuccin Mocha palette applied to window borders:

| State | Border | Text |
|---|---|---|
| Focused | `#CBA6F7` (Mauve) | `#CDD6F4` (Text) |
| Focused inactive | `#45475A` (Surface1) | `#CDD6F4` (Text) |
| Unfocused | `#313244` (Surface0) | `#A6ADC8` (Subtext0) |
| Urgent | `#F38BA8` (Red) | `#CDD6F4` (Text) |

Background for all states: `#1E1E2E` (Base)

### Window Appearance

- `default_border pixel 2` — thin borders, no title bars in tiled/floating mode
- `title_align center` — centered tab titles in tabbed/stacking layout
- `title_format "  %title  "` — inner padding on tabs for visual breathing room
- `gaps inner 6`, `gaps outer 3` — Hyprland-like spacing between windows
- `hide_edge_borders smart` — hides borders when only one window on screen

## Keybindings

### Core

| Keybinding | Action |
|---|---|
| `$mod+Return` | Open kitty terminal |
| `$mod+Shift+q` | Kill focused window |
| `$mod+Shift+c` | Reload i3 config |
| `$mod+Shift+r` | Restart i3 in-place |
| `$mod+Escape` | Lock screen (i3lock) |

### Navigation (vim-style)

| Keybinding | Action |
|---|---|
| `$mod+h/j/k/l` | Focus left/down/up/right |
| `$mod+Shift+h/j/k/l` | Move window left/down/up/right |
| `$mod+Arrow keys` | Focus (also with Shift to move) |

### Layout

| Keybinding | Action |
|---|---|
| `$mod+b` | Split horizontal |
| `$mod+v` | Split vertical |
| `$mod+f` | Fullscreen toggle |
| `$mod+s` | Stacking layout |
| `$mod+w` | Tabbed layout |
| `$mod+e` | Toggle split layout |
| `$mod+Shift+space` | Toggle floating |
| `$mod+space` | Toggle focus tiling/floating |
| `$mod+a` | Focus parent container |
| `$mod+r` | Enter resize mode |

### Resize Mode

| Key | Action |
|---|---|
| `h/l` or `Left/Right` | Shrink/grow width |
| `j/k` or `Down/Up` | Grow/shrink height |
| `Return/Escape/$mod+r` | Exit resize mode |

### Workspaces

| Keybinding | Action |
|---|---|
| `$mod+1-0` | Switch to workspace 1-10 |
| `$mod+Shift+1-0` | Move container to workspace 1-10 |

### Volume & Media

| Keybinding | Action |
|---|---|
| `XF86AudioRaiseVolume` | Volume up 5% |
| `XF86AudioLowerVolume` | Volume down 5% |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioMicMute` | Toggle mic mute |
| `XF86AudioPlay` | Play/pause (playerctl) |
| `XF86AudioNext/Prev` | Next/previous track |

### Rofi Menus

See `~/.config/rofi/README.md` for full rofi documentation.

| Keybinding | Menu | Script/Command |
|---|---|---|
| `$mod+space` | App Launcher (drun) | `rofilaunch.sh d` |
| `$mod+Tab` | Window Switcher | `rofilaunch.sh w` |
| `$mod+Shift+s` | Run | `rofilaunch.sh --run` |
| `$mod+Shift+f` | File Browser | `rofilaunch.sh f` |
| `$mod+Shift+d` | Style Selector | `rofi-style-selector.sh` |
| `$mod+F1` | Rofi Keys | `rofi -show keys` |
| `$mod+Shift+e` | Power Menu | `rofi-power.sh` |
| `$mod+c` | Clipboard | `rofi-clipboard.sh` |
| `$mod+Shift+b` | Bluetooth | `rofi-bluetooth.sh` |
| `$mod+Shift+m` | Display Manager | `rofi-display.sh` |
| `$mod+Shift+w` | Wallpaper Picker | `rofi-wallpaper.sh` |
| `Print` | Screenshot | `rofi-screenshot.sh` |
| `$mod+Ctrl+s` | Systemd Services | `rofi-systemd.sh` |
| `$mod+equal` | Calculator | `rofi -show calc` |
| `$mod+period` | Emoji Picker | `rofimoji` |
| `$mod+slash` | Web Search | `rofi-websearch-v2.sh` |
| `$mod+p` | Project Manager | `rofi-projects.sh` |
| `$mod+g` | Git Profile | `rofi-git-profile.sh` |
| `$mod+t` | Tmux Sessions | `rofi-tmux.sh` |
| `$mod+Shift+o` | Firefox Bookmarks | `rofi-bookmarks.sh` |
| `$mod+grave` | Zen Tab Switcher | `zen-tab-popup.sh` |
| `$mod+Shift+t` | Zen Workspaces | `zen-workspaces.sh` |
| `$mod+Shift+p` | Relaunch Polybar | `polybar/launch.sh` |
| `$mod+n` | Obsidian Actions | `rofi-obsidian.sh` |
| `$mod+Shift+n` | Obsidian Search | `rofi-obsidian-search.sh` |
| `$mod+F2` | i3 Keybindings | `rofi-keybindings.sh` |
| `$mod+m` | Media Controls | `rofi-media.sh` |

## Autostart Services

| Service | Type | Purpose |
|---|---|---|
| xrandr | `exec` | Monitor arrangement |
| dex | `exec` | XDG autostart entries |
| xss-lock + i3lock | `exec` | Screen lock on suspend/idle |
| nm-applet | `exec` | NetworkManager tray icon |
| polybar | `exec_always` | Status bar (replaces i3bar) |
| picom | `exec_always` | Compositor |
| ~/.fehbg | `exec_always` | Wallpaper persistence |
| dunst | `exec` | Notification daemon |
| greenclip | `exec` | Clipboard daemon |

`exec` runs once at login. `exec_always` re-runs on i3 restart (`$mod+Shift+r`).

## Window Rules

Floating is enabled for:

- Pop-up windows (`window_role="pop-up"`)
- Task dialogs (`window_role="task_dialog"`)
- Dialog windows (`window_type="dialog"`)
- Menu windows (`window_type="menu"`)
- Pavucontrol (audio mixer)
- nm-connection-editor (network settings)

## Dependencies

- **i3** — Window manager (with gaps support)
- **picom** — Compositor (GLX backend, dual_kawase blur)
- **polybar** — Status bar
- **kitty** — Terminal emulator
- **feh** — Wallpaper setter
- **i3lock** — Screen locker
- **dunst** — Notification daemon
- **JetBrainsMono Nerd Font** — UI font
- **rofi + scripts** — See `~/.config/rofi/README.md`
- **pactl** — PulseAudio volume control
- **playerctl** — MPRIS media control
- **greenclip** — Clipboard manager
- **xss-lock** — Idle/suspend screen lock trigger
- **nm-applet** — NetworkManager system tray
- **dex** — XDG autostart runner

## Related Configs

| Config | Path |
|---|---|
| Rofi | `~/.config/rofi/` |
| Picom | `~/.config/picom/picom.conf` |
| Polybar | `~/.config/polybar/` |
| Kitty | `~/.config/kitty/` |
| Dunst | `~/.config/dunst/` |
| Wallpapers | `~/walls/` (categorized subdirectories) |
