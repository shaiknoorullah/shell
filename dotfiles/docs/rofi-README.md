# Rofi Mega-Setup

Rofi configured as a unified command center with 20+ functions. Fullscreen blurred overlay with solid opaque content box, Catppuccin Mocha theme, designed to replicate a Hyprland-like experience on i3.

## Architecture

### The Blur Trick

The fullscreen overlay effect works through a collaboration between Rofi and picom:

- Rofi window is set to `fullscreen: true` with `transparency: "real"`
- Window background uses `cm-base-overlay` (`#1E1E2E95`) - semi-transparent
- This triggers picom's `dual_kawase` blur on the desktop behind
- Content boxes (inputbar, listview, mode-switcher) use SOLID opaque backgrounds
- Result: blurred desktop with crisp, readable content on top
- Rofi handles its own transparency via the theme; if picom ever reduces it, add
  `"100:class_g = 'Rofi'"` to `opacity-rule` in picom.conf (not currently set)

### Theme Layering System

```
catppuccin-mocha.rasi   <- Color palette (all cm-* variables)
        |
   settings.rasi        <- Font, global resets
        |
+-- list-menu.rasi      <- Base layout for searchable menus
|   +-- launcher.rasi   <- Per-menu overrides (columns, lines, prompt icon, etc.)
|   +-- clipboard.rasi
|   +-- ... (16 total)
|
+-- option-menu.rasi    <- Base layout for horizontal icon menus
    +-- power.rasi
    +-- screenshot.rasi
    +-- media.rasi
```

Each menu is invoked with `-theme path/to/menu.rasi`, so the global `config.rasi` contains NO theme.

## Directory Structure

```
~/.config/rofi/
├── README.md                    <- This file
├── config.rasi                  <- Global config (modi, matching, icons - NO theme)
├── themes/
│   ├── shared/
│   │   ├── catppuccin-mocha.rasi  <- Full Catppuccin Mocha palette
│   │   ├── settings.rasi          <- Font & global resets
│   │   ├── list-menu.rasi         <- Base: searchable list menus
│   │   └── option-menu.rasi       <- Base: horizontal icon menus
│   ├── launcher.rasi              <- App launcher / run / window / ssh / files
│   ├── power.rasi                 <- Power menu (5 icons)
│   ├── screenshot.rasi            <- Screenshot mode selector (3 icons)
│   ├── media.rasi                 <- Media controls (5 icons)
│   ├── clipboard.rasi             <- Clipboard history
│   ├── bluetooth.rasi             <- Bluetooth manager
│   ├── display.rasi               <- Display/monitor layout
│   ├── wallpaper.rasi             <- Wallpaper picker
│   ├── systemd.rasi               <- Systemd service browser
│   ├── calculator.rasi            <- Calculator (rofi-calc)
│   ├── emoji.rasi                 <- Emoji picker (rofimoji)
│   ├── websearch.rasi             <- Web search
│   ├── projects.rasi              <- Project launcher
│   ├── git-profile.rasi           <- Git identity switcher
│   ├── tmux.rasi                  <- Tmux session manager
│   ├── bookmarks.rasi             <- Firefox bookmarks
│   ├── obsidian.rasi              <- Obsidian quick actions
│   ├── obsidian-search.rasi       <- Obsidian note search
│   └── keybindings.rasi           <- i3 keybinding viewer
├── scripts/
│   ├── rofi-power.sh              <- Power menu script
│   ├── rofi-media.sh              <- Media controls script
│   ├── rofi-screenshot.sh         <- Screenshot script
│   ├── rofi-keybindings.sh        <- i3 keybinding parser
│   ├── rofi-wallpaper.sh          <- Wallpaper selector
│   ├── rofi-clipboard.sh         <- Clipboard (greenclip wrapper)
│   ├── rofi-git-profile.sh        <- Git profile switcher
│   ├── rofi-tmux.sh               <- Tmux session manager
│   ├── rofi-projects.sh           <- Project launcher
│   ├── rofi-obsidian.sh           <- Obsidian quick actions hub
│   ├── rofi-obsidian-search.sh    <- Obsidian note search
│   ├── rofi-obsidian-create.sh    <- Obsidian note creator
│   ├── rofi-bluetooth.sh          <- Bluetooth manager
│   ├── rofi-display.sh            <- Display layout manager
│   ├── rofi-systemd.sh            <- Systemd service manager
│   ├── rofi-bookmarks.sh          <- Firefox bookmark browser
│   ├── rofi-websearch.sh          <- Web search with suggestions
│   ├── git-profiles.conf          <- Git profile definitions
│   └── apis/
│       ├── google-suggest.sh      <- Google autocomplete API
│       ├── ddg-suggest.sh         <- DuckDuckGo autocomplete API
│       ├── youtube-suggest.sh     <- YouTube suggestions API
│       └── wikipedia-suggest.sh   <- Wikipedia OpenSearch API
```

## Keybinding Reference

| Keybinding | Menu | Type | Script/Command |
|---|---|---|---|
| `$mod+space` | App Launcher (drun) | Core | `rofilaunch.sh d` |
| `$mod+Tab` | Window Switcher | Core | `rofilaunch.sh w` |
| `$mod+Shift+s` | Run | Core | `rofilaunch.sh --run` |
| `$mod+Shift+f` | File Browser | Core | `rofilaunch.sh f` |
| `$mod+Shift+d` | Style Selector | Core | `rofi-style-selector.sh` |
| `$mod+F1` | Rofi Keys | Core | `rofi -show keys` |
| `$mod+Shift+e` | Power Menu | System | `rofi-power.sh` |
| `$mod+c` | Clipboard | System | `rofi-clipboard.sh` |
| `$mod+Shift+b` | Bluetooth | System | `rofi-bluetooth.sh` |
| `$mod+Shift+m` | Display Manager | System | `rofi-display.sh` |
| `$mod+Shift+w` | Wallpaper Picker | System | `rofi-wallpaper.sh` |
| `Print` | Screenshot | System | `rofi-screenshot.sh` |
| `$mod+Ctrl+s` | Systemd Services | System | `rofi-systemd.sh` |
| `$mod+equal` | Calculator | Productivity | `rofi -show calc` |
| `$mod+period` | Emoji Picker | Productivity | `rofimoji` |
| `$mod+slash` | Web Search | Productivity | `rofi-websearch-v2.sh` |
| `$mod+p` | Project Manager | Developer | `rofi-projects.sh` |
| `$mod+g` | Git Profile | Developer | `rofi-git-profile.sh` |
| `$mod+t` | Tmux Sessions | Developer | `rofi-tmux.sh` |
| `$mod+Shift+o` | Firefox Bookmarks | Browser | `rofi-bookmarks.sh` |
| `$mod+grave` | Zen Tab Switcher | Browser | `zen-tab-popup.sh` |
| `$mod+Shift+t` | Zen Workspaces | Browser | `zen-workspaces.sh` |
| `$mod+Shift+p` | Relaunch Polybar | System | `polybar/launch.sh` |
| `$mod+n` | Obsidian Actions | Notes | `rofi-obsidian.sh` |
| `$mod+Shift+n` | Obsidian Search | Notes | `rofi-obsidian-search.sh` |
| `$mod+F2` | i3 Keybindings | Other | `rofi-keybindings.sh` |
| `$mod+m` | Media Controls | Other | `rofi-media.sh` |

## Dependencies

### Required

- **rofi** - Menu framework
- **picom** - Compositor (dual_kawase blur, transparency)
- **i3** - Window manager
- **JetBrainsMono Nerd Font** - Icon font used throughout
- **dunst** / **notify-send** - Desktop notifications

### Per-Feature Dependencies

| Feature | Packages |
|---|---|
| Screenshot | `maim`, `xclip`, `xdotool` |
| Clipboard | `greenclip` (daemon, auto-started by i3) |
| Emoji | `rofimoji` (via pipx) |
| Calculator | `rofi-calc` plugin (built from source) |
| Media | `playerctl` |
| Wallpaper | `feh` |
| Bluetooth | `bluetoothctl` (from `bluez-utils`) |
| Display | `xrandr` |
| Systemd | `pkexec` (for privilege elevation) |
| Bookmarks | `sqlite3`, `firefox` |
| Web Search | `curl`, `jq`, `python3`, optionally `rofi-blocks` plugin |
| Projects | `code` (VS Code), `kitty` |
| Obsidian | `code` (VS Code) |
| Tmux | `tmux`, `kitty` |

## Configuration

### Picom Integration

The following picom.conf settings are critical:

- `blur-method = "dual_kawase"` and `blur-strength = 5` - enables blur behind rofi
- Rofi is NOT in `blur-background-exclude` - blur must apply behind it
- Rofi is in `rounded-corners-exclude` - fullscreen window should not get rounded corners
- Rofi is NOT in `blur-background-exclude` - blur must apply

### i3 Integration

- All keybindings are in `~/.config/i3/config` under categorized sections
- `exec --no-startup-id greenclip daemon` in autostart
- `exec_always --no-startup-id ~/.fehbg` for wallpaper persistence
- `$mod+Shift+e` replaced i3-nagbar exit with `rofi-power.sh`

### Adding a New Menu

1. Create a theme file in `themes/` that imports the appropriate base:

   ```rasi
   /* My new menu theme */
   @import "shared/list-menu"

   listview { columns: 1; lines: 8; }
   textbox-prompt-colon { str: "icon "; }
   mode-switcher { enabled: false; }
   ```

2. Create a script in `scripts/` following the pattern:

   ```bash
   #!/usr/bin/env bash
   THEME="$HOME/.config/rofi/themes/my-menu.rasi"
   # ... build options ...
   chosen=$(echo -e "$options" | rofi -dmenu -theme "$THEME" -p "Prompt" -mesg "Description")
   # ... handle selection ...
   ```

3. Add keybinding in `~/.config/i3/config`:

   ```
   bindsym $mod+key exec --no-startup-id ~/.config/rofi/scripts/my-script.sh
   ```

4. Reload i3: `$mod+Shift+r`

### Customizing Colors

Edit `themes/shared/catppuccin-mocha.rasi`. All variables use the `cm-` prefix. To switch to a different Catppuccin flavor (Latte, Frappe, Macchiato), replace the hex values.

### Git Profiles

Edit `scripts/git-profiles.conf` with pipe-delimited entries:

```
Work|Your Name|you@company.com
Personal|username|you@personal.com
```

### Obsidian Vault

The default vault path is `~/powerhouse/`. To change it, edit the `VAULT_DIR` variable in:

- `scripts/rofi-obsidian.sh`
- `scripts/rofi-obsidian-search.sh`
- `scripts/rofi-obsidian-create.sh`

### Project Directory

The default project directory is `~/work/`. To change it, edit `PROJECTS_DIR` in `scripts/rofi-projects.sh`.

## Troubleshooting

### No blur behind rofi

- Check picom is running: `pgrep picom`
- Verify `blur-method = "dual_kawase"` in picom.conf
- Ensure Rofi is NOT in `blur-background-exclude`
- Restart picom: `pkill picom && picom -b`

### Rofi shows with wrong theme / old style

- Each keybinding passes `-theme` explicitly
- Check that `config.rasi` has NO theme section (configuration only)
- Verify theme file path in i3 config or script

### Greenclip not working

- Check daemon: `pgrep greenclip`
- Start manually: `greenclip daemon &`
- i3 autostart should handle this on login

### Calculator not showing

- Verify rofi-calc plugin is installed: `rofi -dump-config | grep calc`
- Build from source if needed

### Emoji picker not working

- Verify rofimoji: `which rofimoji`
- Install: `pipx install rofimoji`

## File Count

- 4 shared themes + 19 per-menu themes = 23 theme files
- 17 scripts + 4 API scripts = 21 script files
- 1 global config + 1 git-profiles config + 1 README = 3 other files
- **Total: 47 files**
