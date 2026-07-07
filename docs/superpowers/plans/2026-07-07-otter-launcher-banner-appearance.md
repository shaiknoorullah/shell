# otter-launcher "banner-top otter" Appearance — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Super+D otter-launcher into a banner-top design — a crisp full-width otter banner, one nerd-font system-info line, Dracula colors, and icon module rows — modeled on the upstream demos.

**Architecture:** Keep otter's `config.toml` thin; push the two complex, testable pieces (banner render, stat line) into standalone scripts that `header_cmd` / `header` call. All ANSI in the TOML is written as literal `` through a Python-writer script (the Edit tool corrupts the escape, and raw ESC / `\x1b` are rejected by otter's TOML parser). The window size lives in the Hyprland rule and is tuned against user screenshots. Everything is chezmoi-managed and synced back to the dotfiles repo at the end.

**Tech Stack:** otter-launcher 0.7.5 (TOML), bash, chafa 1.18.2 (`-f kitty`), kitty image protocol, JetBrainsMono Nerd Font, Hyprland (Lua config via chezmoi template), chezmoi, git.

## Global Constraints

- ANSI in `config.toml` MUST be the literal 6-char sequence `` — written via a Python script, never the Edit tool, never raw ESC or `\x1b`.
- Banner rendered with `chafa -f kitty` (kitty image protocol), never chafa-ANSI/sixel.
- Dracula palette, exact hexes: bg `#282a36`, fg `#f8f8f2`, purple `#bd93f9`, pink `#ff79c6`, comment `#6272a4`, current-line `#44475a`.
- Work-safe imagery only; image file stored locally in the repo, no exfiltration.
- Live edits land in `~/.config/...`, then are re-added to the chezmoi source and pushed to `github-personal:shaiknoorullah/dotfiles`, branch `feat/caelestia-widgets`.
- The hyprland chezmoi template `private_dot_config/hypr/hyprland.lua.tmpl` contains `{{ .dracula.purple }}` / `{{ .dracula.pink }}` / `{{ .dracula.surface0 }}` on its border lines — these MUST be preserved on any re-sync (force-copy live → tmpl, then sed the 3 resolved colors back to directives).
- Cursor/visual results can't be self-tested — those steps are **USER VERIFY** (screenshot).

## File structure

| File | Responsibility |
|---|---|
| `~/.config/otter-launcher/images/otter.jpg` | the chosen banner image (source of truth) |
| `~/.config/otter-launcher/scripts/otter-banner.sh` | render the image via `chafa -f kitty` at a cell size |
| `~/.config/otter-launcher/scripts/otter-stats.sh` | print the nerd-font stat line (user@host + load + mem + uptime + WM) |
| `~/.config/otter-launcher/config.toml` | interface + module styling; calls the two scripts |
| `~/.config/hypr/hyprland.lua` | `class="otter"` window size rule |
| chezmoi source mirrors (`private_dot_*`) | committed + pushed at the end |

Scripts keep the ANSI-heavy stat line and the image logic OUT of the TOML, so the only TOML ANSI is separator / prefixes / prompt (handled by the Python-writer).

---

### Task 1: Source and choose the banner image

**Files:**
- Create: `~/.config/otter-launcher/images/otter.jpg`

- [ ] **Step 1: Fetch 2-3 dark, work-safe otter candidates into scratch**

```bash
D=/tmp/otter-cand; mkdir -p "$D"
# candidate A: upstream repo's painterly swimming otter (GPL, the foot.png source)
curl -sSL -o "$D/a.jpg" "https://github.com/kuokuo123/otter-launcher/raw/main/assets/otter_swim.jpg" || true
# candidate B/C: additional dark otter stills (CC0/public-domain sources) — fill at build time
ls -la "$D"
```

- [ ] **Step 2: Preview each candidate inline (kitty), Dracula-tinted**

```bash
for f in "$D"/*.jpg; do echo "== $f =="; chafa -f kitty --size 56x8 "$f"; done
```

- [ ] **Step 3: USER VERIFY — user picks one candidate.** Present the rendered options; user names the file. (User-gated: do not proceed until chosen.)

- [ ] **Step 4: Install the chosen image**

```bash
mkdir -p ~/.config/otter-launcher/images
cp -f "$D/<chosen>.jpg" ~/.config/otter-launcher/images/otter.jpg
file ~/.config/otter-launcher/images/otter.jpg   # expect: JPEG/PNG image data
```

- [ ] **Step 5: Verify chafa can render it in kitty protocol**

```bash
chafa -f kitty --size 56x8 ~/.config/otter-launcher/images/otter.jpg | head -c 32 | xxd | head -1
```
Expected: non-empty output beginning with the kitty graphics escape (`\e_G...`).

---

### Task 2: Banner renderer script

**Files:**
- Create: `~/.config/otter-launcher/scripts/otter-banner.sh`

**Interfaces:**
- Produces: `otter-banner.sh [COLS] [ROWS]` → prints the kitty-protocol banner to stdout. Defaults COLS=56, ROWS=8. Called by `config.toml` `header_cmd`.

- [ ] **Step 1: Write the script**

```bash
mkdir -p ~/.config/otter-launcher/scripts
cat > ~/.config/otter-launcher/scripts/otter-banner.sh <<'EOF'
#!/usr/bin/env bash
# Render the otter banner via kitty's image protocol (crisp). Called from otter header_cmd.
set -uo pipefail
export PATH="/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin${PATH:+:$PATH}"
IMG="${OTTER_BANNER:-$HOME/.config/otter-launcher/images/otter.jpg}"
COLS="${1:-56}"; ROWS="${2:-8}"
[ -f "$IMG" ] || exit 0
chafa -f kitty --size "${COLS}x${ROWS}" --align top,center "$IMG" 2>/dev/null
EOF
chmod +x ~/.config/otter-launcher/scripts/otter-banner.sh
```

- [ ] **Step 2: Syntax check**

```bash
bash -n ~/.config/otter-launcher/scripts/otter-banner.sh && echo "syntax OK"
```
Expected: `syntax OK`

- [ ] **Step 3: Verify it emits kitty-protocol bytes**

```bash
~/.config/otter-launcher/scripts/otter-banner.sh 56 8 | head -c 16 | xxd | head -1
```
Expected: starts with the kitty graphics escape (`1b 5f 47` = `\e_G`).

- [ ] **Step 4: USER VERIFY — run it in a kitty terminal**

```bash
~/.config/otter-launcher/scripts/otter-banner.sh 56 8
```
Expected: the otter image draws in the terminal.

- [ ] **Step 5: Commit**

```bash
git -C ~/src/caelestia-shell add -A && git -C ~/src/caelestia-shell status --short  # staged next in Task 6 sync; local checkpoint only
```

---

### Task 3: Stat-line script

**Files:**
- Create: `~/.config/otter-launcher/scripts/otter-stats.sh`

**Interfaces:**
- Produces: `otter-stats.sh` → prints ONE line: `<user>@<host>  <heart> <load>%  <mem-icon> <mem>  <up-icon> <uptime>  <wm-icon> hypr`, Dracula-colored via truecolor ANSI. Called via `$(...)` inside `config.toml` `header`.

- [ ] **Step 1: Write the script** (nerd-font glyphs are literal UTF-8; ANSI via bash `$'\e'` — legal here because this is a script, not the TOML)

```bash
cat > ~/.config/otter-launcher/scripts/otter-stats.sh <<'EOF'
#!/usr/bin/env bash
# One-line otter-launcher system-info bar (Dracula truecolor + nerd-font icons).
set -uo pipefail
export PATH="/usr/bin:/bin:$HOME/.local/bin${PATH:+:$PATH}"
e=$'\e'
purple="${e}[38;2;189;147;249m"; pink="${e}[38;2;255;121;198m"
fg="${e}[38;2;248;248;242m"; dim="${e}[38;2;98;114;164m"; rst="${e}[0m"
host="$(hostname -s 2>/dev/null || echo dev)"
cores="$(nproc 2>/dev/null || echo 1)"
load="$(awk -v c="$cores" '{printf "%.0f", ($1/c)*100}' /proc/loadavg 2>/dev/null)"
mem="$(free -h --si 2>/dev/null | awk 'NR==2{print $3}')"
up="$(uptime -p 2>/dev/null | sed 's/up //; s/,.*//; s/ hours\?/h/; s/ hour\?/h/; s/ minutes\?/m/; s/ minute\?/m/; s/ //g')"
printf '   %s%s%s@%s%s    %s%s %s%s%%    %s󰍛%s %s%s    %s%s %s%s    %s%s %shypr%s\n' \
  "$purple" "$USER" "$fg" "$host" "$rst" \
  "$pink" "$rst" "$dim" "$load" \
  "$purple" "$rst" "$dim" "$mem" \
  "$purple" "$rst" "$dim" "$up" \
  "$purple" "$rst" "$dim" "$rst"
EOF
chmod +x ~/.config/otter-launcher/scripts/otter-stats.sh
```

- [ ] **Step 2: Syntax check**

```bash
bash -n ~/.config/otter-launcher/scripts/otter-stats.sh && echo "syntax OK"
```
Expected: `syntax OK`

- [ ] **Step 3: Verify output shape (one line, values present)**

```bash
~/.config/otter-launcher/scripts/otter-stats.sh | cat -v | head
```
Expected: a single line containing `devsupreme@<host>`, a number+`%`, a memory size, an uptime token, and `hypr`, with `^[[38;2;...` truecolor codes.

- [ ] **Step 4: USER VERIFY — glyphs render** (run in kitty, confirm the heart / chip / clock / WM icons show, not tofu boxes).

---

### Task 4: Rewrite config.toml via the Python-writer

**Files:**
- Modify: `~/.config/otter-launcher/config.toml` (full rewrite of `[general]` + `[interface]` + `[[modules]]` styling)

**Interfaces:**
- Consumes: `otter-banner.sh` (header_cmd), `otter-stats.sh` (header).

- [ ] **Step 1: Write the generator** (placeholder `@E@` → literal ``, so no raw ESC ever reaches the file)

```python
# /tmp/gen_otter_config.py
import pathlib
E = "@E@"
cfg = f'''# otter-launcher — banner-top otter (Dracula). ANSI = \\u001b (literal).
[general]
default_module = "ws"
vi_mode = false
loop_mode = false
esc_to_abort = true
cheatsheet_entry = "?"
cheatsheet_viewer = "less -R; clear"
delay_startup = 30

[interface]
suggestion_mode = "list"
suggestion_lines = 4
customized_list_order = true
header_cmd = "$HOME/.config/otter-launcher/scripts/otter-banner.sh 56 8"
header_cmd_trimmed_lines = 1
header = "$($HOME/.config/otter-launcher/scripts/otter-stats.sh)\\n    {E}[38;2;189;147;249m❯{E}[0m "
separator = "    {E}[38;2;98;114;164m──────────────────────────────{E}[0m"
footer = ""
place_holder = "type a prefix…"
prefix_padding = 3
list_prefix = "     "
selection_prefix = "   {E}[38;2;255;121;198m▌{E}[0m "
prefix_color = "{E}[38;2;189;147;249m"
description_color = "{E}[38;2;248;248;242m"
place_holder_color = "{E}[38;2;98;114;164m"
cursor_shape = 6

[[modules]]
description = " project context"
prefix = "c"
cmd = "/home/devsupreme/.local/bin/ctx '{{}}'"
with_argument = true
unbind_proc = true

[[modules]]
description = " web search"
prefix = "ws"
cmd = "xdg-open 'https://duckduckgo.com/?q={{}}'"
with_argument = true
url_encode = true
unbind_proc = true

[[modules]]
description = " shell"
prefix = "sh"
cmd = "kitty --hold -e sh -c '{{}}'"
with_argument = true
unbind_proc = true

[[modules]]
description = "󰸉 wallpaper picker"
prefix = "wp"
cmd = "kitty --class wallpaper --config /home/devsupreme/.config/kitty/otter.conf -e /home/devsupreme/.local/bin/wallpaper"
unbind_proc = true
'''
cfg = cfg.replace("@E@", "\\u001b")
pathlib.Path("/home/devsupreme/.config/otter-launcher/config.toml").write_text(cfg)
print("written", len(cfg), "bytes;", cfg.count("\\u001b"), "escapes")
```

- [ ] **Step 2: Run it**

```bash
python3 /tmp/gen_otter_config.py
```
Expected: `written NNN bytes; NN escapes`

- [ ] **Step 3: Verify the TOML parses**

```bash
timeout 3 ~/.cargo/bin/otter-launcher </dev/null 2>&1 | head -3
```
Expected: empty (valid). Any TOML error printed here = fail; re-check `@E@` substitution.

- [ ] **Step 4: USER VERIFY — Super+D.** Banner draws crisp (not skewed), stat line populated, `❯` prompt on the 4-col gutter, module rows show icons + purple prefixes + `▌` pink on the active row. Screenshot back.

- [ ] **Step 5: If banner skews** (partial/garbled image): raise `delay_startup` to 60, re-run Step 2-4. If a stray blank line pushes the layout: adjust `header_cmd_trimmed_lines` (0/1/2).

---

### Task 5: Window sizing (Hyprland) + screenshot iteration

**Files:**
- Modify: `~/.config/hypr/hyprland.lua` (the `class = "^(otter)$"` size rule, currently `size = "420 270"`)

- [ ] **Step 1: Set a banner-top starting size** (wide + short: banner 8 + stat 1 + prompt 1 + sep 1 + list 4 + margins ≈ 16 rows)

```bash
sed -i 's/class = "\^(otter)\$" }, size = "[0-9 ]*"/class = "^(otter)$" }, size = "640 430"/' ~/.config/hypr/hyprland.lua
grep -n 'class = "\^(otter)\$" }, size' ~/.config/hypr/hyprland.lua
```

- [ ] **Step 2: Reload Hyprland**

```bash
export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE="$(find /run/user/1001/hypr -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | head -1)"
hyprctl reload | head -1
```
Expected: `ok`

- [ ] **Step 3: USER VERIFY — Super+D + screenshot.** Window should hug the content: banner spans the width, no dead space right/below, nothing clipped.

- [ ] **Step 4: Tune.** From the screenshot: if right dead-space → reduce width + reduce banner COLS in `config.toml` header_cmd arg to match; if bottom dead-space → reduce height; if clipped → increase. Repeat Steps 1-3 until it hugs. Keep banner COLS ≈ (window_px_width − 2*padding) / cell_width so the banner fills the width.

---

### Task 6: Sync to the dotfiles repo and push

**Files:**
- chezmoi source: `private_dot_config/otter-launcher/{config.toml,scripts/*,images/otter.jpg}`, `private_dot_config/hypr/hyprland.lua.tmpl`

- [ ] **Step 1: Add the new scripts + image, re-add the changed config**

```bash
cd ~/src/caelestia-shell
chezmoi add ~/.config/otter-launcher/scripts/otter-banner.sh \
            ~/.config/otter-launcher/scripts/otter-stats.sh \
            ~/.config/otter-launcher/images/otter.jpg \
            ~/.config/otter-launcher/config.toml
chezmoi status | grep otter || echo "otter source in sync"
```

- [ ] **Step 2: Re-sync the hyprland template, preserving the `{{ }}` directives**

```bash
SRC=~/src/caelestia-shell/dotfiles/private_dot_config/hypr/hyprland.lua.tmpl
command cp -f ~/.config/hypr/hyprland.lua "$SRC"
sed -i \
  -e 's|rgb(bd93f9)", "rgb(ff79c6)|rgb({{ .dracula.purple }})", "rgb({{ .dracula.pink }})|' \
  -e 's|"rgb(232336)"|"rgb({{ .dracula.surface0 }})"|' \
  "$SRC"
chezmoi diff ~/.config/hypr/hyprland.lua | head -3   # expect EMPTY
grep -c '{{' "$SRC"                                    # expect 2
```

- [ ] **Step 3: Commit**

```bash
cd ~/src/caelestia-shell
git add dotfiles/private_dot_config/otter-launcher dotfiles/private_dot_config/hypr/hyprland.lua.tmpl
git commit -F - <<'MSG'
feat(otter): banner-top otter appearance — chafa-kitty banner, stat line, Dracula

Banner-top redesign per docs/superpowers/specs/2026-07-07-otter-launcher-banner-design.md:
otter-banner.sh (chafa -f kitty) + otter-stats.sh (nerd-font stat line), config.toml
restyled to Dracula with icon module rows, hyprland otter window sized for banner-top.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
MSG
```

- [ ] **Step 4: Push**

```bash
git -C ~/src/caelestia-shell push home feat/caelestia-widgets 2>&1 | tail -3
```
Expected: a `feat/caelestia-widgets -> feat/caelestia-widgets` update line.

- [ ] **Step 5: Verify remote matches**

```bash
git -C ~/src/caelestia-shell log --oneline -1
git -C ~/src/caelestia-shell log --oneline home/feat/caelestia-widgets -1
```
Expected: same SHA.

---

## Self-review

**Spec coverage:** banner (T1,T2), stat line (T3), config/colors/icons/separator/prompt (T4), window sizing (T5), tooling (chafa installed pre-plan; nerd font present), image sourcing (T1), sync/push (T6), work-safe imagery (T1 constraint), preserve `{{ }}` template (T6 S2). All spec sections map to a task.

**Placeholder scan:** the only deferred item is *which* image (T1 Step 3, user-gated by design) and the tuning values in T5 (explicitly screenshot-driven, with the adjustment rule given) — not placeholders.

**Consistency:** `otter-banner.sh COLS ROWS` signature is consistent between T2 (definition) and T4 (`header_cmd = "... 56 8"`) and T5 (tune COLS with width). `otter-stats.sh` called via `$(...)` in T4 header. Dracula hexes identical across stat script (truecolor `189;147;249` = `#bd93f9`, `255;121;198` = `#ff79c6`, `98;114;164` = `#6272a4`) and the TOML. Module `cmd` values preserved verbatim from the current config.
