#!/usr/bin/env bash
# adhd-salah-schedule.sh — schedule today's 5 salah nudges as transient user timers at each
# iqamah time. Re-run daily (times change). Skips prayer times already past for today.
set -uo pipefail
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
CONF="$HOME/.config/adhd/prayer-times.conf"
[ -f "$CONF" ] || exit 0
now="$(date +%H%M)"
while read -r name t _rest; do
    case "$name" in ''|'#'*) continue ;; esac
    [ -z "${t:-}" ] && continue
    hhmm="${t/:/}"
    [ "$hhmm" -le "$now" ] 2>/dev/null && continue   # already passed today
    systemd-run --user --quiet \
        --on-calendar="*-*-* ${t}:00" \
        --timer-property=AccuracySec=30s \
        --unit="adhd-salah-nudge-${name}" \
        "$HOME/.local/bin/adhd-salah-nudge.sh" "$name" 2>/dev/null || true
done < "$CONF"
echo "salah nudges scheduled"
