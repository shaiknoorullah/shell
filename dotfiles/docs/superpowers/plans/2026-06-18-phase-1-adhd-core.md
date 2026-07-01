# Phase 1 — ADHD Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: implement task-by-task. Steps use checkbox (`- [ ]`) syntax. **Execution: Workflow/subagent-team driven** (operator directive 2026-06-18) — subagents author into the chezmoi source; the main loop gates `chezmoi apply` to live.

**Goal:** A friction-≤2-step capture path + a task/time engine that makes starting cheap and the day observable — taskwarrior + timewarrior + Flowtime deep-focus (prayer-scaffolded, no pomodoro) + frictionless capture into the Obsidian vault.

**Architecture:** taskwarrior holds tasks (contexts = projects, a curated `+today` list); timewarrior holds time intervals (auto-started by a taskwarrior hook); small bash scripts in `~/.local/bin` provide capture, focus, and the start-ritual; everything authored in the chezmoi source (`dot_*`) and deployed by a gated `chezmoi apply`. New bats tests cover the scripts with mocked `task`/`timew`/`curl`.

**Tech Stack:** taskwarrior, timewarrior, bash, Obsidian Local REST API (`https://127.0.0.1:27124`), rofi (capture input for now), dunst (`notify-send`/`dunstify`), bats (tests), chezmoi (deploy).

## Global Constraints

- **Friction ≤ 2 actions** per capture/log (manifesto: `CLAUDE.md:27`) — a hard acceptance criterion on every UI step.
- **No pomodoro.** Focus = **Flowtime** (count-up, overtime never force-stops) scaffolded by **salah**; gentle dismissible nudge only past ~90 min.
- **Shame-free.** No "broken streak" / red punishment anywhere (RSD).
- **Contexts:** `work · lab · agents · personal`. taskwarrior projects namespaced `work.*` etc. Current context read from `~/.cache/ctx` (default `personal`).
- **Capture target:** today's daily note `journal/daily/DD-MM-YYYY.md` under an `## Inbox` heading, via Obsidian REST (`$OBSIDIAN_REST_TOKEN` from `~/.secrets`).
- **Authored in chezmoi source** (`dot_*` naming, `executable_` for scripts); deployed only via a reviewed `chezmoi apply`. Never write live config directly.
- **Palette/theme** for any rofi prompt: reuse the live theme; do not introduce new colors.
- Commit after each task. Work on a branch off `main`.

---

### Task 1: taskwarrior config (contexts + curated Today)

**Files:**
- Create: `dot_taskrc` (→ `~/.taskrc`)

- [ ] **Step 1: Write `dot_taskrc`**

```ini
# ~/.taskrc — managed by chezmoi
data.location=~/.task
news.version=2.6.0

# UDAs
uda.estimate.type=duration
uda.estimate.label=Est

# Contexts (work/lab/agents/personal) — read filters
context.work.read=project ~ work
context.lab.read=project ~ lab
context.agents.read=project ~ agents
context.personal.read=project ~ personal

# ADHD: a small curated Today list via the +today tag; near-term urgency boosts
urgency.user.tag.today.coefficient=15.0
urgency.user.tag.next.coefficient=8.0
urgency.due.coefficient=12.0
# never shame: no overdue color screaming
color.overdue=
report.today.description=Today
report.today.columns=id,project,description,estimate
report.today.filter=+today status:pending
report.today.sort=urgency-
```

- [ ] **Step 2: Deploy + verify (chezmoi)**

Run (main loop, gated):
```bash
chezmoi add ~/.taskrc 2>/dev/null; chezmoi apply
task add project:work.ats "boolgen otel" +today
task context work; task today
```
Expected: the task appears under the `Today` report when context is `work`.

- [ ] **Step 3: Commit**

```bash
git add dot_taskrc && git commit -m "feat(task): taskwarrior config — contexts + curated +today"
```

---

### Task 2: timewarrior + taskwarrior on-modify hook (auto time-tracking)

**Files:**
- Create: `dot_config/timewarrior/timewarrior.cfg`
- Create: `dot_config/task/hooks/executable_on-modify.timewarrior`

**Interfaces:**
- Produces: starting a task (`task start <id>`) creates a running timew interval tagged with the task's project + context; stopping/done stops it.

- [ ] **Step 1: Write the hook** (`dot_config/task/hooks/executable_on-modify.timewarrior`)

```bash
#!/usr/bin/env bash
# Bridge taskwarrior start/stop → timewarrior intervals, tagged by project.
read -r old; read -r new
get(){ printf '%s' "$1" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('$2',''))"; }
o_start=$(get "$old" start); n_start=$(get "$new" start)
proj=$(get "$new" project); desc=$(get "$new" description)
if [ -z "$o_start" ] && [ -n "$n_start" ]; then timew start "$proj" "$desc" :quiet 2>/dev/null; fi
if [ -n "$o_start" ] && [ -z "$n_start" ]; then timew stop :quiet 2>/dev/null; fi
printf '%s\n' "$new"
```

- [ ] **Step 2: Write `dot_config/timewarrior/timewarrior.cfg`**

```ini
# managed by chezmoi
define exclusions =
```

- [ ] **Step 3: Deploy + verify**

```bash
chezmoi apply
ID=$(task +today ids | head -1); task start "$ID"; timew | head -3; task stop "$ID"
```
Expected: `timew` shows a running interval tagged with the task project after `start`; stopped after `stop`.

- [ ] **Step 4: Commit**

```bash
git add dot_config/timewarrior dot_config/task && git commit -m "feat(time): timewarrior + on-modify hook (auto-track on task start)"
```

---

### Task 3: Capture (≤2-step → vault inbox + optional task)

**Files:**
- Create: `dot_local/bin/executable_adhd-capture.sh` (→ `~/.local/bin/adhd-capture.sh`)
- Create: `tests/test_capture.bats`, `tests/test_helper/mocks/{rofi,curl,task}` (reuse if present)
- Modify: `dot_config/i3/config.tmpl` (add `bindsym $mod+Shift+space`)

**Interfaces:**
- Produces: `adhd-capture.sh` — pops a one-line rofi input; POSTs the text to today's daily-note `## Inbox` via Obsidian REST; if text starts `t:`/`task:`, also `task add project:<ctx>`.

- [ ] **Step 1: Write the failing test** (`tests/test_capture.bats`)

```bash
@test "capture: posts typed text to Obsidian REST inbox" {
  set_rofi_outputs "ship the otel patch"
  run bash "$(get_script ../dot_config/../dot_local/bin/executable_adhd-capture.sh)"
  assert_mock_called_with "curl" "27124"
}
@test "capture: t: prefix also adds a task" {
  set_rofi_outputs "t: review FR-006 PR"
  run bash "$(get_script ... )"
  assert_mock_called_with "task" "add"
}
```

- [ ] **Step 2: Run, verify it fails** — `bats tests/test_capture.bats` → FAIL (script missing).

- [ ] **Step 3: Write `executable_adhd-capture.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
CTX=$(cat "$HOME/.cache/ctx" 2>/dev/null || echo personal)
text=$(printf '' | rofi -dmenu -p "Capture" -theme "$HOME/.config/rofi/themes/simple.rasi" 2>/dev/null) || exit 0
[ -z "$text" ] && exit 0
note="journal/daily/$(date +%d-%m-%Y).md"
body="- $(date +%H:%M) $text"
curl -sk -X POST "https://127.0.0.1:27124/vault/$note" \
  -H "Authorization: Bearer ${OBSIDIAN_REST_TOKEN:-}" \
  -H "Content-Type: text/markdown" -H "Heading: Inbox" --data "$body" >/dev/null || true
case "$text" in
  t:*|task:*) task add project:"$CTX" "${text#*:}" +next >/dev/null 2>&1 ;;
esac
notify-send "Captured" "$text" 2>/dev/null || true
```

- [ ] **Step 4: Run tests, verify pass** — `bats tests/test_capture.bats` → PASS.

- [ ] **Step 5: Add the i3 binding** — in `dot_config/i3/config.tmpl`, add:
  `bindsym $mod+Shift+space exec --no-startup-id ~/.local/bin/adhd-capture.sh`

- [ ] **Step 6: Deploy + manual smoke + commit**

```bash
chezmoi apply
git add dot_local/bin tests/test_capture.bats dot_config/i3/config.tmpl && git commit -m "feat(capture): keybind → vault inbox + optional task (<=2 steps)"
```

---

### Task 4: Flowtime deep-focus daemon (prayer-scaffolded)

**Files:**
- Create: `dot_config/adhd/prayer-times.conf` (→ `~/.config/adhd/prayer-times.conf` — operator-editable HH:MM list to start; auto-calc deferred)
- Create: `dot_local/bin/executable_adhd-focus.sh`
- Create: `tests/test_focus.bats`
- Modify: `dot_config/i3/config.tmpl` (`bindsym $mod+Shift+f` repurposed? use `$mod+Shift+x`)

**Interfaces:**
- Produces: `adhd-focus.sh start <taskid>` → starts a count-up timew interval (via `task start`); writes `~/.cache/focus` (start epoch + taskid); a watcher fires a **dismissible** `notify-send` if elapsed > 90 min; `adhd-focus.sh status` prints elapsed + minutes to next salah from `prayer-times.conf`.

- [ ] **Step 1: Write the failing test** (`tests/test_focus.bats`)

```bash
@test "focus: start begins a timew interval for the task" {
  run bash "$(get_script ...adhd-focus.sh)" start 1
  assert_mock_called_with "task" "start"
}
@test "focus: status reports minutes to next prayer" {
  printf 'Asr 16:42\nMaghrib 19:05\n' > "$HOME/.config/adhd/prayer-times.conf"
  run bash "$(get_script ...adhd-focus.sh)" status
  assert_output --partial "→"
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Write `executable_adhd-focus.sh`** (count-up, no fixed box; nudge ≥90m; next-prayer from config)

```bash
#!/usr/bin/env bash
set -euo pipefail
CONF="$HOME/.config/adhd/prayer-times.conf"; STATE="$HOME/.cache/focus"
next_prayer(){ now=$(date +%H%M); while read -r n t; do [ "${t/:/}" -gt "$now" ] && { echo "$n $t"; return; }; done < "$CONF"; echo "Fajr (tmrw)"; }
case "${1:-status}" in
  start) task start "${2:?taskid}" >/dev/null 2>&1; printf '%s %s\n' "$(date +%s)" "${2}" > "$STATE";
         notify-send "Deep block started" "→ $(next_prayer)" 2>/dev/null || true;;
  stop)  task stop "$(awk '{print $2}' "$STATE" 2>/dev/null)" >/dev/null 2>&1 || true; rm -f "$STATE";;
  status) [ -f "$STATE" ] && { s=$(awk '{print $1}' "$STATE"); printf 'block %dm · → %s\n' $(( ($(date +%s)-s)/60 )) "$(next_prayer)"; } || echo "idle";;
  nudge) [ -f "$STATE" ] && { s=$(awk '{print $1}' "$STATE"); [ $(( ($(date +%s)-s)/60 )) -ge 90 ] && notify-send "Long block — breathe?" "Dismiss to keep going · next: $(next_prayer)" 2>/dev/null; };;
esac
```

- [ ] **Step 4: Run tests, verify pass.**

- [ ] **Step 5: i3 binding + a periodic nudge** — add `bindsym $mod+Shift+x exec --no-startup-id ~/.local/bin/adhd-focus.sh status` and (autostart) a loop or `exec_always` that calls `adhd-focus.sh nudge` every few minutes (a tiny `executable_adhd-nudge-loop.sh` or systemd-user timer).

- [ ] **Step 6: Deploy + commit**

```bash
chezmoi apply
git add dot_config/adhd dot_local/bin tests/test_focus.bats dot_config/i3/config.tmpl && git commit -m "feat(focus): Flowtime deep-focus daemon, prayer-scaffolded, gentle 90m nudge"
```

---

### Task 5: Start ritual (one command: pick → start → land in context)

**Files:**
- Create: `dot_local/bin/executable_adhd-start.sh`
- Create: `tests/test_start.bats`
- Modify: `dot_config/i3/config.tmpl` (`bindsym $mod+Shift+Return`)

**Interfaces:**
- Consumes: `adhd-focus.sh` (Task 4), taskwarrior `+next` list.
- Produces: `adhd-start.sh` — rofi-pick a `+today`/`+next` task → `adhd-focus.sh start <id>` → switch tmux to the task's context session (best-effort).

- [ ] **Step 1: Write the failing test** (`tests/test_start.bats`)

```bash
@test "start: selecting a task starts a focus block" {
  set_rofi_outputs "1 boolgen otel"
  run bash "$(get_script ...adhd-start.sh)"
  assert_mock_called_with "task" "start"
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Write `executable_adhd-start.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
CTX=$(cat "$HOME/.cache/ctx" 2>/dev/null || echo personal)
line=$(task +today status:pending export 2>/dev/null | python3 -c "import json,sys;[print(t['id'],t.get('description','')) for t in json.load(sys.stdin)]" | rofi -dmenu -p "Start" -theme "$HOME/.config/rofi/themes/simple.rasi") || exit 0
[ -z "$line" ] && exit 0
id=${line%% *}
~/.local/bin/adhd-focus.sh start "$id"
tmux has-session -t "$CTX" 2>/dev/null && tmux switch-client -t "$CTX" 2>/dev/null || true
```

- [ ] **Step 4: Run tests, verify pass.**

- [ ] **Step 5: i3 binding** — `bindsym $mod+Shift+Return exec --no-startup-id ~/.local/bin/adhd-start.sh`

- [ ] **Step 6: Deploy + commit**

```bash
chezmoi apply
git add dot_local/bin tests/test_start.bats dot_config/i3/config.tmpl && git commit -m "feat(start): one-command start ritual (pick → focus → context)"
```

---

## Self-Review

- **Spec coverage:** §9.1 taskwarrior → T1; §9.2 timew+hook → T2; §9.3 capture → T3; §1.4/§14.1 Flowtime/prayer → T4; §1.5 start ritual → T5. §14.2 idle-catch + §14.5 trackers deferred to Phase 1.5 (noted). All core §9 items covered.
- **Friction rule:** capture (T3) and start (T5) are each a single keybind → one rofi line → done (≤2 actions). ✓
- **No pomodoro:** T4 is count-up Flowtime, dismissible nudge only. ✓
- **Live-write discipline:** every task authors `dot_*` source; deploy is a gated `chezmoi apply`. ✓
- **Dependencies:** T3/T4/T5 depend on T1/T2 (taskwarrior/timew). T5 depends on T4. The workflow must run T1→T2 before T3/T4 (parallel), then T5 after T4.
- **Known external dep:** Obsidian REST must be running (`:27124`) for T3 live smoke; prayer times start as an operator-edited config (auto-calc deferred).

## Deferred to Phase 1.5

- Idle-catch (`xprintidle` → assign-time popup) — §14.2.
- Tracker quick-log (salah/coffee/walk → daily-note frontmatter) — §14.5.
