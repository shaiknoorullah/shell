#!/usr/bin/env bash
#
# rofi-websearch.sh -- Web Search Launcher
#
# Description:
#   Multi-engine web search from rofi. Supports two modes depending on
#   whether the rofi-blocks plugin is installed:
#
#   With rofi-blocks (enhanced mode):
#     1. Select a search engine (Google, DuckDuckGo, YouTube, Wikipedia)
#     2. Type a query (rofi-blocks could provide live autocomplete suggestions
#        via the API helper scripts in apis/)
#     3. Opens the search results in Firefox
#
#   Without rofi-blocks (fallback mode):
#     1. Select a search engine (adds GitHub as a 5th option)
#     2. Type a query in a plain rofi text input
#     3. Opens the search results in Firefox
#
#   In both modes, queries are URL-encoded via Python's urllib.parse to
#   handle special characters safely.
#
# Keybinding: $mod+slash
#
# Dependencies:
#   - rofi    : menu/prompt interface
#   - firefox : web browser (opens the search URL)
#   - python3 : URL-encodes the query string (urllib.parse.quote_plus)
#   - curl    : (for blocks mode) used by API suggestion scripts
#
# Optional:
#   - rofi-blocks plugin : enables live suggestion mode
#
# Related scripts (in apis/):
#   - google-suggest.sh, ddg-suggest.sh, youtube-suggest.sh, wikipedia-suggest.sh
#
# Usage:
#   ~/.config/rofi/scripts/rofi-websearch.sh
#

THEME="$HOME/.config/rofi/themes/clipboard.rasi"
API_DIR="$HOME/.config/rofi/scripts/apis"

# Detect whether rofi was built with the "blocks" plugin by inspecting
# rofi's config dump. This determines which UI mode we use.
has_blocks=false
if rofi -dump-config 2>/dev/null | grep -q "blocks"; then
    has_blocks=true
fi

if [[ "$has_blocks" == true ]]; then
    # --- Enhanced mode: rofi-blocks available ---
    # In this mode, the API scripts in apis/ can provide live autocomplete
    # suggestions as the user types. GitHub is excluded here because it
    # does not have a public suggestions API.
    engines="  Google\n  DuckDuckGo\n  YouTube\n󰖬  Wikipedia"

    engine=$(echo -e "$engines" | rofi -dmenu -theme "$THEME" -p "Search" -mesg "Select search engine")

    [[ -z "$engine" ]] && exit 0

    # Map the chosen engine to its API suggestion script and search URL.
    # The api_script variable points to the helper that fetches autocomplete
    # suggestions for rofi-blocks to display.
    case "$engine" in
        *"Google"*)      api_script="$API_DIR/google-suggest.sh"; search_url="https://www.google.com/search?q=" ;;
        *"DuckDuckGo"*)  api_script="$API_DIR/ddg-suggest.sh"; search_url="https://duckduckgo.com/?q=" ;;
        *"YouTube"*)     api_script="$API_DIR/youtube-suggest.sh"; search_url="https://www.youtube.com/results?search_query=" ;;
        *"Wikipedia"*)   api_script="$API_DIR/wikipedia-suggest.sh"; search_url="https://en.wikipedia.org/wiki/Special:Search?search=" ;;
        *)               exit 0 ;;
    esac

    query=$(rofi -dmenu -theme "$THEME" -p "Query" -mesg "Type your search query")

    if [[ -n "$query" ]]; then
        # URL-encode the query to handle spaces, ampersands, and other
        # special characters that would break the URL.
        encoded_query=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))' "$query")
        firefox "${search_url}${encoded_query}" &
    fi
else
    # --- Fallback mode: no rofi-blocks ---
    # Simple two-step flow: pick an engine, type a query.
    # GitHub is included here as a 5th option since this mode does not
    # rely on suggestion APIs (GitHub has no public autocomplete endpoint).
    engines="  Google\n  DuckDuckGo\n  YouTube\n󰖬  Wikipedia\n  GitHub"

    engine=$(echo -e "$engines" | rofi -dmenu -theme "$THEME" -p "Search" -mesg "Select search engine")

    [[ -z "$engine" ]] && exit 0

    query=$(rofi -dmenu -theme "$THEME" -p "Query" -mesg "Type your search query")

    [[ -z "$query" ]] && exit 0

    # URL-encode the query using Python's urllib
    encoded_query=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))' "$query")

    # Open the appropriate search URL in Firefox (backgrounded to avoid blocking)
    case "$engine" in
        *"Google"*)      firefox "https://www.google.com/search?q=${encoded_query}" & ;;
        *"DuckDuckGo"*)  firefox "https://duckduckgo.com/?q=${encoded_query}" & ;;
        *"YouTube"*)     firefox "https://www.youtube.com/results?search_query=${encoded_query}" & ;;
        *"Wikipedia"*)   firefox "https://en.wikipedia.org/wiki/Special:Search?search=${encoded_query}" & ;;
        *"GitHub"*)      firefox "https://github.com/search?q=${encoded_query}" & ;;
    esac
fi
