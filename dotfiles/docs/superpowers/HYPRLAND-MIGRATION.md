# Hyprland migration — handoff & install steps

> Status as of the autonomous run. **You stay on i3 until this is built + verified.**
> Everything below the WM (taskwarrior, timew, capture/focus, prayer times,
> chezmoi, secrets) already runs and carries over untouched.

## Done autonomously (no binary / no session needed)
- **JaKooLit installer fixed** — re-cloned to the `24.04` branch (the `main` branch was docs-only). `~/Ubuntu-Hyprland/install.sh` is now present.
- **Iqamah prayer times finished** — `adhd-prayer-times.sh` now scaffolds around **Iqamah** (your masjid's congregation times), from `~/.config/adhd/iqamah.conf` (Dhuhr 13:30 / Asr 17:15 set; Fajr/Maghrib/Isha as adhan+offset seeds — edit monthly). Calculated adhan kept as reference. Focus daemon reads it (`→ Dhuhr 13:30`). All Phase-1 tests green.
- **Hyprland config prepped into chezmoi** (`private_dot_config/hypr/`): your 84 i3-keybinds ported, **Dracula** (templated), **blur + shadows ON**, `nvidia.conf` (driver 610, explicit sync), `monitors.conf`, ADHD-engine bindings, and **`layerrule = blur` on bars** (see below).
- **quickshell shell — first-pass authored** (workflow), `private_dot_config/quickshell/`. NOT render-verified yet (see caveat).

## The key insight about the bars
On i3, eww looked flat because **picom wasn't blurring it**. On **Hyprland, the compositor blurs any bar** (`layerrule = blur, eww/waybar/quickshell`). So:

- **Path A — eww on Hyprland (cheap, reuses everything):** our existing 12 backends + eww bars + Hyprland's compositor blur = real glass. Likely looks *dramatically* better than it did on i3, with zero rebuild. **Try this first.**
- **Path B — quickshell (full caelestia aesthetic):** the fluid QtQuick morphs caelestia/Brain-Shell have. The first-pass is authored. **Caveat:** quickshell needs **Qt 6.6+**, but Ubuntu 24.04 ships **Qt 6.4** — so installing quickshell here means getting a newer Qt (PPA / Qt installer / build). That's the real cost of B. Pursue only if A isn't enough.

## Install steps (you run — needs sudo)
1. **Hyprland** (the binary + nvidia + Wayland deps):
   ```bash
   cd ~/Ubuntu-Hyprland && ./install.sh
   ```
   Answers: **nvidia → yes** · **its dotfiles → decline** (we use ours) · **SDDM → optional** (GDM already lists sessions).
2. Tell me it's done. Then I:
   - `chezmoi apply` our `hypr/` config,
   - spin up a **headless Hyprland** instance,
   - test **Path A (eww + blur)** via `grim` screenshots — if it's good, we're basically there,
   - if you want B, sort the Qt situation and verify the quickshell first-pass headless,
   - hand back a **verified** result. *Then* you log in.

## Switching sessions (reminder)
Log out of i3 (`$mod+Shift+e` → Logout, or `i3-msg exit`) → at GDM, **⚙ gear (bottom-right)** → pick **Hyprland** → log in. To return: log out → ⚙ → **i3**. i3 stays the fallback the whole time.
