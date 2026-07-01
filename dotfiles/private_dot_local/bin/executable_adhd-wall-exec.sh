#!/usr/bin/env bash
# adhd-wall-exec.sh — host actuator for the quickshell wallpaper widget.
# Triggered by adhd-wall.path when the widget writes ~/.cache/adhd/wall-request
# (a wallpaper path). Applies it to caelestia (its own wallpaper/scheme pipeline;
# swww is no longer used now that caelestia draws the wallpaper). `-N` keeps the
# current (dracula) scheme instead of deriving one from the image.
set -uo pipefail
export PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH"
req="$HOME/.cache/adhd/wall-request"
[ -f "$req" ] || exit 0
p="$(head -n1 "$req" | tr -d '\r')"
rm -f "$req"
[ -n "$p" ] && [ -f "$p" ] && caelestia wallpaper -f "$p" -N
