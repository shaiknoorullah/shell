#!/usr/bin/env bash
# zen-tab-popup.sh — Launch tab switcher as floating popup
# Modes:
#   Default (from i3): floating kitty window
#   --tmux: tmux display-popup

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SWITCHER="$SCRIPT_DIR/zen-tab-switcher.sh"

case "${1:-}" in
    --tmux)
        tmux display-popup -w 85% -h 75% -E "$SWITCHER"
        ;;
    *)
        kitty --class zen-tab-switcher \
              --override font_size=10 \
              --override background_opacity=0.92 \
              --override remember_window_size=no \
              --override initial_window_width=140c \
              --override initial_window_height=35c \
              -e "$SWITCHER"
        ;;
esac
