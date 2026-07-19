# Minimal Wayland Desktop Rebuild — Design

Drop the monolithic caelestia/quickshell shell for a lightweight, toggleable-bar Hyprland stack, without losing the ADHD executive-function affordances the shell carried.

## 1. Goal
Replace `caelestia-shell` (one quickshell process owning bar + notifications + wallpaper + dashboard) with focused, individually-swappable tools — **waybar, mako, swayosd, swww, clipse, grim/slurp** — plus a **toggleable** bar that still shows the ADHD anchors (salah runway, active context, active project, tracking status). End state: a caelestia-free desktop with rollback available until the final removal step.

## 2. Where this fits (sequencing)
This is **track 2 of 3** coupled personal-desktop projects. Decided with the user (2026-07-19): do the minimal-rebuild **in chezmoi first** (fast edit→apply loop for tuning), then a **separate later spec** migrates the settled minimal tree to nix/home-manager. otter Phase-2 **verify** folds in as this rebuild's first task. The nix repo (`~/dotfiles`, home-manager standalone flake) currently only installs caelestia — its caelestia block + flake input are removed as part of Phase 3 here; full nixification is out of scope for this spec.

## 3. Current state (verified 2026-07-19)
- **caelestia still owns:** notifications (owns `org.freedesktop.Notifications`), the status bar, the dashboard/widgets, and part of wallpaper. It is a **monolithic** quickshell process — a single role can't be swapped while keeping others.
- **Already swapped:** launcher rofi→otter (done; otter has 21 modules incl. built Phase-2 bm/ob/git/sys/fb); wallpaper→swww (live, `--restore` in autostart); clipboard→clipse (`clipse -listen`).
- **Tools present:** swww, cliphist, clipse, hyprlock, hypridle (all installed; hyprlock/hypridle already configured — lock/idle is already minimal and stays as-is).
- **Tools MISSING (the real new installs):** waybar, mako, swayosd; screenshot currently uses caelestia's `ipc picker` (Print).
- **Redundancy to clean:** BOTH `cliphist` watchers AND `clipse -listen` run, plus a caelestia `clip-meta` sidecar; rofi still runs 2 things (style-selector on Super+Shift+D, obsidian-search on Super+Shift+N).
- Autostart lives in `~/.config/hypr/hyprland.lua` (a chezmoi template — edit live + `.tmpl` by hand, never `chezmoi add`).

## 4. Locked decisions (from the brainstorm)
- **Toggleable minimal waybar** (hide/show keybind = the "ADHD zen" toggle), not always-on and not barless.
- **All four ADHD bar cells:** salah runway, active context, active project, tracking status.
- **swayosd** for volume/brightness/caps-lock OSD.
- **mako** for notifications; **grim+slurp** for screenshots; **clipse** as the sole clipboard (drop cliphist + caelestia sidecar); **swww** for wallpaper.
- **Dashboard/widgets dropped.** hyprlock/hypridle unchanged.
- **Approach = configure-everything-alongside → one cutover → remove caelestia**, all in chezmoi, each phase reversible, time-tracking (systemd --user units, scripts, `~/powerhouse` vault note) untouched.

## 5. Component map
| Role | Replacement | Notes |
|---|---|---|
| Notifications | mako | install + Dracula config; takes the notifications bus at cutover |
| Bar | waybar | toggleable; modules in §6 |
| OSD | swayosd | `swayosd-server` + `swayosd-client` keybinds for vol/brightness |
| Screenshot | grim + slurp (script) | region + full; rebind `Print` (+ a Super+Shift+? for full) |
| Wallpaper | swww | already live; remove caelestia's `background` role only |
| Clipboard | clipse | keep `clipse -listen` + the Super+C TUI; drop cliphist watchers + caelestia `clip-meta` sidecar |
| Dashboard | dropped | — |
| Launcher | otter | verify Phase-2 modules work |
| rofi (last 2) | otter / drop | style-selector, obsidian-search |

## 6. Waybar (toggleable)
Layout: `[workspaces]  ·  [clock · 🕌 salah runway]  ·  [▶ tracking][ project@branch ][ ctx ][audio][network][tray]`

- **Base modules:** `hyprland/workspaces`, `clock`, `wireplumber` (audio), `network` (or keep `nm-applet` in `tray`), `tray` (nm-applet lives here).
- **Toggle:** a keybind (e.g. `Super + B`) that hides/shows waybar (`killall -SIGUSR1 waybar`, waybar's built-in toggle) — the zen switch.
- **Four ADHD custom modules** (`custom/*`, each `exec` a script on an interval, output text + a CSS class for accent):
  1. **salah-runway** → `~/.local/bin/adhd-focus.sh status` (already emits `→ Fajr 05:01`); refresh each minute.
  2. **active-context** → taskwarrior current context (`task _get rc.context` / `task context show`); `on-click` cycles to the next of work/lab/agents/personal via `task context <name>`; color-accented per context.
  3. **active-project** → project name + git branch; reads a small **active-project state file** (see §14 open items) that the otter `pj` switcher writes; `on-click` → otter `pj`.
  4. **tracking-status** → `timew get dom.active` + active tags → `▶ <task>` or `◦ idle`; `on-click` → the taskwarrior-tui daily driver.
- Styling: Dracula, matching kitty/otter/mako.

## 7. Notifications — mako
Install mako; Dracula config (position top-right, timeouts, urgency styling, action support). At cutover mako owns `org.freedesktop.Notifications` (caelestia must not be running to claim it). Verify with `notify-send` including an action (the salah nudge from Stage 2 uses a plain notification — mako must render it; the salah picker keybind remains the reliable path regardless).

## 8. OSD — swayosd
`swayosd-server` autostarted; keybinds route volume/brightness/caps-lock through `swayosd-client` (e.g. `XF86AudioRaiseVolume` → `swayosd-client --output-volume raise`). Dracula-matched style.

## 9. Screenshot — grim + slurp
A small script (`~/.local/bin/screenshot.sh`) for region (`grim -g "$(slurp)"`) and full-screen, copying to clipboard (`wl-copy`) and saving to `~/Pictures/Screenshots/`. Rebind `Print` (region) off caelestia's `ipc call picker open`; add a full-screen bind. (The heavier caelestia clipboard/screenshot QML rewrite specs in `~/dotfiles/docs` are superseded — caelestia is being removed.)

## 10. Wallpaper — swww
Already live (`swww-daemon` + `~/.local/bin/wallpaper --restore` at login, picker on Super+Shift+W). Only change: ensure caelestia's `background` isn't also setting a wallpaper post-cutover (it won't be running). No new work beyond confirming.

## 11. Clipboard — clipse only
Keep `clipse -listen` + the Super+C TUI. Remove: the two `wl-paste … cliphist store` autostart lines, and the two `wl-paste … clip-meta-record.sh` (caelestia sidecar) lines. One clipboard manager, no caelestia dependency.

## 12. rofi removal + otter Phase-2 verify (Phase 0)
- Verify otter Phase-2 modules (bm/ob/git/sys/fb) actually work end-to-end.
- Migrate rofi's last 2 binds: style-selector (Super+Shift+D) and obsidian-search (Super+Shift+N) → otter equivalents (or drop the style-selector, since caelestia's scheme is going away). After this, rofi can be dropped entirely.

## 13. Caelestia removal (Phase 3)
After living on the new stack: remove the `caelestia-shell` autostart line (done at cutover), `~/.config/caelestia/` (config + scripts, incl. clip-meta), the `programs.caelestia` block + `caelestia` flake input in `~/dotfiles`, and the chezmoi `caelestia`/`quickshell` dirs. `home-manager switch` + `chezmoi apply` land a caelestia-free tree.

## 14. Phasing (each phase ends in a working desktop; reversible until Phase 3)
- **Phase 0 — cleanups** (no caelestia dependency): otter Phase-2 verify; rofi last-2 migration; clipboard consolidation to clipse.
- **Phase 1 — configure all replacements** while caelestia still runs: mako config; waybar config + the 4 ADHD custom modules + toggle keybind; swayosd config + keybinds; the grim/slurp script + binds; confirm swww. Each piece individually testable (waybar launched manually, mako tested in a brief caelestia-down window). Nothing relied on yet.
- **Phase 2 — the cutover**: in `hyprland.lua` (+ `.tmpl`), replace the `caelestia-shell` exec with `waybar` + `mako` + `swayosd-server`; rebind Print. Relogin; verify the full desktop with caelestia **installed but not launched** (instant rollback = re-add the exec).
- **Phase 3 — remove caelestia**: after a settling period, delete caelestia config/scripts + the nix block + flake input + chezmoi caelestia/quickshell dirs.

## 15. Non-goals / out of scope
- **Nix/home-manager migration** — the separate track-3 spec (this rebuild lands in chezmoi; nix absorbs the result later).
- New widgets/dashboard/OSD-beyond-swayosd.
- Changing hyprlock/hypridle (already minimal) or the time-tracking system.
- The caelestia clipboard/screenshot QML rewrite (superseded by removal).

## 16. Constraints
- Personal, work-monitored machine — personal GitHub only; behavioral/config stays in the `shaiknoorullah/shell` repo.
- Every phase leaves a working desktop; caelestia stays installed (rollback) until Phase 3.
- `hyprland.lua` is a chezmoi TEMPLATE (`{{ .dracula.* }}`) — edit live + `.tmpl` by hand, never `chezmoi add`.
- Time-tracking untouched: aw-server/awatcher/timetrack-logind/timetrack-rollup/-sync units, `~/.local/bin` scripts, and the `~/powerhouse` note path keep working.

## 17. Open items to resolve during planning
- **Active-project state source:** where "the active project" is stored — the otter `pj` switcher should write a small state file (e.g. `~/.cache/adhd/active-project`) that the waybar module reads. Confirm/define this.
- Exact waybar module configs (workspace icons, clock format, network vs nm-applet-in-tray) and the toggle mechanism (SIGUSR1 vs a mode).
- mako + swayosd styling (Dracula values) and swayosd keybind set.
- Where the 4 ADHD module scripts live (`~/.local/bin/waybar-*.sh`?) and their refresh intervals.
- Confirm nothing else on the system depends on caelestia's `ipc` (only the Print screenshot bind found).
