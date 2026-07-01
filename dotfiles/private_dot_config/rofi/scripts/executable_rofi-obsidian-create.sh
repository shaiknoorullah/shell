#!/usr/bin/env bash
#
# rofi-obsidian-create.sh -- Obsidian New Note Wizard
#
# Description:
#   A two-step rofi wizard for creating a new Markdown note in the Obsidian
#   vault. Step 1 lets the user choose which sub-directory to place the
#   note in (or the vault root). Step 2 prompts for the note's name. The
#   script then writes a .md file with YAML frontmatter (date, type, tags)
#   and opens it in VS Code. If a note with that name already exists in the
#   chosen directory, it opens the existing file instead of overwriting it.
#
# Keybinding: (none -- launched as a sub-menu from rofi-obsidian.sh)
#
# Dependencies:
#   - rofi        : menu/prompt interface
#   - code        : VS Code editor
#   - notify-send : desktop notifications
#
# Vault path: ~/powerhouse/
#
# Usage:
#   ~/.config/rofi/scripts/rofi-obsidian-create.sh
#   (Typically invoked from rofi-obsidian.sh "Create New Note" action)
#

THEME="$HOME/.config/rofi/themes/simple.rasi"
VAULT_DIR="$HOME/powerhouse"

# Guard: vault directory must exist
if [[ ! -d "$VAULT_DIR" ]]; then
    notify-send "Obsidian" "Vault not found: $VAULT_DIR" -u critical
    exit 1
fi

# --- Step 1: Select the target directory ---
# List all directories inside the vault as relative paths, excluding hidden
# directories (those starting with '.') which are typically metadata (.git,
# .obsidian, .trash, etc.). The vault root is prepended as "." for
# convenience so the user can create notes at the top level.
dirs=$(find "$VAULT_DIR" -type d -printf "%P\n" | grep -v '^\.' | sort)
dirs=".\n$dirs"  # Prepend vault root as the first option

chosen_dir=$(echo -e "$dirs" | rofi -dmenu -theme "$THEME" -p "Directory" -mesg "Select directory for new note")

[[ -z "$chosen_dir" ]] && exit 0

# --- Step 2: Enter the note name ---
# The -lines 0 flag hides the list area, turning rofi into a simple text
# input prompt. The user should not include the .md extension.
note_name=$(rofi -dmenu -theme "$THEME" -p "Name" -mesg "Enter note name (without .md)" -lines 0)

[[ -z "$note_name" ]] && exit 0

# --- Build the full file path ---
# "." means the vault root; otherwise, ensure the target sub-directory exists
# (mkdir -p is safe if it already does).
if [[ "$chosen_dir" == "." ]]; then
    note_path="$VAULT_DIR/${note_name}.md"
else
    mkdir -p "$VAULT_DIR/$chosen_dir"
    note_path="$VAULT_DIR/$chosen_dir/${note_name}.md"
fi

# --- Duplicate guard ---
# If a note with this name already exists, open it rather than clobbering it.
# This prevents accidental data loss.
if [[ -f "$note_path" ]]; then
    notify-send "Obsidian" "Note already exists: $note_name" -u warning
    code "$note_path"
    exit 0
fi

# --- Write the new note with YAML frontmatter ---
# The frontmatter template matches the vault's conventions: date (ISO 8601),
# type, and an initially empty tags list for the user to populate.
today=$(date +%Y-%m-%d)
cat > "$note_path" << EOF
---
date: $today
type: note
tags: []
---

# $note_name

EOF

code "$note_path"
notify-send "Obsidian" "Created: $note_name" -t 3000
