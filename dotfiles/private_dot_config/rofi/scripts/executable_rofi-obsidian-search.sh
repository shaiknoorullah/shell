#!/usr/bin/env bash
#
# rofi-obsidian-search.sh -- Obsidian Note Search
#
# Description:
#   Finds every Markdown (.md) file inside the Obsidian vault and presents
#   them in a rofi menu as vault-relative paths (e.g., "daily/2025-01-15.md").
#   Rofi's built-in fuzzy matching lets the user quickly filter down to the
#   desired note, which is then opened in VS Code.
#
# Keybinding: $mod+Shift+n
#
# Dependencies:
#   - rofi        : menu/prompt interface (with built-in fuzzy filtering)
#   - find        : recursively discovers .md files in the vault
#   - code        : VS Code editor
#   - notify-send : desktop notifications for errors/empty states
#
# Vault path: ~/powerhouse/
#
# Usage:
#   ~/.config/rofi/scripts/rofi-obsidian-search.sh
#   (Also launched from rofi-obsidian.sh "Search Notes" action)
#

THEME="$HOME/.config/rofi/themes/simple.rasi"
VAULT_DIR="$HOME/powerhouse"

# Guard: ensure the vault directory exists before attempting to search
if [[ ! -d "$VAULT_DIR" ]]; then
    notify-send "Obsidian" "Vault not found: $VAULT_DIR" -u critical
    exit 1
fi

# Collect all markdown files and display them as vault-relative paths.
# -printf "%P\n" strips the leading $VAULT_DIR prefix so paths are clean
# and human-readable in the rofi list.
notes=$(find "$VAULT_DIR" -name "*.md" -type f -printf "%P\n" | sort)

if [[ -z "$notes" ]]; then
    notify-send "Obsidian" "No notes found" -u normal
    exit 0
fi

# Let the user pick (or fuzzy-search) a note
chosen=$(echo "$notes" | rofi -dmenu -theme "$THEME" -p "Search" -mesg "Search notes in vault")

# Open the selected note by re-joining the relative path with the vault root
if [[ -n "$chosen" ]]; then
    code "$VAULT_DIR/$chosen"
fi
