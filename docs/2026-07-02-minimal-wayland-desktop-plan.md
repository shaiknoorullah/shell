# Minimal Wayland Desktop — Ditch Caelestia, Go Fundamentals-Only

**Goal:** Replace the caelestia/quickshell shell with a minimal, fundamentals-only Wayland setup. Caelestia was scaffolding for a broken base that's now fixed — the heavy shell is no longer needed.

**Approach (never nuke-first):** configure every minimal piece *alongside* running caelestia → one coordinated **cutover** (swap Hyprland autostart + keybinds) → verify → *then* remove caelestia. Keep caelestia installed until verified so revert is instant.

## Target stack (each replaces a caelestia function)
| Function | Tool | Status |
|---|---|---|
| Compositor / lock / idle | Hyprland / hyprlock / hypridle | ✅ installed (never was caelestia) |
| Wallpaper | **swww** | ✅ installed |
| Screenshot | **grim + slurp** | ✅ installed |
| Media | **playerctl** + otter | ✅ installed |
| Clipboard | **cliphist** + fuzzel picker | ✅ cliphist installed; need fuzzel |
| Launcher + prefix-commands + ADHD | **otter-launcher** (TUI in floating kitty) | ❌ build via `cargo install` |
| Notifications | **mako** | ❌ install |
| Bar | **waybar** (minimal; CONTENT TBD) | ❌ install |

## Phase 1 — Install (caelestia still running; safe)
```bash
cargo install --git https://github.com/kuokuo123/otter-launcher   # or clone + cargo build --release
sudo apt install mako-notifier waybar fuzzel     # confirm pkg names; brew is also an option
```

## Phase 2 — Configure (write configs; don't start yet)
- **otter** `~/.config/otter-launcher/config.toml`: `[general] default_module="gg", exec_cmd="hyprctl dispatch exec --"`; one `[[modules]]` per workflow. Port the ~12 custom rofi scripts as modules (prefix + `cmd` = the script's command):
  - `ob` obsidian, `pj` projects, `tm` tmux, `ws` websearch, `gp` git-profile, `bm` bookmarks, `zt` zen-tab, plus ADHD prefixes `cap`/`start`/`ctx` calling the adhd scripts that read `~/.cache/ctx` + `~/.cache/ctx-project`.
  - App launch: otter `app` module (fzf desktop files) OR keep fuzzel for apps.
- **mako** `~/.config/mako/config`: ~10 lines (default-timeout, anchor, colors).
- **waybar** `~/.config/waybar/{config.jsonc,style.css}`: thin config. **Bar CONTENT is deferred** — decide modules at cutover (candidates: workspaces, clock, battery/network/volume, tray, ctx indicator).
- **fuzzel** for clipboard picker: `cliphist list | fuzzel --dmenu | cliphist decode | wl-copy`.

## Phase 3 — Cutover (edit `~/.config/hypr/hyprland.lua`)
- Autostart: remove `caelestia-shell` (line ~121); add `swww-daemon` + `swww img <wall>`, `mako`, `waybar`.
- Keybinds (currently route to caelestia): 
  - `Super+Space` launcher → floating kitty running otter (window-rule the otter kitty as a centered float).
  - `Super+C` clipboard → the cliphist+fuzzel one-liner.
  - `Print` screenshot → `grim -g "$(slurp)" - | wl-copy` (+ save).
  - `Super+A` (ADHD leftbar) → repurpose to an otter ADHD prefix or drop.
- Keep hyprlock/hypridle binds as-is.

## Phase 4 — Verify, then remove caelestia
- Log out/in (or `hyprctl reload` + restart daemons). Confirm: wallpaper, notifications (`notify-send test`), bar, launcher, clipboard, screenshot, media keys all work.
- Only then: remove the caelestia flake input from `~/dotfiles` home-manager + `home-manager switch`; drop `~/.nix-profile` caelestia; retire `~/.config/quickshell/task-ui` if the ADHD scripts no longer read it.

## Phase 5 — Repo reshape
- The `~/src/caelestia-shell` monorepo loses the caelestia shell code → becomes **dotfiles + docs**. Rename to `dotfiles`. chezmoi source stays `dotfiles/`.
- Push to a **NEW PRIVATE repo** (public fork holds private content). Keep upstream caelestia remote only if still forking anything (probably not).

## Open decisions
- **Bar content** (deferred to end).
- Whether app-launch is otter or fuzzel.
- Exact otter module set for the 12 custom rofi ports (some may just be dropped).

## Context / provenance
Reverses this session's earlier "consolidate into caelestia" work (clipboard v2, task-UI port). cliphist history + `~/.cache/ctx*` ADHD state survive. Backups: `~/.local/state/dots-cleanup-2026-07-02/`, `~/ubuntu-dots.archived-2026-07-02/`. See memory `minimal-wayland-desktop-rebuild`.
