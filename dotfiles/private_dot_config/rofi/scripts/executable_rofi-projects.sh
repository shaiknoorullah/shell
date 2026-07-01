#!/usr/bin/env bash
#
# rofi-projects.sh -- Project Launcher
#
# Description:
#   Lists all project directories under ~/work/ in a rofi menu, decorated
#   with Nerd Font icons that indicate the project type (Go, Rust, Node,
#   Python, Java, Ruby, generic Git, or plain folder). After selecting a
#   project, a sub-menu lets the user choose how to open it: VS Code,
#   a terminal, or the system file manager.
#
# Keybinding: $mod+p
#
# Dependencies:
#   - rofi        : menu/prompt interface
#   - find        : discovers project directories
#   - code        : VS Code editor
#   - kitty       : terminal emulator
#   - xdg-open    : opens the default file manager
#   - notify-send : desktop notifications
#
# Usage:
#   ~/.config/rofi/scripts/rofi-projects.sh
#
# Flow:
#   1. Scan ~/work/ for immediate child directories.
#   2. Detect each project's type via marker files and assign an icon.
#   3. User selects a project from the rofi list.
#   4. A second rofi menu presents the action (VS Code / Terminal / File Manager).
#

THEME="$HOME/.config/rofi/themes/simple.rasi"
PROJECTS_DIR="$HOME/work"

# Ensure the projects directory exists (first-run convenience)
if [[ ! -d "$PROJECTS_DIR" ]]; then
    mkdir -p "$PROJECTS_DIR"
fi

# get_project_icon()
#   Determines a Nerd Font icon representing the primary language/framework
#   of a project directory by checking for well-known marker files.
#
#   Parameters:
#     $1 - Absolute path to the project directory
#
#   Output:
#     Prints a single icon character to stdout.
#
#   Detection order matters: a project could contain multiple marker files
#   (e.g., package.json inside a Go monorepo), so the most specific markers
#   are checked first and the generic git/folder fallbacks come last.
get_project_icon() {
    local dir="$1"
    if [[ -f "$dir/go.mod" ]]; then echo "󰟓"                                                    # Go
    elif [[ -f "$dir/Cargo.toml" ]]; then echo ""                                                # Rust
    elif [[ -f "$dir/package.json" ]]; then echo ""                                              # Node.js / JavaScript
    elif [[ -f "$dir/requirements.txt" || -f "$dir/pyproject.toml" || -f "$dir/setup.py" ]]; then echo ""  # Python
    elif [[ -f "$dir/pom.xml" || -f "$dir/build.gradle" ]]; then echo ""                         # Java
    elif [[ -f "$dir/Gemfile" ]]; then echo ""                                                   # Ruby
    elif [[ -d "$dir/.git" ]]; then echo ""                                                      # Generic git repo
    else echo "󰉋"                                                                                # Plain directory
    fi
}

# Build a newline-delimited list of "icon  name" entries for each project.
# find is limited to depth 1 so only top-level directories appear.
projects=""
while IFS= read -r dir; do
    [[ ! -d "$dir" ]] && continue
    name=$(basename "$dir")
    icon=$(get_project_icon "$dir")
    projects+="$icon  $name\n"
done < <(find "$PROJECTS_DIR" -maxdepth 1 -mindepth 1 -type d | sort)

if [[ -z "$projects" ]]; then
    notify-send "Projects" "No projects found in $PROJECTS_DIR" -u normal
    exit 0
fi

# Display the project list in rofi
chosen=$(echo -e "$projects" | rofi -dmenu -theme "$THEME" -p "Projects" -mesg "~/work/")

[[ -z "$chosen" ]] && exit 0

# Extract the project name by stripping the leading icon and whitespace.
# The icon is a single (possibly multi-byte) non-space token followed by spaces.
project_name=$(echo "$chosen" | sed 's/^[^ ]* *//')
project_path="$PROJECTS_DIR/$project_name"

# Sub-menu: choose which application to open the project with
action=$(echo -e "  Open in VS Code\n  Open Terminal\n"󰉋"  Open File Manager" | \
    rofi -dmenu -theme "$THEME" -p "Action" -mesg "$project_name")

# Dispatch the chosen action. Terminal and file manager are backgrounded
# so this script exits immediately and does not block the window manager.
case "$action" in
    *"VS Code"*)       code "$project_path" ;;
    *"Terminal"*)       kitty --directory "$project_path" & ;;
    *"File Manager"*)   xdg-open "$project_path" & ;;
esac
