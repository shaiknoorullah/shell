#!/usr/bin/env bash
#
# rofi-obsidian.sh -- Obsidian Quick Actions Hub
#
# Description:
#   Central launcher for Obsidian vault operations. Presents a rofi menu
#   with four quick actions: create today's daily note (with YAML
#   frontmatter template), open the entire vault in VS Code, search
#   existing notes, or create a brand-new note. The search and create
#   actions delegate to dedicated companion scripts.
#
# Keybinding: $mod+n
#
# Dependencies:
#   - rofi        : menu/prompt interface
#   - code        : VS Code editor (used to open notes and the vault)
#   - notify-send : desktop notifications (used by sub-scripts)
#
# Related scripts:
#   - rofi-obsidian-search.sh : full-text note search (launched from here)
#   - rofi-obsidian-create.sh : new-note creation wizard (launched from here)
#
# Vault path: ~/powerhouse/
#
# Usage:
#   ~/.config/rofi/scripts/rofi-obsidian.sh
#

THEME="$HOME/.config/rofi/themes/simple.rasi"
VAULT_DIR="$HOME/powerhouse"
SCRIPT_DIR="$HOME/.config/rofi/scripts"

# Menu options -- each prefixed with a Nerd Font icon for visual clarity
options="  Create Daily Note\n  Open Vault in VS Code\n  Search Notes\n  Create New Note"

chosen=$(echo -e "$options" | rofi -dmenu -theme "$THEME" -p "Obsidian" -mesg "Quick Actions")

[[ -z "$chosen" ]] && exit 0

case "$chosen" in
    *"Daily Note"*)
        # --- Create (or open) today's daily note ---
        # Daily notes live in <vault>/daily/ and are named by ISO date.
        # If the file already exists we simply open it, ensuring this action
        # is idempotent and safe to invoke multiple times a day.
        daily_dir="$VAULT_DIR/daily"
        mkdir -p "$daily_dir"
        today=$(date +%Y-%m-%d)
        daily_file="$daily_dir/$today.md"

        # Only write the template if the file does not yet exist.
        # The YAML frontmatter includes date, type, and tags to maintain
        # consistency with the vault's metadata conventions.
        if [[ ! -f "$daily_file" ]]; then
            cat > "$daily_file" << EOF
---
date: $today
type: daily
tags: [daily]
---

# $today

## Tasks

- [ ]

## Notes

EOF
        fi
        code "$daily_file"
        ;;
    *"Open Vault"*)
        # Open the entire vault directory in VS Code so the user can
        # browse and edit any note with the full editor experience.
        code "$VAULT_DIR"
        ;;
    *"Search Notes"*)
        # Delegate to the dedicated search script, which lists all .md
        # files and lets the user filter/select one to open.
        bash "$SCRIPT_DIR/rofi-obsidian-search.sh"
        ;;
    *"Create New Note"*)
        # Delegate to the creation wizard, which walks the user through
        # choosing a directory and entering a note name.
        bash "$SCRIPT_DIR/rofi-obsidian-create.sh"
        ;;
esac
