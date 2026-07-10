# rofi → otter-launcher migration — review doc

**Date:** 2026-07-08 (done autonomously overnight; for user review)
**Context:** After the otter-launcher banner redesign + bluetuith panel, migrate the "silly rofi scripts" into the otter/kitty-panel aesthetic. Autonomy granted; review at desk.

## Principles held
- **Reversible:** rofi scripts are NOT deleted — only keybinds repoint. Revert any bind by `git checkout` on `hyprland.lua`, or see per-item revert below.
- **No blind rewrites of risky logic:** complex scripts (sqlite bookmarks, obsidian wizard, systemd+pkexec, git-profile) stay on rofi for now (working) and are listed as Phase 2.
- **Couldn't interactively test** (no display in the agent session) — list-generation + syntax + config-parse were verified; the interactive fzf selection is standard. If any misbehaves, revert is one line.

## Audit + decisions (15 active rofi binds)

| Key | Was | Now | Status |
|---|---|---|---|
| Super+SPACE | rofilaunch.sh d (apps) | otter `app` (fzf .desktop) | MIGRATE |
| Super+Tab | rofilaunch.sh w (windows) | otter `win` (hyprctl+fzf) | MIGRATE |
| Super+Shift+S | rofilaunch.sh --run | otter `run` (fzf $PATH) | MIGRATE |
| Super+Shift+E | rofi-power.sh | otter `pw` (fzf + confirm) | MIGRATE |
| Super+M | rofi-media.sh | otter `md` (fzf playerctl) | MIGRATE |
| Super+slash | rofi-websearch-v2.sh | otter `ws` (existing module) | MIGRATE (rebind) |
| Super+P | rofi-projects.sh | otter `pj` (ported logic) | MIGRATE |
| Super+T | rofi-tmux.sh | otter `tm` (ported logic) | MIGRATE |
| Super+Shift+F | rofilaunch.sh f (files) | rofi (kept) | Phase 2 |
| Super+Shift+D | rofi-style-selector.sh | rofi (kept — rofi-specific) | Keep |
| Super+CTRL+S | rofi-systemd.sh | rofi (kept — pkexec logic) | Phase 2 |
| Super+G | rofi-git-profile.sh | rofi (kept) | Phase 2 |
| Super+Shift+O | rofi-bookmarks.sh | rofi (kept — sqlite) | Phase 2 |
| Super+N | rofi-obsidian.sh | rofi (kept — wizard) | Phase 2 |
| Super+Shift+N | rofi-obsidian-search.sh | rofi (kept) | Phase 2 |

Already off rofi earlier this session: Super+C (caelestia clipboard), Super+Shift+B (bluetuith), Print (caelestia screenshot), Super+Shift+W (otter wallpaper picker), Super+D (otter launcher).

## What changed (files)
- New: `~/.config/otter-launcher/scripts/_otter-fzf.sh` (shared Dracula fzf style) + `otter-{app,win,run,power,media,projects,tmux}.sh`.
- `config.toml` (via build_otter.py): new modules `app win run pw md pj tm` (+ existing `c ws sh wp bt`).
- `hyprland.lua`: the 8 binds above repointed to `otter-launcher <prefix>` on the otter kitty surface.

## Revert (per item)
- All at once: `git -C ~/src/caelestia-shell checkout -- dotfiles/private_dot_config/hypr/hyprland.lua.tmpl && chezmoi apply` (or `git checkout` the live `~/.config/hypr/hyprland.lua`).
- One bind: edit that line in `~/.config/hypr/hyprland.lua` back to `rofi .. "/<script>.sh"`, then `hyprctl reload`.
- The otter module scripts and rofi scripts coexist; nothing was deleted.

## Phase 2 (proposed, for your approval)
Port to otter modules: file-browser, systemd (fzf + pkexec), git-profile, bookmarks (zen sqlite → fzf), obsidian hub/search/create. These have more state/edge-cases; safer to port with you in the loop.

## Status: DONE (8 migrated + wired + reloaded)

All 8 binds now open otter modules on the otter kitty surface (`otter-launcher <prefix>`).
Verified: `bash -n` on all 8 scripts, fzf-opts parse, list-generation (144 apps, 9 windows,
real projects/tmux sessions), power/media action commands match the rofi originals, config
parses with 12 modules.

### Caveats to eyeball tomorrow
1. **Not interactively tested** — no display in the build session, so the fzf *selection* step
   wasn't exercised (list-gen + syntax + parse were). If any menu misbehaves, revert that one
   bind (see above); the rofi script still works.
2. **A few icons are best-guess codepoints** (the projects type-icons for Rust/JS/Py/Java/Ruby/git,
   and the app/win/run/pw/tm header glyphs) — may render as tofu boxes. Tell me which and I'll swap
   to verified ones. Power/media/Go/folder icons are exact copies of the rofi originals.
3. **Menu window size** = the otter class rule (small, 380×280, scrollable). If you want the app /
   window lists taller, I'll add a dedicated `class=otter-menu` rule.
4. **run module** uses `compgen -c` (5247 entries) with `--print-query`, so you can also type an
   arbitrary command, not just pick one.

### Update 2026-07-10 (confirmed working)
- **Launcher TUI redesign** — dropped banner-top; now a full-panel faded-otter Dracula background with bluetuith-style chrome: header bar (`user@host` left + stats right-aligned), full-width dividers, footer keybind bar, all 14 modules shown. New: `otter-header.sh`. (`otter-banner.sh` / `otter-stats.sh` now unused but kept.)
- **obsidian** (Super+N) → otter `ob` (`otter-obsidian.sh`): daily / open vault / search (1178 notes) / new-note wizard over `~/powerhouse`.
- **zen tabs** (Super+comma) → otter `zt` (`otter-tabs.sh`): brotab fuzzy switcher that switches **in the existing zen window** (`bt activate` + focus, no new window), `ctrl-d` close / `ctrl-y` copy-url.

### Phase 2 DONE (2026-07-10) — all rofi menus now migrated
- **files** (`fb`, Super+Shift+F) — fzf directory navigator (no yazi/lf installed; rofi's filebrowser modi had no CLI equivalent). `otter-files.sh`.
- **systemd** (`sys`, Super+CTRL+S) — fzf service list (color-coded status) → start/stop/restart via `pkexec` + view-logs in a kitty (`journalctl -f`). `otter-systemd.sh`.
- **git identity** (`git`, Super+G) — `otter-git.sh`. **Needs `~/.config/rofi/scripts/git-profiles.conf` populated** with your real `label|user|email` lines; right now it falls back to the example template (Work/Personal placeholders).
- **bookmarks** (`bm`, Super+Shift+O) — zen `places.sqlite` (via `zen-utils.sh` WAL-safe copy) → fzf → opens in a new zen tab. `otter-bookmarks.sh`.

18 otter modules total. Every original rofi script is still present as a fallback; all binds git-reversible.
