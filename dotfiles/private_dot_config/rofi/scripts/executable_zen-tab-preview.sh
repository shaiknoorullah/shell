#!/usr/bin/env bash
# zen-tab-preview.sh — fzf preview pane for tab switcher
# Receives fzf selection line: "TAB_ID\tTitle\tURL"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/zen-utils.sh"

line="$*"
tab_id=$(echo "$line" | awk -F'\t' '{print $1}')
title=$(echo "$line" | awk -F'\t' '{print $2}')
url=$(echo "$line" | awk -F'\t' '{print $3}')
domain=$(echo "$url" | sed -E 's|https?://([^/]+).*|\1|' | sed 's/^www\.//')

# Fetch/cache favicon
favicon=$(zen_get_favicon "$domain")

# Display favicon with kitty icat if file is valid
if [[ -s "$favicon" ]]; then
    kitty +kitten icat --clear --transfer-mode=memory --stdin=no \
        --place=8x4@2x0 "$favicon" 2>/dev/null
fi

# Print metadata below favicon area
printf '\n\n\n\n\n'
printf '\033[1;35m%s\033[0m\n' "$title"
printf '\033[0;36m%s\033[0m\n' "$url"
printf '\033[0;90m%s  •  Tab %s\033[0m\n' "$domain" "$tab_id"
