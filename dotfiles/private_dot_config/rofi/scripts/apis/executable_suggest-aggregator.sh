#!/usr/bin/env bash
# suggest-aggregator.sh — Unified suggestion fetcher
# Usage: suggest-aggregator.sh "query" [google|ddg|youtube|wikipedia]
# Output: One suggestion per line, prefixed with type icon

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../zen-utils.sh"

query="$1"
engine="${2:-google}"

[[ -z "$query" ]] && exit 0

# Temp files for parallel fetching
tmp_api=$(mktemp)
tmp_bookmarks=$(mktemp)
tmp_history=$(mktemp)
trap 'rm -f "$tmp_api" "$tmp_bookmarks" "$tmp_history"' EXIT

# 1. API suggestions (background)
(
    case "$engine" in
        google)
            curl -sG "https://suggestqueries.google.com/complete/search" \
                --data-urlencode "q=$query" --data-urlencode "client=firefox" 2>/dev/null \
            | jq -r '.[1][]' 2>/dev/null | head -5 | sed 's/^/  /'
            ;;
        ddg)
            curl -sG "https://duckduckgo.com/ac/" \
                --data-urlencode "q=$query" --data-urlencode "type=list" 2>/dev/null \
            | jq -r '.[1][]' 2>/dev/null | head -5 | sed 's/^/  /'
            ;;
        youtube)
            curl -sG "https://suggestqueries.google.com/complete/search" \
                --data-urlencode "q=$query" --data-urlencode "client=youtube" --data-urlencode "ds=yt" 2>/dev/null \
            | jq -r '.[1][]' 2>/dev/null | head -5 | sed 's/^/  /'
            ;;
        wikipedia)
            curl -sG "https://en.wikipedia.org/w/api.php" \
                --data-urlencode "action=opensearch" --data-urlencode "search=$query" \
                --data-urlencode "limit=5" 2>/dev/null \
            | jq -r '.[1][]' 2>/dev/null | head -5 | sed 's/^/󰖬  /'
            ;;
    esac > "$tmp_api"
) &

# Escape single quotes for safe interpolation into SQL LIKE clauses below.
qsql="${query//\'/\'\'}"

# 2. Bookmark matches (background)
(
    zen_query_db "
        SELECT b.title, p.url FROM moz_bookmarks b
        JOIN moz_places p ON b.fk = p.id
        WHERE b.type = 1 AND b.title IS NOT NULL
        AND (b.title LIKE '%${qsql}%' OR p.url LIKE '%${qsql}%')
        ORDER BY b.dateAdded DESC LIMIT 3;
    " 2>/dev/null | while IFS=$'\t' read -r title url; do
        echo "  $title  ·  $url"
    done > "$tmp_bookmarks"
) &

# 3. History matches (background)
(
    zen_query_db "
        SELECT title, url FROM moz_places
        WHERE visit_count > 0
        AND (title LIKE '%${qsql}%' OR url LIKE '%${qsql}%')
        ORDER BY visit_count DESC, last_visit_date DESC LIMIT 3;
    " 2>/dev/null | while IFS=$'\t' read -r title url; do
        echo "  $title  ·  $url"
    done > "$tmp_history"
) &

wait

# Output in order: API suggestions, bookmarks, history
cat "$tmp_api"
[[ -s "$tmp_bookmarks" ]] && cat "$tmp_bookmarks"
[[ -s "$tmp_history" ]] && cat "$tmp_history"
