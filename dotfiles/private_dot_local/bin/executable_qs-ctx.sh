#!/usr/bin/env bash
# qs-ctx.sh — current ADHD context (name + Dracula accent) as JSON for eww.
#
# Reads the active context from ~/.cache/ctx (a single token written by
# adhd-start/adhd-capture). Maps it to the per-context accent from the
# Phase-2 palette plan (.chezmoidata.yaml `context:` block) and emits:
#
#   {"ctx":"work","accent":"#bd93f9"}
#
# Unknown / missing context falls back to `personal` (green) so the bar
# never goes blank. Accent values mirror .chezmoidata.yaml exactly; the
# widget SCSS still owns the rendered color — this JSON is for the label
# + an inline dot tint only.
set -euo pipefail

CTX_FILE="${EWW_CTX_FILE:-$HOME/.cache/ctx}"

# Context token (default personal, per adhd-start.sh convention).
# Tolerate a missing/unreadable file under `set -euo pipefail`.
ctx=""
if [ -r "$CTX_FILE" ]; then
    ctx="$(tr -d '[:space:]' < "$CTX_FILE" 2>/dev/null || true)"
fi
[ -z "$ctx" ] && ctx="personal"

# Per-context accent (Dracula), matching .chezmoidata.yaml `context:`.
case "$ctx" in
    work)     accent="#bd93f9" ;; # purple
    lab)      accent="#ff79c6" ;; # pink
    agents)   accent="#8be9fd" ;; # cyan
    personal) accent="#50fa7b" ;; # green
    *)        ctx="personal"; accent="#50fa7b" ;; # unknown -> personal
esac

printf '{"ctx":"%s","accent":"%s"}\n' "$ctx" "$accent"
