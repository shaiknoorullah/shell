#!/usr/bin/env bash
#
# rofi-bookmarks.sh -- Zen Browser Bookmarks Browser
#
# Description:
#   Reads bookmarks directly from Zen Browser's SQLite database (places.sqlite)
#   and presents them in a rofi menu. The user can search/filter by title
#   and open the selected bookmark in Zen Browser.
#
# Keybinding: $mod+Shift+o
#
# Dependencies:
#   - rofi        : menu/prompt interface
#   - sqlite3     : queries Zen Browser's places.sqlite database
#   - xdg-open    : opens URLs in the default browser (Zen Browser)
#   - notify-send : desktop notifications
#
# Usage:
#   ~/.config/rofi/scripts/rofi-bookmarks.sh
#
# Technical notes:
#   - Zen Browser holds a WAL (write-ahead log) lock on places.sqlite while
#     running. zen_query_db() copies the database to /tmp before querying,
#     which avoids "database is locked" errors and ensures a consistent read.
#   - Bookmark data spans two tables: moz_bookmarks (metadata) and
#     moz_places (URLs). They are joined via moz_bookmarks.fk -> moz_places.id.
#

# shellcheck source=zen-utils.sh
source "$(dirname "$0")/zen-utils.sh"

THEME="$HOME/.config/rofi/themes/clipboard.rasi"

# Query bookmarks from the Zen Browser profile.
# - moz_bookmarks.type = 1 filters for actual bookmarks (vs. folders, separators)
# - Exclude NULL/empty titles (these are internal Zen Browser entries)
# - Exclude 'place:' URLs (internal smart-bookmark queries)
# - Order by dateAdded DESC so the most recent bookmarks appear first
# - zen_query_db uses tab as the column separator; we reformat to "title | url"
bookmarks=$(zen_query_db "
    SELECT b.title, p.url
    FROM moz_bookmarks b
    JOIN moz_places p ON b.fk = p.id
    WHERE b.type = 1
    AND b.title IS NOT NULL
    AND b.title != ''
    AND p.url NOT LIKE 'place:%'
    ORDER BY b.dateAdded DESC;
" | while IFS=$'\t' read -r title url; do
    echo "$title | $url"
done)

if [[ -z "$bookmarks" ]]; then
    notify-send "Bookmarks" "No bookmarks found" -u normal
    exit 0
fi

chosen=$(echo "$bookmarks" | rofi -dmenu -theme "$THEME" -p "Bookmarks" -mesg "Zen Browser Bookmarks")

if [[ -n "$chosen" ]]; then
    # Extract the URL portion after the " | " separator.
    # sed greedily matches everything up to the last " | " to handle titles
    # that might themselves contain pipe characters.
    url=$(echo "$chosen" | sed 's/.*| //')
    zen_open_url "$url"
fi
