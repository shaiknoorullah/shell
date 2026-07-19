# Minimal Wayland Desktop Rebuild — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the monolithic `caelestia-shell` with waybar (toggleable, 4 ADHD cells) + mako + swayosd + swww + clipse + grim/slurp, in chezmoi, reversibly.

**Architecture:** Configure every replacement *alongside* the still-running caelestia (Phases 0–1, autonomous), then one hyprland.lua cutover + relogin (Phase 2, user-triggered), then remove caelestia (Phase 3). Binaries come from nix (`home.nix`, no sudo); all configs/scripts live in chezmoi.

**Tech Stack:** waybar, mako, swayosd (nix); grim/slurp/swww/clipse (installed); bash module scripts; Hyprland (`hyprland.lua`, a chezmoi template).

## Global Constraints
- **Scope = chezmoi minimal-rebuild only.** The full nix migration is a separate later track. The ONLY `~/dotfiles/home.nix` change here is adding 3 packages.
- **Binaries via nix, no sudo:** add `waybar mako swayosd` to `~/dotfiles/home.nix` `home.packages`; `home-manager switch`. apt-sudo is a fallback only if the nix build fails.
- **`~/.config/hypr/hyprland.lua` is a chezmoi TEMPLATE** with exactly **2** `{{ .dracula.* }}` directives. Edit the live file AND `~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl` BY HAND, identically; the count must stay 2; NEVER `chezmoi add` the hypr file.
- **Reversible until Phase 2.** Everything alongside caelestia; caelestia stays installed until Phase 3 = instant rollback.
- **Do NOT touch** the time-tracking units/scripts (aw-server/awatcher/timetrack-*), `~/.local/bin/adhd-*`/`tw-tui`/`timetrack*`, or `~/powerhouse`. Leave hyprlock/hypridle/swww/clipse as-is (already configured).
- **Dracula palette** (verbatim): bg `#282a36`, current-line `#44475a`, fg `#f8f8f2`, comment `#6272a4`, cyan `#8be9fd`, green `#50fa7b`, orange `#ffb86c`, pink `#ff79c6`, purple `#bd93f9`, red `#ff5555`, yellow `#f1fa8c`.
- **otter config** = `~/.config/otter-launcher/config.toml` (plain, chezmoi-managed; `build_otter.py` is absent — edit directly). Prefixes in use: c/ws/sh/wp/bt/app/win/run/pw/md/ym/pj/tm/ob/zt/git/bm/sys/fb/cl/tw/tt.
- **Binaries:** taskwarrior = `/home/linuxbrew/.linuxbrew/bin/task`; timew = `/usr/bin/timew`.
- **Autonomy:** config authoring, `home-manager switch`, config-parse/daemon-runs checks = autonomous. Anything needing the live RENDER eyeballed, the Phase-2 cutover relogin, and Phase-3 removal = **[user-assisted]** (the desktop can't be reliably screenshotted from automation).
- Commit each task: `chezmoi add` the live files (except the hypr template — edit by hand, `git add -A` picks up the `.tmpl`); `docs/` committed directly. Repo `~/src/caelestia-shell`, personal fork only.

---

## Phase 0 — Cleanups (no caelestia dependency)

### Task 1: Verify otter Phase-2 modules
**Files:** none (verification only).

- [ ] **Step 1: Run each Phase-2 module non-interactively enough to confirm it doesn't error**
```bash
for m in bm ob git sys fb; do
  echo "== $m =="; timeout 4 bash ~/.config/otter-launcher/scripts/otter-$( \
    case $m in bm)echo bookmarks;;ob)echo obsidian;;git)echo git;;sys)echo systemd;;fb)echo files;;esac).sh </dev/null 2>&1 | head -3 || true
done
```
Expected: each prints a menu/list or a graceful "nothing found" — no `command not found`/syntax error. **[user-assisted]** the actual fzf interaction is confirmed by the user launching `bm/ob/git/sys/fb` in otter.
- [ ] **Step 2: Record results** in the task report; if any errors, note the fix (missing dep) but do not block — these are pre-existing modules.

*(No commit — verification task.)*

### Task 2: Drop rofi's last 2 binds
**Files:** Modify `~/.config/hypr/hyprland.lua` + `…/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl` (by hand, both).

Rationale: `Super+Shift+D` (rofi style-selector) is obsolete once rofi/caelestia's scheme go away; `Super+Shift+N` (rofi-obsidian-search) is redundant — `Super+N` already opens otter `ob` (obsidian). Drop both binds.

- [ ] **Step 1: Delete the two bind lines in BOTH files (identical edit)**
Remove:
```lua
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd(rofi .. "/rofi-style-selector.sh"))
```
and
```lua
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd(rofi .. "/rofi-obsidian-search.sh"))
```
- [ ] **Step 2: Verify live==tmpl + dracula count still 2**
```bash
diff <(grep -c 'rofi-' ~/.config/hypr/hyprland.lua) <(grep -c 'rofi-' ~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl)
grep -c '{{ .dracula' ~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl   # must print 2
grep -nE 'SHIFT \+ D|SHIFT \+ N' ~/.config/hypr/hyprland.lua   # neither should reference rofi now
```
Expected: rofi-count equal in both; dracula count 2; no rofi refs on those binds.
- [ ] **Step 3: Commit**
```bash
git -C ~/src/caelestia-shell add -A
git -C ~/src/caelestia-shell commit -m "feat(desktop): phase0 — drop rofi's last 2 binds (style-selector obsolete; obsidian covered by otter ob)"
```

### Task 3: Consolidate clipboard to clipse
**Files:** Modify hyprland.lua live + `.tmpl` (by hand).

Remove the redundant cliphist watchers + the caelestia clip-meta sidecar from autostart (keep only `clipse -listen`).

- [ ] **Step 1: Delete these 4 autostart lines in BOTH files**
```lua
  hl.exec_cmd("wl-paste --type text  --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("wl-paste --type text  --watch $HOME/.config/caelestia/scripts/clip-meta-record.sh")
  hl.exec_cmd("wl-paste --type image --watch $HOME/.config/caelestia/scripts/clip-meta-record.sh")
```
Keep `hl.exec_cmd("/home/devsupreme/.local/bin/clipse -listen")`.
- [ ] **Step 2: Verify**
```bash
grep -c 'cliphist\|clip-meta' ~/.config/hypr/hyprland.lua        # 0
grep -c 'clipse -listen' ~/.config/hypr/hyprland.lua             # 1
grep -c '{{ .dracula' ~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl  # 2
diff ~/.config/hypr/hyprland.lua ~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl | grep -c '^[<>]'  # only the {{dracula}} lines differ
```
Expected: 0 cliphist/clip-meta, 1 clipse, dracula 2. (These autostart changes take effect on next relogin — harmless now.)
- [ ] **Step 3: Commit** `git -C ~/src/caelestia-shell commit -am "feat(desktop): phase0 — consolidate clipboard to clipse (drop cliphist + caelestia clip-meta watchers)"`

---

## Phase 1 — Configure all replacements (caelestia still running)

### Task 4: Install binaries via nix
**Files:** Modify `~/dotfiles/home.nix`.

- [ ] **Step 1: Add the 3 packages to `home.packages`**
Change:
```nix
  home.packages = [
    pkgs.ripgrep
    pkgs.fastfetch
    caelestiaWrapped # puts the nixGL-wrapped `caelestia-shell` on PATH
  ];
```
to add `pkgs.waybar pkgs.mako pkgs.swayosd` (leave caelestia — removed in Phase 3):
```nix
  home.packages = [
    pkgs.ripgrep
    pkgs.fastfetch
    pkgs.waybar
    pkgs.mako
    pkgs.swayosd
    caelestiaWrapped
  ];
```
- [ ] **Step 2: Activate**
```bash
cd ~/dotfiles && home-manager switch --flake .#devsupreme 2>&1 | tail -20
```
Expected: builds + activates. If the nix build errors badly, STOP and report (fallback: `sudo apt install waybar mako-notifier swayosd` — user-run).
- [ ] **Step 3: Verify the binaries are on PATH**
```bash
for b in waybar mako swayosd-server swayosd-client; do command -v $b || echo "MISSING $b"; done
waybar --version; mako --version
```
Expected: all present.
- [ ] **Step 4: Commit** `git -C ~/dotfiles add -A && git -C ~/dotfiles commit -m "feat(nix): add waybar + mako + swayosd for the minimal-desktop rebuild"` then push (`git -C ~/dotfiles push` — repo shaiknoorullah/dots).

### Task 5: mako notifications config
**Files:** Create `~/.config/mako/config`.

- [ ] **Step 1: Write the Dracula config**
```ini
font=JetBrainsMono Nerd Font 11
background-color=#282a36
text-color=#f8f8f2
border-color=#bd93f9
border-size=2
border-radius=8
padding=12
margin=10
default-timeout=6000
anchor=top-right
max-visible=5
icons=1

[urgency=high]
border-color=#ff5555
default-timeout=0
```
- [ ] **Step 2: Validate (mako not started yet — caelestia owns the bus)**
```bash
mako --config ~/.config/mako/config --help >/dev/null 2>&1 && echo "config path OK"
```
- [ ] **Step 3: [user-assisted] brief live test** — in a moment where the user can spare a caelestia-down blip: `pkill -f caelestia-shell; mako & sleep 1; notify-send "mako" "dracula test — action?" ; ` then restart caelestia (`~/.nix-profile/bin/caelestia-shell &`). Confirm the mako popup looked right. (Deferred to the user; not required to proceed.)
- [ ] **Step 4: Commit** `chezmoi add ~/.config/mako/config && git -C ~/src/caelestia-shell commit -am "feat(desktop): phase1 — mako notification config (Dracula)"`

### Task 6: The 4 ADHD waybar module scripts (+ pj active-project state)
**Files:** Create `~/.local/bin/waybar-salah.sh`, `waybar-ctx.sh`, `waybar-project.sh`, `waybar-tracking.sh`; Modify `~/.config/otter-launcher/scripts/otter-projects.sh`.

**Interfaces:** each script prints one JSON line `{"text":…,"class":…}` (waybar `return-type: json`).

- [ ] **Step 1: `waybar-salah.sh`** — next-prayer runway
```bash
#!/usr/bin/env bash
# waybar salah-runway: the "→ <Prayer> <HH:MM>" tail of adhd-focus.sh status.
s="$("$HOME/.local/bin/adhd-focus.sh" status 2>/dev/null)"
runway="${s##*→ }"                       # "Dhuhr 13:30"
[ -n "$runway" ] && [ "$runway" != "$s" ] && runway="→ $runway" || runway="—"
printf '{"text":"🕌 %s","tooltip":"%s","class":"salah"}\n' "$runway" "${s:-no prayer times}"
```
- [ ] **Step 2: `waybar-ctx.sh`** — taskwarrior context (display + `cycle`)
```bash
#!/usr/bin/env bash
TASK=/home/linuxbrew/.linuxbrew/bin/task
CTXS=(none work lab agents personal)
cur="$("$TASK" _get rc.context 2>/dev/null)"; cur="${cur:-none}"
if [ "${1:-}" = "cycle" ]; then
  i=0; for c in "${CTXS[@]}"; do [ "$c" = "$cur" ] && break; i=$((i+1)); done
  next="${CTXS[$(((i+1) % ${#CTXS[@]}))]}"
  "$TASK" context "$next" >/dev/null 2>&1
  pkill -RTMIN+8 waybar 2>/dev/null       # refresh the module
  exit 0
fi
printf '{"text":" %s","class":"ctx-%s"}\n' "$cur" "$cur"
```
- [ ] **Step 3: `waybar-project.sh`** — active project + git branch
```bash
#!/usr/bin/env bash
f="$HOME/.cache/adhd/active-project"
[ -s "$f" ] || { printf '{"text":"","class":"project"}\n'; exit 0; }
proj="$(cat "$f")"
branch=""
[ -d "$HOME/work/$proj/.git" ] && branch="$(git -C "$HOME/work/$proj" branch --show-current 2>/dev/null)"
printf '{"text":" %s%s","class":"project"}\n' "$proj" "${branch:+  $branch}"
```
- [ ] **Step 4: `waybar-tracking.sh`** — timew active/idle
```bash
#!/usr/bin/env bash
TIMEW=/usr/bin/timew
if [ "$("$TIMEW" get dom.active 2>/dev/null)" = "1" ]; then
  n="$("$TIMEW" get dom.active.tag.count 2>/dev/null)"; tag=""
  [ "${n:-0}" -ge 1 ] 2>/dev/null && tag="$("$TIMEW" get dom.active.tag.1 2>/dev/null)"
  printf '{"text":"▶ %s","class":"tracking-on"}\n' "${tag:-tracking}"
else
  printf '{"text":"◦ idle","class":"tracking-off"}\n'
fi
```
- [ ] **Step 5: Make `otter-projects.sh` write the active-project state** — after the user picks a project (find where `name`/the chosen project is set, before opening it), add:
```bash
mkdir -p "$HOME/.cache/adhd"; printf '%s' "$name" > "$HOME/.cache/adhd/active-project"
```
(Insert right after the project `name` is resolved from the fzf selection; verify by reading the script's selection block.)
- [ ] **Step 6: chmod + verify each prints valid JSON**
```bash
chmod +x ~/.local/bin/waybar-{salah,ctx,project,tracking}.sh
for s in salah ctx project tracking; do echo -n "$s: "; ~/.local/bin/waybar-$s.sh | jq -e . >/dev/null && echo "valid JSON" || echo "BAD"; done
```
Expected: all "valid JSON".
- [ ] **Step 7: Commit**
```bash
chezmoi add ~/.local/bin/waybar-salah.sh ~/.local/bin/waybar-ctx.sh ~/.local/bin/waybar-project.sh ~/.local/bin/waybar-tracking.sh ~/.config/otter-launcher/scripts/otter-projects.sh
git -C ~/src/caelestia-shell commit -am "feat(desktop): phase1 — 4 ADHD waybar module scripts + pj active-project state"
```

### Task 7: waybar config + style
**Files:** Create `~/.config/waybar/config.jsonc`, `~/.config/waybar/style.css`.

- [ ] **Step 1: `config.jsonc`**
```jsonc
{
  "layer": "top",
  "position": "top",
  "height": 30,
  "spacing": 6,
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock", "custom/salah"],
  "modules-right": ["custom/tracking", "custom/project", "custom/ctx", "wireplumber", "network", "tray"],
  "hyprland/workspaces": { "on-click": "activate", "format": "{name}" },
  "clock": { "format": "{:%a %d %b  %H:%M}", "tooltip-format": "<tt>{calendar}</tt>" },
  "custom/salah":    { "exec": "/home/devsupreme/.local/bin/waybar-salah.sh",    "return-type": "json", "interval": 60, "on-click": "kitty --class otter --config ~/.config/kitty/otter.conf -e ~/.local/bin/adhd-focus.sh status" },
  "custom/tracking": { "exec": "/home/devsupreme/.local/bin/waybar-tracking.sh", "return-type": "json", "interval": 15, "on-click": "kitty --class tasktui --config ~/.config/kitty/tasktui.conf -e ~/.local/bin/tw-tui" },
  "custom/project":  { "exec": "/home/devsupreme/.local/bin/waybar-project.sh",  "return-type": "json", "interval": 10, "on-click": "kitty --class otter --config ~/.config/kitty/otter.conf -e ~/.cargo/bin/otter-launcher pj" },
  "custom/ctx":      { "exec": "/home/devsupreme/.local/bin/waybar-ctx.sh",      "return-type": "json", "interval": 30, "signal": 8, "on-click": "/home/devsupreme/.local/bin/waybar-ctx.sh cycle" },
  "wireplumber": { "format": "{icon} {volume}%", "format-muted": "󰝟", "format-icons": ["󰕿","󰖀","󰕾"], "on-click": "swayosd-client --output-volume mute-toggle" },
  "network": { "format-wifi": "  {signalStrength}%", "format-ethernet": "󰈀", "format-disconnected": "󰤭", "tooltip-format": "{ifname}: {ipaddr}" },
  "tray": { "spacing": 8 }
}
```
- [ ] **Step 2: `style.css` (Dracula)**
```css
* { font-family: "JetBrainsMono Nerd Font", monospace; font-size: 13px; min-height: 0; }
window#waybar { background: #282a36; color: #f8f8f2; border-bottom: 2px solid #44475a; }
#workspaces button { color: #6272a4; padding: 0 8px; background: transparent; border: none; }
#workspaces button.active { color: #bd93f9; }
#workspaces button:hover { color: #f8f8f2; background: #44475a; }
#clock { color: #f8f8f2; font-weight: bold; padding: 0 10px; }
#custom-salah { color: #8be9fd; padding: 0 8px; }
#custom-tracking { padding: 0 8px; }
#custom-tracking.tracking-on { color: #50fa7b; }
#custom-tracking.tracking-off { color: #6272a4; }
#custom-project { color: #ffb86c; padding: 0 8px; }
#custom-ctx { padding: 0 8px; }
#custom-ctx.ctx-none { color: #6272a4; }
#custom-ctx.ctx-work { color: #8be9fd; }
#custom-ctx.ctx-lab { color: #50fa7b; }
#custom-ctx.ctx-agents { color: #bd93f9; }
#custom-ctx.ctx-personal { color: #ffb86c; }
#wireplumber, #network { color: #f8f8f2; padding: 0 8px; }
#tray { padding: 0 8px; }
```
- [ ] **Step 3: Config-parse check (launch waybar to a throwaway, don't leave it)** — waybar can't run its bar twice cleanly while caelestia's bar exists, but it validates config on start:
```bash
timeout 2 waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css -l trace 2>&1 | grep -iE 'error|parse|invalid' | head || echo "no config errors"
```
Expected: no parse/error lines (a launched-but-killed waybar is fine).
- [ ] **Step 4: [user-assisted] render check** — deferred to the Phase-2 cutover (the bar's real appearance + the 4 cells + toggle are eyeballed once it's the live bar).
- [ ] **Step 5: Commit** `chezmoi add ~/.config/waybar/config.jsonc ~/.config/waybar/style.css && git -C ~/src/caelestia-shell commit -am "feat(desktop): phase1 — waybar config + Dracula style (workspaces/clock/salah/tracking/project/ctx/audio/net/tray)"`

### Task 8: swayosd config + keybinds
**Files:** Create `~/.config/swayosd/style.css`; Modify hyprland.lua live + `.tmpl` (add media/brightness/caps binds — these are additive, safe now).

- [ ] **Step 1: `swayosd/style.css` (Dracula, optional but nice)**
```css
window { background: #282a36; border: 2px solid #bd93f9; border-radius: 12px; }
label { color: #f8f8f2; font-family: "JetBrainsMono Nerd Font"; }
progressbar { background: #44475a; border-radius: 8px; }
progress { background: #bd93f9; border-radius: 8px; }
```
- [ ] **Step 2: Add the OSD keybinds in BOTH hyprland.lua files** (near the other binds; these route through swayosd-client — harmless until swayosd-server runs at cutover):
```lua
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume raise"))
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume lower"))
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"))
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"))
hl.bind("Caps_Lock",             hl.dsp.exec_cmd("swayosd-client --caps-lock"))
```
- [ ] **Step 3: Verify + dracula count 2**
```bash
grep -c swayosd-client ~/.config/hypr/hyprland.lua        # 6 (+the waybar wireplumber on-click is in waybar, not here)
grep -c '{{ .dracula' ~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl  # 2
swayosd-client --help >/dev/null 2>&1 && echo "swayosd-client OK"
```
- [ ] **Step 4: Commit** `chezmoi add ~/.config/swayosd/style.css && git -C ~/src/caelestia-shell commit -am "feat(desktop): phase1 — swayosd style + vol/brightness/caps keybinds"`

### Task 9: grim/slurp screenshot script (+ confirm swww)
**Files:** Create `~/.local/bin/screenshot.sh`.

- [ ] **Step 1: Write the script**
```bash
#!/usr/bin/env bash
# screenshot.sh [region|full] — grim/slurp; copies to clipboard + saves.
set -uo pipefail
dir="$HOME/Pictures/Screenshots"; mkdir -p "$dir"
f="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
case "${1:-region}" in
  region) geo="$(slurp 2>/dev/null)" || exit 0; grim -g "$geo" "$f" ;;
  full)   grim "$f" ;;
  *) echo "usage: screenshot.sh region|full" >&2; exit 2 ;;
esac
[ -s "$f" ] && { wl-copy < "$f"; notify-send "📸 screenshot" "$(basename "$f")"; }
```
- [ ] **Step 2: chmod + syntax + confirm swww daemon is the wallpaper source**
```bash
chmod +x ~/.local/bin/screenshot.sh && bash -n ~/.local/bin/screenshot.sh && echo "OK"
pgrep -x swww-daemon >/dev/null && echo "swww running ✓" || echo "swww not running (starts via wallpaper --restore at login)"
```
(Full-screen grim can be tested now; region needs interactive slurp = [user-assisted].)
- [ ] **Step 3: Commit** `chezmoi add ~/.local/bin/screenshot.sh && git -C ~/src/caelestia-shell commit -am "feat(desktop): phase1 — grim/slurp screenshot script"`

---

## Phase 2 — The cutover  **[USER-ASSISTED]**

### Task 10: Swap caelestia → waybar/mako/swayosd + rebind Print, then relogin
**Files:** Modify hyprland.lua live + `.tmpl` (by hand).

- [ ] **Step 1: In the autostart block, REPLACE the caelestia line** (in BOTH files):
```lua
  hl.exec_cmd("~/.nix-profile/bin/caelestia-shell")
```
with:
```lua
  hl.exec_cmd("waybar")
  hl.exec_cmd("mako")
  hl.exec_cmd("swayosd-server")
```
- [ ] **Step 2: Rebind Print** — replace:
```lua
hl.bind("Print",               hl.dsp.exec_cmd(cs .. " ipc call picker open"))
```
with:
```lua
hl.bind("Print",               hl.dsp.exec_cmd("~/.local/bin/screenshot.sh region"))
hl.bind(mod .. " + Print",     hl.dsp.exec_cmd("~/.local/bin/screenshot.sh full"))
```
- [ ] **Step 3: Add the waybar toggle keybind** (verify `Super+B` is free first; `Super+Shift+B` is bluetuith):
```bash
grep -nE 'mod .. " \+ B"' ~/.config/hypr/hyprland.lua || echo "Super+B FREE"
```
then add (both files):
```lua
hl.bind(mod .. " + B",         hl.dsp.exec_cmd("killall -SIGUSR1 waybar"))  -- toggle bar (zen)
```
- [ ] **Step 4: Verify live==tmpl (except dracula) + dracula count 2 + no caelestia exec left**
```bash
grep -c 'caelestia-shell' ~/.config/hypr/hyprland.lua        # 0 in autostart (cs var may remain; fine)
grep -cE 'waybar|mako|swayosd-server' ~/.config/hypr/hyprland.lua  # ≥3
grep -c '{{ .dracula' ~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl  # 2
```
- [ ] **Step 5: [USER-ASSISTED] cutover** — the user relogins (or runs, in the live session: `pkill -f caelestia-shell; waybar & mako & swayosd-server &`). Then confirms: bar shows workspaces/clock/salah/tracking/project/ctx/audio/net/tray; notifications pop via mako; volume/brightness show swayosd; Print takes a screenshot; wallpaper intact; clipse (Super+C) works; `Super+B` toggles the bar. **If anything's broken: `killall waybar mako swayosd-server; ~/.nix-profile/bin/caelestia-shell &` restores caelestia instantly** (it's still installed).
- [ ] **Step 6: Commit** (after the user confirms) `git -C ~/src/caelestia-shell commit -am "feat(desktop): phase2 CUTOVER — caelestia-shell → waybar+mako+swayosd; Print → grim/slurp; Super+B bar toggle"`

---

## Phase 3 — Remove caelestia  **[USER-ASSISTED, after settling]**

### Task 11: Delete caelestia
**Files:** Remove `~/.config/caelestia/`; Modify `~/dotfiles/home.nix` + `flake.nix`; remove chezmoi `caelestia`/`quickshell` dirs.

- [ ] **Step 1: Remove the nix caelestia** — in `home.nix` delete `caelestiaWrapped` from `home.packages`, the `programs.caelestia { … }` block, and the `caelestiaBase`/`caelestiaWrapped` let-bindings; in `flake.nix` delete the `caelestia.url` input + `inputs.caelestia.homeManagerModules.default` from modules. Then `home-manager switch --flake .#devsupreme`.
- [ ] **Step 2: Remove the configs**
```bash
rm -rf ~/.config/caelestia
chezmoi forget --force ~/.config/caelestia 2>/dev/null || true
git -C ~/src/caelestia-shell rm -r --cached dotfiles/private_dot_config/caelestia dotfiles/private_dot_config/quickshell 2>/dev/null || true
rm -rf ~/src/caelestia-shell/dotfiles/private_dot_config/caelestia ~/src/caelestia-shell/dotfiles/private_dot_config/quickshell
```
- [ ] **Step 2b: Remove caelestia refs from hyprland.lua** (live + `.tmpl`, by hand): delete the `local cs = "$HOME/.nix-profile/bin/caelestia-shell"` line (~line 10) and any remaining `caelestia`/`cs` reference (the Print bind stopped using `cs` in Task 10). Keep dracula count at 2.
- [ ] **Step 3: Verify caelestia-free**
```bash
command -v caelestia-shell && echo "STILL PRESENT" || echo "caelestia gone ✓"
grep -rn caelestia ~/.config/hypr/hyprland.lua || echo "no caelestia in hypr ✓"
grep -c '{{ .dracula' ~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl   # still 2
```
- [ ] **Step 4: Commit** both repos: `git -C ~/dotfiles commit -am "feat(nix): remove caelestia (minimal desktop shipped)" && git -C ~/dotfiles push`; `git -C ~/src/caelestia-shell commit -am "feat(desktop): phase3 — remove caelestia config + quickshell dirs"`

---

## Done-When (acceptance)
- caelestia-shell is no longer launched; waybar (toggleable via `Super+B`) + mako + swayosd run instead; the bar shows workspaces/clock + the 4 ADHD cells (salah runway, tracking, project, ctx) + audio/net/tray.
- Notifications (incl. the salah nudge) render via mako; volume/brightness via swayosd; `Print` screenshots via grim/slurp; wallpaper via swww; clipboard via clipse only.
- rofi's last 2 binds gone; otter unchanged + verified. Time-tracking + `~/powerhouse` untouched.
- Phase 3: caelestia removed from configs + nix; rollback was available until then.
