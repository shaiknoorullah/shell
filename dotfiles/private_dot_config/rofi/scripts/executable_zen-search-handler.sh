#!/usr/bin/env bash
# zen-search-handler.sh — rofi-blocks handler for browser-style search
# Protocol: reads events from stdin, writes JSON to stdout
# Events: INPUT_CHANGE <text>, SELECT_ENTRY <text>, EXEC_CUSTOM_INPUT <text>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/zen-utils.sh"

AGGREGATOR="$SCRIPT_DIR/apis/suggest-aggregator.sh"
DEBOUNCE_PID=""
engine="google"
engine_label=""

# URL detection regex
is_url() {
    [[ "$1" =~ ^https?:// ]] || [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+(/.*)?$ ]]
}

# Parse bang prefix and return engine name
parse_bang() {
    local input="$1"
    case "$input" in
        '!g '*)    echo "google|${input#!g }" ;;
        '!ddg '*)  echo "ddg|${input#!ddg }" ;;
        '!d '*)    echo "ddg|${input#!d }" ;;
        '!yt '*)   echo "youtube|${input#!yt }" ;;
        '!w '*)    echo "wikipedia|${input#!w }" ;;
        '!gh '*)   echo "github|${input#!gh }" ;;
        *)         echo "|$input" ;;
    esac
}

# Build search URL for given engine and query
search_url() {
    local eng="$1" q
    q=$(echo "$2" | zen_urlencode)
    case "$eng" in
        google)    echo "https://www.google.com/search?q=$q" ;;
        ddg)       echo "https://duckduckgo.com/?q=$q" ;;
        youtube)   echo "https://www.youtube.com/results?search_query=$q" ;;
        wikipedia) echo "https://en.wikipedia.org/wiki/Special:Search?search=$q" ;;
        github)    echo "https://github.com/search?q=$q" ;;
        *)         echo "https://www.google.com/search?q=$q" ;;
    esac
}

# Handle input change — fetch suggestions
handle_input() {
    local input="$1"

    # Kill previous debounce if still running
    [[ -n "$DEBOUNCE_PID" ]] && kill "$DEBOUNCE_PID" 2>/dev/null

    # Don't query for very short input
    if (( ${#input} < 2 )); then
        echo '{"lines":[]}'
        return
    fi

    # Parse bangs
    local parsed eng query
    parsed=$(parse_bang "$input")
    eng="${parsed%%|*}"
    query="${parsed#*|}"
    [[ -n "$eng" ]] && engine="$eng"

    # URL detection — offer direct navigation
    if is_url "$query"; then
        local url="$query"
        [[ ! "$url" =~ ^https?:// ]] && url="https://$url"
        printf '{"lines":[{"text":"  Open %s","data":"url:%s"}]}\n' "$query" "$url"
        return
    fi

    # Fetch suggestions (with debounce via subshell)
    (
        sleep 0.12
        local suggestions
        suggestions=$("$AGGREGATOR" "$query" "$engine" 2>/dev/null)
        if [[ -n "$suggestions" ]]; then
            # Build JSON lines array
            local json='{"lines":['
            local first=true
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                # Escape quotes for JSON
                line="${line//\\/\\\\}"
                line="${line//\"/\\\"}"
                if [[ "$first" == true ]]; then
                    first=false
                else
                    json+=","
                fi
                json+="{\"text\":\"$line\"}"
            done <<< "$suggestions"
            json+=']}'
            echo "$json"
        else
            echo '{"lines":[]}'
        fi
    ) &
    DEBOUNCE_PID=$!
    wait "$DEBOUNCE_PID" 2>/dev/null
    DEBOUNCE_PID=""
}

# Handle entry selection
handle_select() {
    local entry="$1"
    # Check if it's a direct URL entry
    if [[ "$entry" == url:* ]]; then
        zen_open_url "${entry#url:}"
    elif [[ "$entry" =~ ·[[:space:]]+(https?://) ]]; then
        # Bookmark/history entry with URL after " · "
        local url="${entry##*· }"
        url="${url## }"
        zen_open_url "$url"
    else
        # Search suggestion — strip icon prefix and search
        local query="${entry#*  }"  # Remove icon + spaces
        query="${query#*  }"
        local url
        url=$(search_url "$engine" "$query")
        zen_open_url "$url"
    fi
}

# Initial setup message for rofi-blocks
echo '{"input action":"send","prompt":"  Search","event format":"{{name_enum}} {{value}}"}'

# Main event loop
while IFS= read -r event; do
    case "$event" in
        "INPUT_CHANGE "*)
            handle_input "${event#INPUT_CHANGE }"
            ;;
        "SELECT_ENTRY "*)
            handle_select "${event#SELECT_ENTRY }"
            ;;
        "EXEC_CUSTOM_INPUT "*)
            input="${event#EXEC_CUSTOM_INPUT }"
            if is_url "$input"; then
                [[ ! "$input" =~ ^https?:// ]] && input="https://$input"
                zen_open_url "$input"
            else
                parsed=$(parse_bang "$input")
                eng="${parsed%%|*}"
                query="${parsed#*|}"
                [[ -n "$eng" ]] && engine="$eng"
                url=$(search_url "$engine" "$query")
                zen_open_url "$url"
            fi
            ;;
    esac
done
