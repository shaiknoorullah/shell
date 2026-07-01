#!/usr/bin/env bash
# zen-tab-switcher.sh — Fuzzy tab search with preview
# Usage: Run directly in a terminal, or via zen-tab-popup.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/zen-utils.sh"

TAB_CACHE="$CACHE_DIR/tab-cache.tsv"
CACHE_TTL=2  # seconds

# Load tabs (with cache for rapid re-invocations)
load_tabs() {
    local now cache_age
    now=$(date +%s)
    if [[ -f "$TAB_CACHE" ]]; then
        cache_age=$(( now - $(stat -c %Y "$TAB_CACHE" 2>/dev/null || echo 0) ))
        if (( cache_age < CACHE_TTL )); then
            cat "$TAB_CACHE"
            return
        fi
    fi
    bt list 2>/dev/null | tee "$TAB_CACHE"
}

# Catppuccin Mocha colors for fzf
FZF_COLORS="bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8"
FZF_COLORS+=",fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc"
FZF_COLORS+=",marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
FZF_COLORS+=",border:#6c7086"

# Get active tab for highlighting
active_tab=$(bt active 2>/dev/null | awk '{print $1}')

selected=$(load_tabs | fzf \
    --ansi \
    --delimiter='\t' \
    --with-nth=2.. \
    --layout=reverse \
    --border=rounded \
    --prompt="  Tabs > " \
    --header="enter:switch | ctrl-d:close | ctrl-y:copy url | ctrl-w:close+next" \
    --header-first \
    --preview="$SCRIPT_DIR/zen-tab-preview.sh {}" \
    --preview-window=down:7:wrap \
    --color="$FZF_COLORS" \
    --bind="ctrl-d:execute-silent(bt close {1})+reload(bt list)" \
    --bind="ctrl-y:execute-silent(echo {3} | wl-copy)+abort" \
    --no-multi \
    --info=inline \
    --tabstop=4 \
    --query="${1:-}" \
)

# If a tab was selected (enter), activate it
if [[ -n "$selected" ]]; then
    tab_id=$(echo "$selected" | awk -F'\t' '{print $1}')
    bt activate "$tab_id" 2>/dev/null
    zen_focus_browser
fi
