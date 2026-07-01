#!/usr/bin/env bash
# rofi-websearch-v2.sh — Browser-style search bar with live suggestions
#
# Features:
#   - Single input field (no engine selection step)
#   - Live autocomplete via rofi-blocks + Google Suggest API
#   - URL detection: type a URL to navigate directly
#   - Bang syntax: !g (Google), !ddg (DuckDuckGo), !yt (YouTube),
#                  !w (Wikipedia), !gh (GitHub)
#   - Bookmark and history matches mixed into suggestions
#
# Keybinding: $mod+slash
#
# Dependencies: rofi, rofi-blocks, python3, curl, jq, sqlite3

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THEME="$HOME/.config/rofi/themes/searchbar.rasi"
HANDLER="$SCRIPT_DIR/zen-search-handler.sh"

# Check if rofi-blocks is available
if rofi -dump-config 2>/dev/null | grep -q "blocks"; then
    rofi -modi "blocks" -show blocks \
         -blocks-wrap "$HANDLER" \
         -theme "$THEME" \
         -kb-cancel "Escape" \
         -kb-accept-entry "Return" \
         -matching normal
else
    # Fallback to simple search (like original rofi-websearch.sh)
    source "$SCRIPT_DIR/zen-utils.sh"
    query=$(rofi -dmenu -theme "$THEME" -p "  Search" -mesg "Type to search (no live suggestions — install rofi-blocks)")
    [[ -z "$query" ]] && exit 0
    encoded=$(echo "$query" | zen_urlencode)
    zen_open_url "https://www.google.com/search?q=${encoded}"
fi
