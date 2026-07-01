# Phase 0 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A clean, secure, single-theme (Dracula) foundation for the ADHD-OS, deployed via chezmoi, with the existing rofi/i3 drift fixed and the test suite green.

**Architecture:** Bring the `ubuntu-dots` repo in sync with the working on-disk config, stop the plaintext-secret leak, then adopt **chezmoi** as the dotfiles manager — its `.chezmoidata.yaml` holds one Dracula palette that templates fan out into every config, and its `age` encryption holds secrets. Safe, reversible, visible wins first; the chezmoi migration last.

**Tech Stack:** bash, BATS (existing rofi tests), chezmoi, age (encryption), rofi/i3/picom/polybar/kitty configs, git.

## Global Constraints

- **Palette: Dracula, everywhere** — base `#282A36`, bg `#15161E`, fg `#F8F8F2`, comment `#6272A4`, purple `#BD93F9`, pink `#FF79C6`, cyan `#8BE9FD`, green `#50FA7B`, orange `#FFB86C`, red `#FF5555`, yellow `#F1FA8C`. Context accents: work=purple, lab=pink, agents=cyan, personal=green.
- **One palette source of truth** — after Task 7, no rendered config may contain a hand-typed Dracula hex; all colors come from `.chezmoidata.yaml` via templates.
- **No secrets in tracked files** — `git grep -nE 'sk-[A-Za-z0-9]'` over tracked files must return nothing after Task 4.
- **Tests stay green** — `cd rofi/tests && bats test_*.bats` must report 0 failures at the end of every task from Task 2 onward.
- **Source of truth for keybindings = `i3/config`** (the running config). README and tests conform to it, never the reverse.
- Work on a branch; commit after every task. Do not push unless asked.
- Font everywhere: `JetBrainsMono Nerd Font`.

---

### Task 1: Commit the 5 on-disk rofi scripts into the repo

The i3 config binds 5 scripts that exist in `~/.config/rofi/scripts/` but were never committed, so a fresh deploy breaks. Bring them into the repo.

**Files:**
- Create: `rofi/scripts/rofilaunch.sh`, `rofi/scripts/rofi-style-selector.sh`, `rofi/scripts/rofi-websearch-v2.sh`, `rofi/scripts/zen-tab-popup.sh`, `rofi/scripts/zen-workspaces.sh`

- [ ] **Step 1: Copy the live scripts into the repo**

```bash
cd ~/ubuntu-dots
for s in rofilaunch.sh rofi-style-selector.sh rofi-websearch-v2.sh zen-tab-popup.sh zen-workspaces.sh; do
  cp -v "$HOME/.config/rofi/scripts/$s" "rofi/scripts/$s"
  chmod +x "rofi/scripts/$s"
done
```

- [ ] **Step 2: Verify every script the i3 config references now exists in-repo**

```bash
cd ~/ubuntu-dots
grep -oE '~/\.config/rofi/scripts/[a-z0-9-]+\.sh' i3/config | sed 's#~/.config/rofi/##' | sort -u | while read p; do
  [ -f "rofi/$p" ] && echo "OK  $p" || echo "MISSING $p"
done
```
Expected: every line prints `OK`. No `MISSING`.

- [ ] **Step 3: Commit**

```bash
cd ~/ubuntu-dots
git add rofi/scripts/rofilaunch.sh rofi/scripts/rofi-style-selector.sh rofi/scripts/rofi-websearch-v2.sh rofi/scripts/zen-tab-popup.sh rofi/scripts/zen-workspaces.sh
git commit -m "fix(rofi): commit 5 scripts referenced by i3 config but missing from repo"
```

---

### Task 2: Reconcile keybinding tests + README to the real i3 config (bats green)

10 tests in `test_i3_keybindings.bats` fail because they assert an old keybinding scheme. `i3/config` is the source of truth; update the tests and README to match it.

**Files:**
- Modify: `rofi/tests/test_i3_keybindings.bats`
- Modify: `rofi/README.md` (keybinding table), `i3/README.md` (keybinding table)

**The real bindings (from `i3/config`, authoritative):**

| Key | Action |
|---|---|
| `$mod+space` | `rofilaunch.sh d` (app launcher/drun) |
| `$mod+Tab` | `rofilaunch.sh w` (window switcher) |
| `$mod+Shift+s` | `rofilaunch.sh --run` |
| `$mod+Shift+f` | `rofilaunch.sh f` (filebrowser) |
| `$mod+Shift+d` | `rofi-style-selector.sh` |
| `$mod+F1` | `rofi -show keys` |
| `$mod+c` | `rofi-clipboard.sh` |
| `$mod+Shift+b` | `rofi-bluetooth.sh` |
| `$mod+Shift+m` | `rofi-display.sh` |
| `$mod+Shift+w` | `rofi-wallpaper.sh` |
| `Print` | `rofi-screenshot.sh` |
| `$mod+Ctrl+s` | `rofi-systemd.sh` |
| `$mod+equal` | `rofi -show calc` |
| `$mod+period` | `rofimoji` |
| `$mod+slash` | `rofi-websearch-v2.sh` |
| `$mod+p` | `rofi-projects.sh` |
| `$mod+g` | `rofi-git-profile.sh` |
| `$mod+t` | `rofi-tmux.sh` |
| `$mod+Shift+o` | `rofi-bookmarks.sh` |
| `$mod+grave` | `zen-tab-popup.sh` |
| `$mod+Shift+t` | `zen-workspaces.sh` |
| `$mod+n` | `rofi-obsidian.sh` |
| `$mod+Shift+n` | `rofi-obsidian-search.sh` |
| `$mod+F2` | `rofi-keybindings.sh` |
| `$mod+m` | `rofi-media.sh` |
| `$mod+Shift+e` | `rofi-power.sh` |

- [ ] **Step 1: Run the suite and capture the exact failing assertions**

```bash
cd ~/ubuntu-dots/rofi/tests
bats test_i3_keybindings.bats 2>&1 | grep -A4 '^not ok' | tee /tmp/failing.txt
```
Expected: 10 `not ok` blocks; each shows the binding string it expected.

- [ ] **Step 2: Update each failing test to assert the real binding**

Open `rofi/tests/test_i3_keybindings.bats`. For every failing `@test`, change the
expected binding string to match the table above (e.g. a test asserting
`$mod+d` → `drun` becomes `$mod+space` → `rofilaunch.sh d`; the systemd test
asserts `$mod+Ctrl+s`; websearch asserts `rofi-websearch-v2.sh`). Add tests for
the bindings that have no coverage yet (`$mod+grave` → `zen-tab-popup.sh`,
`$mod+Shift+t` → `zen-workspaces.sh`, `$mod+Shift+d` → `rofi-style-selector.sh`).

- [ ] **Step 3: Run only this file until green**

```bash
cd ~/ubuntu-dots/rofi/tests
bats test_i3_keybindings.bats
```
Expected: all tests `ok`, 0 failures.

- [ ] **Step 4: Run the full suite**

```bash
cd ~/ubuntu-dots/rofi/tests
bats test_*.bats 2>&1 | tail -3
```
Expected: `0 failures` (146/146 or current total).

- [ ] **Step 5: Update the README keybinding tables**

Edit the keybinding table in both `rofi/README.md` and `i3/README.md` to match the table above (replace the stale `$mod+d`/`$mod+Shift+p`-systemd rows).

- [ ] **Step 6: Commit**

```bash
cd ~/ubuntu-dots
git add rofi/tests/test_i3_keybindings.bats rofi/README.md i3/README.md
git commit -m "test(rofi): reconcile i3-keybinding tests + READMEs to actual config; suite green"
```

---

### Task 3: Fix picom launch path + sync README

`picom/launch.sh` loads `~/.config/picom.conf` but the file deploys to `~/.config/picom/picom.conf`; and the README's blur/opacity numbers don't match `picom.conf`.

**Files:**
- Modify: `picom/launch.sh`
- Modify: `i3/README.md` (picom table)

- [ ] **Step 1: Fix the config paths in launch.sh**

In `picom/launch.sh`, change `~/.config/picom.conf` → `~/.config/picom/picom.conf`
and `~/.config/picom-xrender.conf` → `~/.config/picom/picom-xrender.conf`.

- [ ] **Step 2: Verify the referenced paths exist relative to deploy**

```bash
cd ~/ubuntu-dots
grep -oE '~/\.config/picom/[a-z-]+\.conf' picom/launch.sh | sed 's#~/.config/picom/##' | while read f; do
  [ -f "picom/$f" ] && echo "OK $f" || echo "MISSING $f"; done
```
Expected: `OK picom.conf` and `OK picom-xrender.conf`.

- [ ] **Step 3: Sync README picom numbers to picom.conf**

Read `picom/picom.conf`; update the picom table in `i3/README.md` so blur-strength,
active/inactive opacity match the actual file (currently README says strength 8 /
active 92%; config says strength 5 / 0.95). State the real values.

- [ ] **Step 4: Commit**

```bash
cd ~/ubuntu-dots
git add picom/launch.sh i3/README.md
git commit -m "fix(picom): correct config paths in launch.sh; sync README numbers"
```

---

### Task 4: Stop the plaintext-secret leak (immediate)

`~/.zshrc` contains a live `CZ_OPENAI_API_KEY` and `LITELLM_API_KEY` in plaintext. Rotate and externalize now; chezmoi will encrypt them in Task 6.

**Files:**
- Create: `~/.secrets` (gitignored, chmod 600 — NOT in repo)
- Modify: `~/.zshrc`

- [ ] **Step 1: (OPERATOR ACTION) Rotate the keys**

Rotate `CZ_OPENAI_API_KEY` in the OpenAI dashboard and `LITELLM_API_KEY` at its
source. Claude cannot do this. Paste the new values in the next step.

- [ ] **Step 2: Create the secrets file**

```bash
umask 077
cat > ~/.secrets <<'EOF'
export CZ_OPENAI_API_KEY="<new-rotated-key>"
export LITELLM_API_KEY="<new-rotated-key>"
# Obsidian Local REST API (for Phase 1 capture)
export OBSIDIAN_REST_TOKEN="<from Obsidian local-rest-api settings>"
EOF
chmod 600 ~/.secrets
```

- [ ] **Step 3: Remove the inline keys from ~/.zshrc and source the file**

In `~/.zshrc`, delete the `export CZ_OPENAI_API_KEY=...` and
`export LITELLM_API_KEY=...` lines. Add near the top:

```bash
[ -f ~/.secrets ] && source ~/.secrets
```

- [ ] **Step 4: Verify no secret remains and the env still resolves**

```bash
grep -nE 'sk-[A-Za-z0-9_-]{20,}' ~/.zshrc && echo "STILL LEAKING" || echo "clean"
zsh -ic 'echo ${CZ_OPENAI_API_KEY:+set} ${LITELLM_API_KEY:+set}'
```
Expected: `clean`, then `set set`.

- [ ] **Step 5: Ensure ~/.secrets can never be committed**

```bash
cd ~/ubuntu-dots
grep -q '^\.secrets$' .gitignore 2>/dev/null || echo '.secrets' >> .gitignore
git add .gitignore && git commit -m "chore: gitignore ~/.secrets; keys externalized from .zshrc"
```

---

### Task 5: Install chezmoi + age and initialize the repo as the source

**Files:**
- Create: `~/.config/chezmoi/chezmoi.toml`
- Modify: repo (chezmoi takes the repo as its source dir)

- [ ] **Step 1: Install chezmoi and real age**

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
sudo apt-get install -y age
command -v chezmoi age
```
Expected: both paths print; `chezmoi --version` works.

- [ ] **Step 2: Generate an age key for secret encryption**

```bash
mkdir -p ~/.config/chezmoi
age-keygen -o ~/.config/chezmoi/key.txt 2>&1
chmod 600 ~/.config/chezmoi/key.txt
grep -o 'age1[a-z0-9]*' ~/.config/chezmoi/key.txt | head -1   # this is your recipient
```

- [ ] **Step 3: Point chezmoi's source dir at the repo**

```bash
RECIP=$(grep -o 'age1[a-z0-9]*' ~/.config/chezmoi/key.txt | head -1)
cat > ~/.config/chezmoi/chezmoi.toml <<EOF
sourceDir = "$HOME/ubuntu-dots"
encryption = "age"
[age]
  identity = "$HOME/.config/chezmoi/key.txt"
  recipient = "$RECIP"
EOF
chezmoi source-path
```
Expected: prints `/home/devsupreme/ubuntu-dots`.

- [ ] **Step 4: Commit chezmoi.toml note (key.txt stays OUT of the repo)**

```bash
cd ~/ubuntu-dots
echo 'key.txt' >> .gitignore
git add .gitignore
git commit -m "chore(chezmoi): use repo as source dir; gitignore age key"
```
Note: `~/.config/chezmoi/key.txt` is the master decryption key — back it up to Vaultwarden later (sub-project D), never commit it.

---

### Task 6: Encrypt the secrets into chezmoi

**Files:**
- Create: `dot_secrets.tmpl` or `encrypted_dot_secrets.age` (chezmoi-managed)

- [ ] **Step 1: Have chezmoi adopt ~/.secrets as an encrypted file**

```bash
cd ~/ubuntu-dots
chezmoi add --encrypt ~/.secrets
ls encrypted_private_dot_secrets.age 2>/dev/null || ls -1 | grep -i secrets
```
Expected: an `encrypted_*dot_secrets*.age` file appears in the repo (ciphertext).

- [ ] **Step 2: Verify it round-trips and contains no plaintext key**

```bash
cd ~/ubuntu-dots
chezmoi cat ~/.secrets | grep -c 'export'        # decrypts → should be >=2
grep -aE 'sk-[A-Za-z0-9_-]{20,}' encrypted_*dot_secrets*.age && echo "LEAK" || echo "ciphertext-only"
```
Expected: a count ≥2, then `ciphertext-only`.

- [ ] **Step 3: Commit the encrypted blob**

```bash
cd ~/ubuntu-dots
git add encrypted_*dot_secrets*.age
git commit -m "feat(chezmoi): manage ~/.secrets as age-encrypted secret"
```

---

### Task 7: Dracula token system — one palette, templated into every config

**Files:**
- Create: `.chezmoidata.yaml` (the palette)
- Create: `dot_config/rofi/themes/shared/dracula.rasi.tmpl`
- Modify (convert to templates): i3 colors, polybar `[colors]`, kitty theme, picom tint

- [ ] **Step 1: Write the palette data**

```bash
cd ~/ubuntu-dots
cat > .chezmoidata.yaml <<'EOF'
dracula:
  base: "282A36"
  bg: "15161E"
  fg: "F8F8F2"
  comment: "6272A4"
  purple: "BD93F9"
  pink: "FF79C6"
  cyan: "8BE9FD"
  green: "50FA7B"
  orange: "FFB86C"
  red: "FF5555"
  yellow: "F1FA8C"
context:
  work: "BD93F9"
  lab: "FF79C6"
  agents: "8BE9FD"
  personal: "50FA7B"
EOF
```

- [ ] **Step 2: Create the rofi color template (the pattern for all others)**

```bash
mkdir -p ~/ubuntu-dots/dot_config/rofi/themes/shared
cat > ~/ubuntu-dots/dot_config/rofi/themes/shared/dracula.rasi.tmpl <<'EOF'
/* Generated from .chezmoidata.yaml — do not edit hex by hand */
* {
    cm-base:    #{{ .dracula.base }};
    cm-bg:      #{{ .dracula.bg }};
    cm-fg:      #{{ .dracula.fg }};
    cm-comment: #{{ .dracula.comment }};
    cm-accent:  #{{ .dracula.purple }};
    cm-pink:    #{{ .dracula.pink }};
    cm-cyan:    #{{ .dracula.cyan }};
    cm-green:   #{{ .dracula.green }};
    cm-red:     #{{ .dracula.red }};
    cm-yellow:  #{{ .dracula.yellow }};
}
EOF
```

- [ ] **Step 3: Verify the template renders to real hex**

```bash
cd ~/ubuntu-dots
chezmoi execute-template < dot_config/rofi/themes/shared/dracula.rasi.tmpl | grep -E 'cm-accent|cm-base'
```
Expected: `cm-accent: #BD93F9;` and `cm-base: #282A36;` (no `{{ }}` left).

- [ ] **Step 4: Convert i3, polybar, kitty, picom color blocks to templates**

For each, move the file into the chezmoi `dot_config/<app>/...tmpl` layout and
replace its hardcoded Dracula/Catppuccin hex with `{{ .dracula.<name> }}` refs
(i3 `client.*` lines, polybar `[colors]`, kitty `current-theme.conf`, picom tint).
Have the rofi per-menu themes `@import "shared/dracula"` instead of
`catppuccin-mocha`.

- [ ] **Step 5: Verify no rendered config contains a hand-typed Dracula hex outside the data file**

```bash
cd ~/ubuntu-dots
chezmoi apply --dry-run --verbose 2>&1 | tail -5
# after apply, the only place hex literals live is .chezmoidata.yaml
grep -rniE '#(BD93F9|282A36|F8F8F2|50FA7B)' dot_config/ | grep -v '\.tmpl' || echo "no stray literals"
```
Expected: `no stray literals`.

- [ ] **Step 6: Apply and confirm the rofi suite still passes**

```bash
chezmoi apply
cd ~/ubuntu-dots/rofi/tests && bats test_*.bats 2>&1 | tail -2
```
Expected: 0 failures.

- [ ] **Step 7: Commit**

```bash
cd ~/ubuntu-dots
git add .chezmoidata.yaml dot_config/
git commit -m "feat(theme): Dracula token system — one palette templated into all configs"
```

---

### Task 8: Bootstrap script + README + final verification

**Files:**
- Create: `README.md` (top-level), `run_once_before_00-bootstrap.sh.tmpl` (chezmoi)

- [ ] **Step 1: Write the top-level README**

Create `~/ubuntu-dots/README.md` covering: what this is, the chezmoi model
(`chezmoi init --apply <repo>`), the Dracula token source (`.chezmoidata.yaml`),
the layout (`dot_config/*`), the secret model (age + `~/.config/chezmoi/key.txt`),
and a pointer to `docs/superpowers/specs/2026-06-18-adhd-os-design.md` + the phases.

- [ ] **Step 2: Dry-run a clean apply to prove deployability**

```bash
cd ~/ubuntu-dots
chezmoi apply --dry-run --verbose 2>&1 | tail -20
chezmoi diff | head -40
```
Expected: no errors; diffs are only the intended config/theme changes.

- [ ] **Step 3: Full apply + smoke check**

```bash
chezmoi apply
test -f ~/.config/rofi/themes/shared/dracula.rasi && echo "theme deployed"
test -f ~/.config/picom/picom.conf && echo "picom path ok"
zsh -ic 'echo ${CZ_OPENAI_API_KEY:+secret-set}'
cd ~/ubuntu-dots/rofi/tests && bats test_*.bats 2>&1 | tail -2
```
Expected: `theme deployed`, `picom path ok`, `secret-set`, `0 failures`.

- [ ] **Step 4: Commit**

```bash
cd ~/ubuntu-dots
git add README.md run_once_before_00-bootstrap.sh.tmpl 2>/dev/null; git add -A
git commit -m "docs: top-level README + chezmoi bootstrap; Phase 0 complete"
```

---

## Self-Review

- **Spec coverage:** 0.1 secrets → Tasks 4+6; 0.2 drift (scripts/tests/picom) → Tasks 1–3; 0.3 token system → Task 7; 0.4 chezmoi+README → Tasks 5,8. All §8 items covered.
- **Open Q4 (repoint vs commit missing scripts):** resolved by discovery — the scripts exist on disk, so Task 1 commits them (no repointing needed).
- **Risk ordering:** the irreversible/visible secret leak is stopped early (Task 4) before the larger chezmoi migration; safe drift fixes (1–3) front-loaded for momentum.
- **Verification, not faith:** every task ends in a command with expected output; the bats suite gates Tasks 2,7,8.
