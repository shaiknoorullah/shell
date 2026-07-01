# Rofi Mega-Setup Test Suite — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Comprehensive BATS unit tests for all 17 rofi scripts + 4 API scripts + i3 keybinding validation, using mocked external commands.

**Architecture:** Every external command (rofi, systemctl, playerctl, bluetoothctl, etc.) is replaced by a mock that logs its invocation and returns canned output. Tests assert both that the correct commands were called with the correct arguments AND that the script's internal logic (option generation, parsing, branching) is correct.

**Tech Stack:** BATS (Bash Automated Testing System), bats-support, bats-assert, bash mocks via PATH injection.

---

## Task 1: Install BATS and Create Directory Structure

**Files:**
- Create: `~/.config/rofi/tests/` (directory tree)

**Step 1: Install BATS and helpers**

```bash
# Install bats and helper libraries
sudo apt install -y bats
mkdir -p ~/.config/rofi/tests/test_helper/bats-support
mkdir -p ~/.config/rofi/tests/test_helper/bats-assert
git clone --depth 1 https://github.com/bats-core/bats-support.git ~/.config/rofi/tests/test_helper/bats-support
git clone --depth 1 https://github.com/bats-core/bats-assert.git ~/.config/rofi/tests/test_helper/bats-assert
```

**Step 2: Create directory structure**

```bash
mkdir -p ~/.config/rofi/tests/{test_helper/mocks,test_helper/mock_responses}
```

**Step 3: Verify BATS works**

Run: `bats --version`
Expected: `Bats 1.x.x`

---

## Task 2: Create Common Test Helper

**Files:**
- Create: `~/.config/rofi/tests/test_helper/common.bash`

**Step 1: Write the shared test setup**

```bash
#!/usr/bin/env bash
# common.bash — Shared test infrastructure for all rofi script tests.
#
# Provides:
#   - BATS helper loading (bats-support, bats-assert)
#   - Mock infrastructure (PATH injection, logging, response control)
#   - Temp directory management with automatic cleanup
#   - Helper functions for asserting mock invocations

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$(cd "$TESTS_DIR/../scripts" && pwd)"
MOCKS_DIR="$TESTS_DIR/test_helper/mocks"
MOCK_RESPONSES_DIR="$TESTS_DIR/test_helper/mock_responses"

# Load BATS helpers
load "$TESTS_DIR/test_helper/bats-support/load"
load "$TESTS_DIR/test_helper/bats-assert/load"

# ── Setup / Teardown ──────────────────────────────────────────

# Called before each test. Creates temp dirs, injects mocks into PATH.
common_setup() {
    # Create temp directory for this test
    TEST_TEMP="$(mktemp -d)"
    export TEST_TEMP

    # Mock log — every mock appends its invocation here
    export MOCK_LOG="$TEST_TEMP/mock_calls.log"
    touch "$MOCK_LOG"

    # Rofi mock output — tests set this to simulate user selection
    export ROFI_MOCK_OUTPUT=""

    # Multi-call rofi output — for scripts that invoke rofi multiple times
    # Each line is consumed in order. File is created only when needed.
    export ROFI_MULTI_OUTPUT="$TEST_TEMP/rofi_multi_output"

    # Track which rofi call we're on (for multi-call scripts)
    export ROFI_CALL_COUNT="$TEST_TEMP/rofi_call_count"
    echo "0" > "$ROFI_CALL_COUNT"

    # Override HOME to isolate file operations
    export REAL_HOME="$HOME"
    export HOME="$TEST_TEMP/fakehome"
    mkdir -p "$HOME/.config/rofi/themes" "$HOME/.config/rofi/scripts/apis" "$HOME/.config/i3"

    # Copy theme files so scripts can reference them (they just need to exist)
    touch "$HOME/.config/rofi/themes/power.rasi"
    touch "$HOME/.config/rofi/themes/media.rasi"
    touch "$HOME/.config/rofi/themes/screenshot.rasi"
    touch "$HOME/.config/rofi/themes/keybindings.rasi"
    touch "$HOME/.config/rofi/themes/wallpaper.rasi"
    touch "$HOME/.config/rofi/themes/clipboard.rasi"
    touch "$HOME/.config/rofi/themes/git-profile.rasi"
    touch "$HOME/.config/rofi/themes/tmux.rasi"
    touch "$HOME/.config/rofi/themes/projects.rasi"
    touch "$HOME/.config/rofi/themes/obsidian.rasi"
    touch "$HOME/.config/rofi/themes/obsidian-search.rasi"
    touch "$HOME/.config/rofi/themes/bluetooth.rasi"
    touch "$HOME/.config/rofi/themes/display.rasi"
    touch "$HOME/.config/rofi/themes/systemd.rasi"
    touch "$HOME/.config/rofi/themes/bookmarks.rasi"
    touch "$HOME/.config/rofi/themes/websearch.rasi"
    touch "$HOME/.config/rofi/themes/calculator.rasi"
    touch "$HOME/.config/rofi/themes/emoji.rasi"

    # Inject mocks into PATH (mocks take priority over real commands)
    export PATH="$MOCKS_DIR:$PATH"
}

# Called after each test. Removes temp directory.
common_teardown() {
    rm -rf "$TEST_TEMP"
}

# ── Mock Assertion Helpers ────────────────────────────────────

# assert_mock_called <command> — Asserts that a mock was invoked
assert_mock_called() {
    local cmd="$1"
    grep -q "^$cmd " "$MOCK_LOG" || grep -q "^$cmd$" "$MOCK_LOG" || {
        echo "Expected mock '$cmd' to be called, but it wasn't."
        echo "Mock log contents:"
        cat "$MOCK_LOG"
        return 1
    }
}

# assert_mock_not_called <command> — Asserts that a mock was NOT invoked
assert_mock_not_called() {
    local cmd="$1"
    if grep -q "^$cmd " "$MOCK_LOG" 2>/dev/null || grep -q "^$cmd$" "$MOCK_LOG" 2>/dev/null; then
        echo "Expected mock '$cmd' NOT to be called, but it was."
        echo "Mock log contents:"
        cat "$MOCK_LOG"
        return 1
    fi
}

# assert_mock_called_with <command> <substring> — Asserts mock called with args containing substring
assert_mock_called_with() {
    local cmd="$1"
    local expected="$2"
    grep "^$cmd " "$MOCK_LOG" | grep -q "$expected" || {
        echo "Expected '$cmd' to be called with args containing '$expected'"
        echo "Actual calls:"
        grep "^$cmd " "$MOCK_LOG" || echo "(none)"
        return 1
    }
}

# assert_mock_called_with_exact <full_line> — Asserts exact line exists in mock log
assert_mock_called_with_exact() {
    local expected="$1"
    grep -qF "$expected" "$MOCK_LOG" || {
        echo "Expected exact mock call: $expected"
        echo "Mock log contents:"
        cat "$MOCK_LOG"
        return 1
    }
}

# get_mock_calls <command> — Returns all invocations of a mock
get_mock_calls() {
    local cmd="$1"
    grep "^$cmd " "$MOCK_LOG" || true
}

# set_rofi_outputs <output1> <output2> ... — Sets multi-call rofi responses
set_rofi_outputs() {
    > "$ROFI_MULTI_OUTPUT"
    for output in "$@"; do
        echo "$output" >> "$ROFI_MULTI_OUTPUT"
    done
}

# get_script <name> — Returns the real path to a script (not in fake HOME)
get_script() {
    echo "$SCRIPTS_DIR/$1"
}
```

---

## Task 3: Create Mock Commands

**Files:**
- Create: `~/.config/rofi/tests/test_helper/mocks/rofi`
- Create: `~/.config/rofi/tests/test_helper/mocks/systemctl`
- Create: `~/.config/rofi/tests/test_helper/mocks/i3lock`
- Create: `~/.config/rofi/tests/test_helper/mocks/i3-msg`
- Create: `~/.config/rofi/tests/test_helper/mocks/playerctl`
- Create: `~/.config/rofi/tests/test_helper/mocks/maim`
- Create: `~/.config/rofi/tests/test_helper/mocks/xclip`
- Create: `~/.config/rofi/tests/test_helper/mocks/xdotool`
- Create: `~/.config/rofi/tests/test_helper/mocks/notify-send`
- Create: `~/.config/rofi/tests/test_helper/mocks/feh`
- Create: `~/.config/rofi/tests/test_helper/mocks/greenclip`
- Create: `~/.config/rofi/tests/test_helper/mocks/pgrep`
- Create: `~/.config/rofi/tests/test_helper/mocks/git`
- Create: `~/.config/rofi/tests/test_helper/mocks/tmux`
- Create: `~/.config/rofi/tests/test_helper/mocks/code`
- Create: `~/.config/rofi/tests/test_helper/mocks/kitty`
- Create: `~/.config/rofi/tests/test_helper/mocks/xdg-open`
- Create: `~/.config/rofi/tests/test_helper/mocks/bluetoothctl`
- Create: `~/.config/rofi/tests/test_helper/mocks/xrandr`
- Create: `~/.config/rofi/tests/test_helper/mocks/pkexec`
- Create: `~/.config/rofi/tests/test_helper/mocks/sqlite3`
- Create: `~/.config/rofi/tests/test_helper/mocks/firefox`
- Create: `~/.config/rofi/tests/test_helper/mocks/python3`
- Create: `~/.config/rofi/tests/test_helper/mocks/curl`
- Create: `~/.config/rofi/tests/test_helper/mocks/jq`
- Create: `~/.config/rofi/tests/test_helper/mocks/journalctl`
- Create: `~/.config/rofi/tests/test_helper/mocks/find`
- Create: `~/.config/rofi/tests/test_helper/mocks/sleep`

**Step 1: Create the rofi mock (most complex — handles multi-call)**

```bash
#!/usr/bin/env bash
# Mock: rofi
# Logs invocation, returns canned output.
# Supports multi-call via ROFI_MULTI_OUTPUT file.
echo "rofi $*" >> "$MOCK_LOG"

if [[ -f "$ROFI_MULTI_OUTPUT" ]] && [[ -s "$ROFI_MULTI_OUTPUT" ]]; then
    # Multi-call mode: read next line from file
    count=$(cat "$ROFI_CALL_COUNT")
    count=$((count + 1))
    echo "$count" > "$ROFI_CALL_COUNT"
    output=$(sed -n "${count}p" "$ROFI_MULTI_OUTPUT")
    echo "$output"
else
    # Single-call mode: return ROFI_MOCK_OUTPUT
    echo "${ROFI_MOCK_OUTPUT:-}"
fi
```

**Step 2: Create simple logging mocks (all follow same pattern)**

Each mock below logs its call and optionally returns canned output from an env var.

```bash
# Template for simple mocks — replace COMMAND_NAME:
#!/usr/bin/env bash
echo "COMMAND_NAME $*" >> "$MOCK_LOG"
```

Create these mocks using the template (just logging, no output needed):
- `systemctl`, `i3lock`, `i3-msg`, `notify-send`, `feh`, `code`, `kitty`,
  `xdg-open`, `firefox`, `pkexec`, `journalctl`, `sleep`

**Step 3: Create mocks that return output**

`playerctl`:
```bash
#!/usr/bin/env bash
echo "playerctl $*" >> "$MOCK_LOG"
case "$1" in
    metadata)
        case "$2" in
            artist) echo "${PLAYERCTL_ARTIST:-Test Artist}" ;;
            title)  echo "${PLAYERCTL_TITLE:-Test Song}" ;;
        esac
        ;;
    *) ;;
esac
```

`maim`:
```bash
#!/usr/bin/env bash
echo "maim $*" >> "$MOCK_LOG"
# Create a fake screenshot file at the path argument
for arg in "$@"; do
    # The last non-flag argument is the output path
    if [[ "$arg" != -* ]]; then
        MAIM_OUTPUT="$arg"
    fi
done
if [[ -n "${MAIM_OUTPUT:-}" ]]; then
    echo "fake_png_data" > "$MAIM_OUTPUT"
fi
```

`xclip`:
```bash
#!/usr/bin/env bash
echo "xclip $*" >> "$MOCK_LOG"
# Consume stdin (scripts pipe to xclip)
cat > /dev/null
```

`xdotool`:
```bash
#!/usr/bin/env bash
echo "xdotool $*" >> "$MOCK_LOG"
echo "12345"  # Fake window ID
```

`greenclip`:
```bash
#!/usr/bin/env bash
echo "greenclip $*" >> "$MOCK_LOG"
if [[ "$1" == "daemon" ]]; then
    : # Do nothing, just pretend to start
fi
```

`pgrep`:
```bash
#!/usr/bin/env bash
echo "pgrep $*" >> "$MOCK_LOG"
# Return success/failure based on PGREP_FOUND
if [[ "${PGREP_FOUND:-}" == "true" ]]; then
    echo "12345"
    exit 0
else
    exit 1
fi
```

`git`:
```bash
#!/usr/bin/env bash
echo "git $*" >> "$MOCK_LOG"
```

`tmux`:
```bash
#!/usr/bin/env bash
echo "tmux $*" >> "$MOCK_LOG"
case "$1" in
    list-sessions)
        echo "${TMUX_SESSIONS:-}" | grep -v '^$' || exit 1
        ;;
    *) ;;
esac
```

`bluetoothctl`:
```bash
#!/usr/bin/env bash
echo "bluetoothctl $*" >> "$MOCK_LOG"
case "$1" in
    show)
        echo "Powered: ${BT_POWERED:-yes}"
        ;;
    devices)
        if [[ "$2" == "Paired" ]]; then
            echo "${BT_PAIRED_DEVICES:-}" | grep -v '^$' || true
        else
            echo "${BT_ALL_DEVICES:-}" | grep -v '^$' || true
        fi
        ;;
    info)
        echo "Connected: ${BT_CONNECTED:-no}"
        ;;
    *)
        ;;
esac
```

`xrandr`:
```bash
#!/usr/bin/env bash
echo "xrandr $*" >> "$MOCK_LOG"
if [[ "$1" == "--query" ]]; then
    echo "${XRANDR_OUTPUT:-eDP-1 connected primary 1920x1080+0+0}"
fi
```

`sqlite3`:
```bash
#!/usr/bin/env bash
echo "sqlite3 $*" >> "$MOCK_LOG"
echo "${SQLITE3_OUTPUT:-}"
```

`python3`:
```bash
#!/usr/bin/env bash
echo "python3 $*" >> "$MOCK_LOG"
# Actually run python3 for URL encoding (tests need real output)
"$(which -a python3 | grep -v "$MOCKS_DIR" | head -1)" "$@"
```

`curl`:
```bash
#!/usr/bin/env bash
echo "curl $*" >> "$MOCK_LOG"
echo "${CURL_OUTPUT:-[]}"
```

`jq`:
```bash
#!/usr/bin/env bash
echo "jq $*" >> "$MOCK_LOG"
# Actually run jq for JSON parsing (tests need real output)
"$(which -a jq | grep -v "$MOCKS_DIR" | head -1)" "$@"
```

`find`:
```bash
#!/usr/bin/env bash
echo "find $*" >> "$MOCK_LOG"
# Use real find if FIND_USE_REAL is set, otherwise return FIND_OUTPUT
if [[ "${FIND_USE_REAL:-}" == "true" ]]; then
    "$(which -a find | grep -v "$MOCKS_DIR" | head -1)" "$@"
else
    echo "${FIND_OUTPUT:-}" | grep -v '^$' || true
fi
```

**Step 4: Make all mocks executable**

```bash
chmod +x ~/.config/rofi/tests/test_helper/mocks/*
```

**Step 5: Verify mock infrastructure**

Create a quick smoke test: `~/.config/rofi/tests/test_smoke.bats`

```bash
#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

@test "mock rofi returns ROFI_MOCK_OUTPUT" {
    ROFI_MOCK_OUTPUT="test selection"
    result=$(rofi -dmenu)
    assert_equal "$result" "test selection"
}

@test "mock rofi logs invocation" {
    rofi -dmenu -theme foo.rasi -p "Test"
    assert_mock_called "rofi"
    assert_mock_called_with "rofi" "-theme foo.rasi"
}

@test "multi-call rofi returns sequential outputs" {
    set_rofi_outputs "first" "second" "third"
    r1=$(rofi -dmenu)
    r2=$(rofi -dmenu)
    r3=$(rofi -dmenu)
    assert_equal "$r1" "first"
    assert_equal "$r2" "second"
    assert_equal "$r3" "third"
}

@test "mock systemctl logs invocation" {
    systemctl poweroff
    assert_mock_called_with "systemctl" "poweroff"
}

@test "mock pgrep returns based on PGREP_FOUND" {
    PGREP_FOUND=true
    run pgrep -x greenclip
    assert_success

    PGREP_FOUND=false
    run pgrep -x greenclip
    assert_failure
}
```

Run: `cd ~/.config/rofi/tests && bats test_smoke.bats`
Expected: All 5 tests pass.

---

## Task 4: Test Power Menu

**Files:**
- Create: `~/.config/rofi/tests/test_power.bats`

```bash
#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

# ── Option Generation ─────────────────────────────────────────

@test "power: presents 5 options to rofi" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-power.sh)"
    # Rofi should be called with 5 newline-separated icons
    assert_mock_called "rofi"
}

# ── Shutdown (with confirmation) ──────────────────────────────

@test "power: shutdown confirmed triggers systemctl poweroff" {
    set_rofi_outputs "⏻" "Yes"
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "systemctl" "poweroff"
}

@test "power: shutdown denied does not trigger poweroff" {
    set_rofi_outputs "⏻" "No"
    run bash "$(get_script rofi-power.sh)"
    assert_mock_not_called "systemctl"
}

# ── Reboot (with confirmation) ────────────────────────────────

@test "power: reboot confirmed triggers systemctl reboot" {
    set_rofi_outputs "" "Yes"
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "systemctl" "reboot"
}

@test "power: reboot denied does not trigger reboot" {
    set_rofi_outputs "" "No"
    run bash "$(get_script rofi-power.sh)"
    assert_mock_not_called "systemctl"
}

# ── Lock (no confirmation) ────────────────────────────────────

@test "power: lock triggers i3lock immediately (no confirm)" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "i3lock" "-c 1E1E2E"
}

# ── Suspend (no confirmation) ─────────────────────────────────

@test "power: suspend triggers systemctl suspend" {
    ROFI_MOCK_OUTPUT="⏾"
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "systemctl" "suspend"
}

# ── Logout (with confirmation) ────────────────────────────────

@test "power: logout confirmed triggers i3-msg exit" {
    set_rofi_outputs "󰍃" "Yes"
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "i3-msg" "exit"
}

# ── Cancel (empty selection) ──────────────────────────────────

@test "power: empty selection does nothing" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-power.sh)"
    assert_mock_not_called "systemctl"
    assert_mock_not_called "i3lock"
    assert_mock_not_called "i3-msg"
}

# ── Rofi invocation correctness ───────────────────────────────

@test "power: rofi called with correct theme" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "rofi" "power.rasi"
}

@test "power: rofi called with dmenu mode" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "rofi" "-dmenu"
}

@test "power: rofi called with Power Menu message" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-power.sh)"
    assert_mock_called_with "rofi" "Power Menu"
}
```

Run: `cd ~/.config/rofi/tests && bats test_power.bats`
Expected: All tests pass.

---

## Task 5: Test Media Controls

**Files:**
- Create: `~/.config/rofi/tests/test_media.bats`

```bash
#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

@test "media: previous triggers playerctl previous" {
    ROFI_MOCK_OUTPUT="󰒮"
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "playerctl" "previous"
}

@test "media: play/pause triggers playerctl play-pause" {
    ROFI_MOCK_OUTPUT="󰐎"
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "playerctl" "play-pause"
}

@test "media: next triggers playerctl next" {
    ROFI_MOCK_OUTPUT="󰒭"
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "playerctl" "next"
}

@test "media: shuffle triggers playerctl shuffle toggle" {
    ROFI_MOCK_OUTPUT="󰒟"
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "playerctl" "shuffle toggle"
}

@test "media: loop triggers playerctl loop" {
    ROFI_MOCK_OUTPUT="󰑖"
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "playerctl" "loop"
}

@test "media: track info passed as rofi message" {
    PLAYERCTL_ARTIST="Pink Floyd"
    PLAYERCTL_TITLE="Comfortably Numb"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "rofi" "Pink Floyd - Comfortably Numb"
}

@test "media: rofi called with media theme" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-media.sh)"
    assert_mock_called_with "rofi" "media.rasi"
}

@test "media: empty selection does nothing" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-media.sh)"
    # playerctl is called for metadata but not for any action
    local action_calls
    action_calls=$(grep "^playerctl " "$MOCK_LOG" | grep -v "metadata" | wc -l)
    assert_equal "$action_calls" "0"
}
```

Run: `cd ~/.config/rofi/tests && bats test_media.bats`
Expected: All tests pass.

---

## Task 6: Test Screenshot

**Files:**
- Create: `~/.config/rofi/tests/test_screenshot.bats`

```bash
#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
    mkdir -p "$HOME/Pictures/Screenshots"
}

teardown() {
    common_teardown
}

@test "screenshot: fullscreen calls maim with output path" {
    ROFI_MOCK_OUTPUT="󰍹"
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called "maim"
    # Should NOT have -s flag (that's area mode)
    local maim_call
    maim_call=$(grep "^maim " "$MOCK_LOG" | head -1)
    refute [[ "$maim_call" == *"-s"* ]]
}

@test "screenshot: area calls maim with -s flag" {
    ROFI_MOCK_OUTPUT="󰩭"
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called_with "maim" "-s"
}

@test "screenshot: window calls maim with -i flag" {
    ROFI_MOCK_OUTPUT="󰖯"
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called_with "maim" "-i"
    assert_mock_called "xdotool"
}

@test "screenshot: file saved to Screenshots directory" {
    ROFI_MOCK_OUTPUT="󰩭"
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called_with "maim" "Pictures/Screenshots/screenshot-"
}

@test "screenshot: clipboard populated via xclip" {
    ROFI_MOCK_OUTPUT="󰩭"
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called_with "xclip" "-selection clipboard"
    assert_mock_called_with "xclip" "image/png"
}

@test "screenshot: notification sent on success" {
    ROFI_MOCK_OUTPUT="󰩭"
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called_with "notify-send" "Screenshot Saved"
}

@test "screenshot: rofi called with screenshot theme" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_called_with "rofi" "screenshot.rasi"
}

@test "screenshot: empty selection does nothing" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-screenshot.sh)"
    assert_mock_not_called "maim"
    assert_mock_not_called "xclip"
}
```

Run: `cd ~/.config/rofi/tests && bats test_screenshot.bats`
Expected: All tests pass.

---

## Task 7: Test Keybindings Viewer, Wallpaper, Clipboard

**Files:**
- Create: `~/.config/rofi/tests/test_keybindings_viewer.bats`
- Create: `~/.config/rofi/tests/test_wallpaper.bats`
- Create: `~/.config/rofi/tests/test_clipboard.bats`

**Step 1: Keybindings viewer tests**

```bash
#!/usr/bin/env bats
# test_keybindings_viewer.bats

setup() {
    load 'test_helper/common'
    common_setup
    # Create a fake i3 config with known bindings
    cat > "$HOME/.config/i3/config" << 'EOF'
bindsym $mod+Return exec kitty
bindsym $mod+d exec --no-startup-id rofi -show drun
bindsym $mod+Shift+q kill
EOF
}

teardown() {
    common_teardown
}

@test "keybindings: parses bindsym lines from i3 config" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-keybindings.sh)"
    assert_mock_called "rofi"
}

@test "keybindings: rofi called with markup-rows" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-keybindings.sh)"
    assert_mock_called_with "rofi" "-markup-rows"
}

@test "keybindings: rofi called with keybindings theme" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-keybindings.sh)"
    assert_mock_called_with "rofi" "keybindings.rasi"
}

@test "keybindings: exits with error if no i3 config" {
    rm "$HOME/.config/i3/config"
    run bash "$(get_script rofi-keybindings.sh)"
    assert_mock_called_with "notify-send" "Error"
}
```

**Step 2: Wallpaper tests**

```bash
#!/usr/bin/env bats
# test_wallpaper.bats

setup() {
    load 'test_helper/common'
    common_setup
    FIND_USE_REAL=true
    export FIND_USE_REAL
    mkdir -p "$HOME/Pictures/Wallpapers"
}

teardown() {
    common_teardown
}

@test "wallpaper: feh called with --bg-fill on selection" {
    touch "$HOME/Pictures/Wallpapers/mountain.jpg"
    ROFI_MOCK_OUTPUT="mountain.jpg"
    run bash "$(get_script rofi-wallpaper.sh)"
    assert_mock_called_with "feh" "--bg-fill"
    assert_mock_called_with "feh" "mountain.jpg"
}

@test "wallpaper: notification sent on set" {
    touch "$HOME/Pictures/Wallpapers/sunset.png"
    ROFI_MOCK_OUTPUT="sunset.png"
    run bash "$(get_script rofi-wallpaper.sh)"
    assert_mock_called_with "notify-send" "Wallpaper Set"
}

@test "wallpaper: empty selection does nothing" {
    touch "$HOME/Pictures/Wallpapers/test.jpg"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-wallpaper.sh)"
    assert_mock_not_called "feh"
}

@test "wallpaper: handles empty directory" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-wallpaper.sh)"
    assert_mock_called_with "notify-send" "No images found"
}

@test "wallpaper: rofi called with wallpaper theme" {
    touch "$HOME/Pictures/Wallpapers/test.jpg"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-wallpaper.sh)"
    assert_mock_called_with "rofi" "wallpaper.rasi"
}
```

**Step 3: Clipboard tests**

```bash
#!/usr/bin/env bats
# test_clipboard.bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

@test "clipboard: starts greenclip daemon if not running" {
    PGREP_FOUND=false
    run bash "$(get_script rofi-clipboard.sh)"
    assert_mock_called_with "greenclip" "daemon"
}

@test "clipboard: skips daemon start if already running" {
    PGREP_FOUND=true
    run bash "$(get_script rofi-clipboard.sh)"
    assert_mock_not_called "greenclip"
}

@test "clipboard: rofi called with greenclip modi" {
    PGREP_FOUND=true
    run bash "$(get_script rofi-clipboard.sh)"
    assert_mock_called_with "rofi" "clipboard:greenclip print"
}

@test "clipboard: rofi called with clipboard theme" {
    PGREP_FOUND=true
    run bash "$(get_script rofi-clipboard.sh)"
    assert_mock_called_with "rofi" "clipboard.rasi"
}
```

Run: `cd ~/.config/rofi/tests && bats test_keybindings_viewer.bats test_wallpaper.bats test_clipboard.bats`
Expected: All tests pass.

---

## Task 8: Test Git Profile

**Files:**
- Create: `~/.config/rofi/tests/test_git_profile.bats`

```bash
#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
    # Create a test profiles config
    cat > "$HOME/.config/rofi/scripts/git-profiles.conf" << 'EOF'
# Test profiles
Work|John Doe|john@company.com
Personal|johndoe|john@personal.com
EOF
}

teardown() {
    common_teardown
}

@test "git-profile: sets user.name on selection" {
    ROFI_MOCK_OUTPUT="Work (John Doe <john@company.com>)"
    run bash "$(get_script rofi-git-profile.sh)"
    assert_mock_called_with "git" "config --global user.name John Doe"
}

@test "git-profile: sets user.email on selection" {
    ROFI_MOCK_OUTPUT="Work (John Doe <john@company.com>)"
    run bash "$(get_script rofi-git-profile.sh)"
    assert_mock_called_with "git" "config --global user.email john@company.com"
}

@test "git-profile: notification sent on switch" {
    ROFI_MOCK_OUTPUT="Personal (johndoe <john@personal.com>)"
    run bash "$(get_script rofi-git-profile.sh)"
    assert_mock_called_with "notify-send" "Git Profile"
}

@test "git-profile: skips comment lines" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-git-profile.sh)"
    # Should present 2 options (not the comment line)
    assert_mock_called "rofi"
}

@test "git-profile: empty selection does nothing" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-git-profile.sh)"
    assert_mock_not_called "git"
}

@test "git-profile: error if config file missing" {
    rm "$HOME/.config/rofi/scripts/git-profiles.conf"
    run bash "$(get_script rofi-git-profile.sh)"
    assert_mock_called_with "notify-send" "Error"
}

@test "git-profile: rofi called with git-profile theme" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-git-profile.sh)"
    assert_mock_called_with "rofi" "git-profile.rasi"
}
```

Run: `cd ~/.config/rofi/tests && bats test_git_profile.bats`
Expected: All tests pass.

---

## Task 9: Test Tmux and Projects

**Files:**
- Create: `~/.config/rofi/tests/test_tmux.bats`
- Create: `~/.config/rofi/tests/test_projects.bats`

**Step 1: Tmux tests**

```bash
#!/usr/bin/env bats
# test_tmux.bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

@test "tmux: lists existing sessions" {
    TMUX_SESSIONS="dev (3 windows) [attached]
staging (1 windows) "
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-tmux.sh)"
    assert_mock_called_with "tmux" "list-sessions"
}

@test "tmux: new session creates and attaches" {
    TMUX_SESSIONS=""
    set_rofi_outputs "+ New Session" "my-session"
    run bash "$(get_script rofi-tmux.sh)"
    assert_mock_called_with "tmux" "new-session"
    assert_mock_called_with "notify-send" "Created session"
}

@test "tmux: kill session prompts for target" {
    TMUX_SESSIONS="dev (3 windows) "
    set_rofi_outputs " Kill Session" "dev"
    run bash "$(get_script rofi-tmux.sh)"
    assert_mock_called_with "tmux" "kill-session"
    assert_mock_called_with "tmux" "-t dev"
}

@test "tmux: selecting session attaches via kitty (outside tmux)" {
    TMUX_SESSIONS="dev (3 windows) "
    ROFI_MOCK_OUTPUT="dev (3 windows) "
    unset TMUX
    run bash "$(get_script rofi-tmux.sh)"
    assert_mock_called "kitty"
}

@test "tmux: selecting session switches client (inside tmux)" {
    TMUX_SESSIONS="dev (3 windows) "
    ROFI_MOCK_OUTPUT="dev (3 windows) "
    export TMUX="/tmp/tmux-1000/default,12345,0"
    run bash "$(get_script rofi-tmux.sh)"
    assert_mock_called_with "tmux" "switch-client"
}

@test "tmux: empty selection does nothing" {
    TMUX_SESSIONS="dev (3 windows) "
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-tmux.sh)"
    local action_calls
    action_calls=$(grep "^tmux " "$MOCK_LOG" | grep -v "list-sessions" | wc -l)
    assert_equal "$action_calls" "0"
}

@test "tmux: rofi called with tmux theme" {
    TMUX_SESSIONS=""
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-tmux.sh)"
    assert_mock_called_with "rofi" "tmux.rasi"
}
```

**Step 2: Projects tests**

```bash
#!/usr/bin/env bats
# test_projects.bats

setup() {
    load 'test_helper/common'
    common_setup
    FIND_USE_REAL=true
    export FIND_USE_REAL
    mkdir -p "$HOME/work"
}

teardown() {
    common_teardown
}

@test "projects: detects Go project" {
    mkdir -p "$HOME/work/myapi"
    touch "$HOME/work/myapi/go.mod"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-projects.sh)"
    assert_output --partial "󰟓"
}

@test "projects: detects Node project" {
    mkdir -p "$HOME/work/webapp"
    touch "$HOME/work/webapp/package.json"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-projects.sh)"
    assert_output --partial ""
}

@test "projects: detects Rust project" {
    mkdir -p "$HOME/work/cli-tool"
    touch "$HOME/work/cli-tool/Cargo.toml"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-projects.sh)"
    assert_output --partial ""
}

@test "projects: opens VS Code on selection" {
    mkdir -p "$HOME/work/myproject"
    set_rofi_outputs "󰉋  myproject" "  Open in VS Code"
    run bash "$(get_script rofi-projects.sh)"
    assert_mock_called "code"
}

@test "projects: opens terminal on selection" {
    mkdir -p "$HOME/work/myproject"
    set_rofi_outputs "󰉋  myproject" "  Open Terminal"
    run bash "$(get_script rofi-projects.sh)"
    assert_mock_called "kitty"
}

@test "projects: handles empty directory" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-projects.sh)"
    assert_mock_called_with "notify-send" "No projects found"
}

@test "projects: rofi called with projects theme" {
    mkdir -p "$HOME/work/test"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-projects.sh)"
    assert_mock_called_with "rofi" "projects.rasi"
}
```

Run: `cd ~/.config/rofi/tests && bats test_tmux.bats test_projects.bats`
Expected: All tests pass.

---

## Task 10: Test Obsidian Suite

**Files:**
- Create: `~/.config/rofi/tests/test_obsidian.bats`

```bash
#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
    FIND_USE_REAL=true
    export FIND_USE_REAL
    mkdir -p "$HOME/powerhouse/daily"
    mkdir -p "$HOME/powerhouse/projects"
}

teardown() {
    common_teardown
}

# ── Quick Actions (rofi-obsidian.sh) ──────────────────────────

@test "obsidian: daily note creates file with frontmatter" {
    ROFI_MOCK_OUTPUT="  Create Daily Note"
    run bash "$(get_script rofi-obsidian.sh)"
    today=$(date +%Y-%m-%d)
    assert [ -f "$HOME/powerhouse/daily/$today.md" ]
    run cat "$HOME/powerhouse/daily/$today.md"
    assert_output --partial "type: daily"
    assert_output --partial "tags: [daily]"
}

@test "obsidian: daily note is idempotent (no overwrite)" {
    today=$(date +%Y-%m-%d)
    echo "existing content" > "$HOME/powerhouse/daily/$today.md"
    ROFI_MOCK_OUTPUT="  Create Daily Note"
    run bash "$(get_script rofi-obsidian.sh)"
    run cat "$HOME/powerhouse/daily/$today.md"
    assert_output --partial "existing content"
}

@test "obsidian: open vault launches VS Code" {
    ROFI_MOCK_OUTPUT="  Open Vault in VS Code"
    run bash "$(get_script rofi-obsidian.sh)"
    assert_mock_called_with "code" "powerhouse"
}

@test "obsidian: rofi called with obsidian theme" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-obsidian.sh)"
    assert_mock_called_with "rofi" "obsidian.rasi"
}

# ── Note Search (rofi-obsidian-search.sh) ─────────────────────

@test "obsidian-search: finds markdown files" {
    touch "$HOME/powerhouse/note1.md"
    touch "$HOME/powerhouse/projects/note2.md"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-obsidian-search.sh)"
    assert_mock_called_with "rofi" "obsidian-search.rasi"
}

@test "obsidian-search: opens selected note in VS Code" {
    touch "$HOME/powerhouse/test-note.md"
    ROFI_MOCK_OUTPUT="test-note.md"
    run bash "$(get_script rofi-obsidian-search.sh)"
    assert_mock_called_with "code" "test-note.md"
}

@test "obsidian-search: handles empty vault" {
    rm -rf "$HOME/powerhouse"/*
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-obsidian-search.sh)"
    assert_mock_called_with "notify-send" "No notes found"
}

# ── Note Create (rofi-obsidian-create.sh) ─────────────────────

@test "obsidian-create: creates note with frontmatter" {
    set_rofi_outputs "." "my-new-note"
    run bash "$(get_script rofi-obsidian-create.sh)"
    assert [ -f "$HOME/powerhouse/my-new-note.md" ]
    run cat "$HOME/powerhouse/my-new-note.md"
    assert_output --partial "type: note"
    assert_output --partial "# my-new-note"
}

@test "obsidian-create: creates note in subdirectory" {
    set_rofi_outputs "projects" "design-doc"
    run bash "$(get_script rofi-obsidian-create.sh)"
    assert [ -f "$HOME/powerhouse/projects/design-doc.md" ]
}

@test "obsidian-create: warns on duplicate" {
    touch "$HOME/powerhouse/existing.md"
    set_rofi_outputs "." "existing"
    run bash "$(get_script rofi-obsidian-create.sh)"
    assert_mock_called_with "notify-send" "already exists"
}

@test "obsidian-create: empty name cancels" {
    set_rofi_outputs "." ""
    run bash "$(get_script rofi-obsidian-create.sh)"
    assert_mock_not_called "code"
}
```

Run: `cd ~/.config/rofi/tests && bats test_obsidian.bats`
Expected: All tests pass.

---

## Task 11: Test Bluetooth

**Files:**
- Create: `~/.config/rofi/tests/test_bluetooth.bats`

```bash
#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

@test "bluetooth: powers on if powered off" {
    BT_POWERED="no"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_mock_called_with "bluetoothctl" "power on"
}

@test "bluetooth: skips power on if already on" {
    BT_POWERED="yes"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bluetooth.sh)"
    # power on should not appear in the log
    local power_calls
    power_calls=$(grep "bluetoothctl power" "$MOCK_LOG" | wc -l)
    assert_equal "$power_calls" "0"
}

@test "bluetooth: shows paired devices" {
    BT_POWERED="yes"
    BT_PAIRED_DEVICES="Device AA:BB:CC:DD:EE:FF My Headphones"
    BT_CONNECTED="no"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_mock_called_with "bluetoothctl" "devices Paired"
}

@test "bluetooth: scan triggers bluetoothctl scan" {
    BT_POWERED="yes"
    BT_PAIRED_DEVICES=""
    BT_ALL_DEVICES="Device 11:22:33:44:55:66 New Speaker"
    set_rofi_outputs "󰂰  Scan for devices" "New Speaker"
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_mock_called_with "bluetoothctl" "scan on"
    assert_mock_called_with "bluetoothctl" "pair"
}

@test "bluetooth: connect selected device" {
    BT_POWERED="yes"
    BT_PAIRED_DEVICES="Device AA:BB:CC:DD:EE:FF Headphones"
    BT_CONNECTED="no"
    set_rofi_outputs "  Headphones" "󰂱  Connect"
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_mock_called_with "bluetoothctl" "connect"
}

@test "bluetooth: disconnect connected device" {
    BT_POWERED="yes"
    BT_PAIRED_DEVICES="Device AA:BB:CC:DD:EE:FF Headphones"
    BT_CONNECTED="yes"
    set_rofi_outputs "󰂱  Headphones [connected]" "󰂲  Disconnect"
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_mock_called_with "bluetoothctl" "disconnect"
}

@test "bluetooth: empty selection exits cleanly" {
    BT_POWERED="yes"
    BT_PAIRED_DEVICES=""
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_success
}

@test "bluetooth: rofi called with bluetooth theme" {
    BT_POWERED="yes"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bluetooth.sh)"
    assert_mock_called_with "rofi" "bluetooth.rasi"
}
```

Run: `cd ~/.config/rofi/tests && bats test_bluetooth.bats`
Expected: All tests pass.

---

## Task 12: Test Display

**Files:**
- Create: `~/.config/rofi/tests/test_display.bats`

```bash
#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

@test "display: detects two monitors" {
    XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0
HDMI-1 connected 2560x1440+1920+0"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "rofi" "display.rasi"
}

@test "display: laptop only turns off external" {
    XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0
HDMI-1 connected 2560x1440+1920+0"
    ROFI_MOCK_OUTPUT="󰍹  Laptop Only (eDP-1)"
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "xrandr" "--output eDP-1 --auto --primary --output HDMI-1 --off"
}

@test "display: external only turns off laptop" {
    XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0
HDMI-1 connected 2560x1440+1920+0"
    ROFI_MOCK_OUTPUT="󰍹  External Only (HDMI-1)"
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "xrandr" "--output HDMI-1 --auto --primary --output eDP-1 --off"
}

@test "display: mirror uses same-as" {
    XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0
HDMI-1 connected 2560x1440+1920+0"
    ROFI_MOCK_OUTPUT="󰍺  Mirror"
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "xrandr" "--same-as"
}

@test "display: extend right uses right-of" {
    XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0
HDMI-1 connected 2560x1440+1920+0"
    ROFI_MOCK_OUTPUT="  Extend Right"
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "xrandr" "--right-of"
}

@test "display: single monitor shows notification" {
    XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0"
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "notify-send" "Only one display"
}

@test "display: notification sent after layout change" {
    XRANDR_OUTPUT="eDP-1 connected primary 1920x1080+0+0
HDMI-1 connected 2560x1440+1920+0"
    ROFI_MOCK_OUTPUT="󰕥  Auto Detect"
    run bash "$(get_script rofi-display.sh)"
    assert_mock_called_with "notify-send" "Layout changed"
}
```

Run: `cd ~/.config/rofi/tests && bats test_display.bats`
Expected: All tests pass.

---

## Task 13: Test Systemd, Bookmarks, Websearch

**Files:**
- Create: `~/.config/rofi/tests/test_systemd.bats`
- Create: `~/.config/rofi/tests/test_bookmarks.bats`
- Create: `~/.config/rofi/tests/test_websearch.bats`

**Step 1: Systemd tests**

```bash
#!/usr/bin/env bats
# test_systemd.bats

setup() {
    load 'test_helper/common'
    common_setup
    # Mock systemctl list-units output — override the mock for this test
    cat > "$MOCKS_DIR/systemctl" << 'MOCK'
#!/usr/bin/env bash
echo "systemctl $*" >> "$MOCK_LOG"
if [[ "$1" == "list-units" ]]; then
    echo "ssh.service loaded active running OpenBSD Secure Shell server"
    echo "docker.service loaded inactive dead Docker Application Container Engine"
fi
MOCK
    chmod +x "$MOCKS_DIR/systemctl"
}

teardown() {
    # Restore original systemctl mock
    cat > "$MOCKS_DIR/systemctl" << 'MOCK'
#!/usr/bin/env bash
echo "systemctl $*" >> "$MOCK_LOG"
MOCK
    chmod +x "$MOCKS_DIR/systemctl"
    common_teardown
}

@test "systemd: lists services with pango markup" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-systemd.sh)"
    assert_mock_called_with "rofi" "-markup-rows"
}

@test "systemd: restart service calls pkexec systemctl restart" {
    set_rofi_outputs "<span color='#A6E3A1'>●</span> <b>ssh</b> <span color='#6C7086'>[running]</span>" "󰜉  Restart"
    run bash "$(get_script rofi-systemd.sh)"
    assert_mock_called_with "pkexec" "systemctl restart ssh.service"
}

@test "systemd: stop service calls pkexec systemctl stop" {
    set_rofi_outputs "<span color='#A6E3A1'>●</span> <b>docker</b> <span color='#6C7086'>[dead]</span>" "  Stop"
    run bash "$(get_script rofi-systemd.sh)"
    assert_mock_called_with "pkexec" "systemctl stop docker.service"
}

@test "systemd: view logs opens kitty with journalctl" {
    set_rofi_outputs "<span color='#A6E3A1'>●</span> <b>ssh</b> <span color='#6C7086'>[running]</span>" "  View Logs"
    run bash "$(get_script rofi-systemd.sh)"
    assert_mock_called "kitty"
}

@test "systemd: rofi called with systemd theme" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-systemd.sh)"
    assert_mock_called_with "rofi" "systemd.rasi"
}
```

**Step 2: Bookmarks tests**

```bash
#!/usr/bin/env bats
# test_bookmarks.bats

setup() {
    load 'test_helper/common'
    common_setup
    # Create fake Firefox profile with places.sqlite
    mkdir -p "$HOME/snap/firefox/common/.mozilla/firefox/abc123.default"
    touch "$HOME/snap/firefox/common/.mozilla/firefox/abc123.default/places.sqlite"
    FIND_USE_REAL=true
    export FIND_USE_REAL
}

teardown() {
    common_teardown
}

@test "bookmarks: finds places.sqlite in snap path" {
    SQLITE3_OUTPUT="GitHub | https://github.com"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bookmarks.sh)"
    assert_mock_called "sqlite3"
}

@test "bookmarks: copies db to /tmp (avoids Firefox lock)" {
    SQLITE3_OUTPUT="GitHub | https://github.com"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bookmarks.sh)"
    # sqlite3 should be called with a /tmp path
    assert_mock_called_with "sqlite3" "/tmp/"
}

@test "bookmarks: opens selected URL in firefox" {
    SQLITE3_OUTPUT="GitHub | https://github.com"
    ROFI_MOCK_OUTPUT="GitHub | https://github.com"
    run bash "$(get_script rofi-bookmarks.sh)"
    assert_mock_called_with "firefox" "https://github.com"
}

@test "bookmarks: error if no Firefox profile" {
    rm -rf "$HOME/snap" "$HOME/.mozilla"
    run bash "$(get_script rofi-bookmarks.sh)"
    assert_mock_called_with "notify-send" "Firefox profile not found"
}

@test "bookmarks: rofi called with bookmarks theme" {
    SQLITE3_OUTPUT="Test | https://test.com"
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-bookmarks.sh)"
    assert_mock_called_with "rofi" "bookmarks.rasi"
}
```

**Step 3: Websearch tests**

```bash
#!/usr/bin/env bats
# test_websearch.bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

@test "websearch: google search opens correct URL" {
    set_rofi_outputs "  Google" "test query"
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_called_with "firefox" "google.com/search"
}

@test "websearch: duckduckgo search opens correct URL" {
    set_rofi_outputs "  DuckDuckGo" "test query"
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_called_with "firefox" "duckduckgo.com"
}

@test "websearch: youtube search opens correct URL" {
    set_rofi_outputs "  YouTube" "test query"
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_called_with "firefox" "youtube.com/results"
}

@test "websearch: wikipedia search opens correct URL" {
    set_rofi_outputs "󰖬  Wikipedia" "test query"
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_called_with "firefox" "wikipedia.org"
}

@test "websearch: empty engine selection exits" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_not_called "firefox"
}

@test "websearch: empty query exits" {
    set_rofi_outputs "  Google" ""
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_not_called "firefox"
}

@test "websearch: rofi called with websearch theme" {
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-websearch.sh)"
    assert_mock_called_with "rofi" "websearch.rasi"
}
```

Run: `cd ~/.config/rofi/tests && bats test_systemd.bats test_bookmarks.bats test_websearch.bats`
Expected: All tests pass.

---

## Task 14: Test API Scripts

**Files:**
- Create: `~/.config/rofi/tests/test_api_scripts.bats`

```bash
#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

# ── Google Suggest ────────────────────────────────────────────

@test "api: google-suggest calls correct endpoint" {
    CURL_OUTPUT='["test",["test result","testing"]]'
    run bash "$(get_script apis/google-suggest.sh)" "test"
    assert_mock_called_with "curl" "suggestqueries.google.com"
}

@test "api: google-suggest passes query parameter" {
    CURL_OUTPUT='["test",["test result"]]'
    run bash "$(get_script apis/google-suggest.sh)" "hello world"
    assert_mock_called_with "curl" "q="
}

@test "api: google-suggest exits on empty query" {
    run bash "$(get_script apis/google-suggest.sh)" ""
    assert_mock_not_called "curl"
}

# ── DuckDuckGo Suggest ───────────────────────────────────────

@test "api: ddg-suggest calls correct endpoint" {
    CURL_OUTPUT='["test",["test result","testing"]]'
    run bash "$(get_script apis/ddg-suggest.sh)" "test"
    assert_mock_called_with "curl" "ac.duckduckgo.com"
}

@test "api: ddg-suggest uses type=list parameter" {
    CURL_OUTPUT='["test",["test result"]]'
    run bash "$(get_script apis/ddg-suggest.sh)" "test"
    assert_mock_called_with "curl" "type=list"
}

# ── YouTube Suggest ──────────────────────────────────────────

@test "api: youtube-suggest calls google endpoint with ds=yt" {
    CURL_OUTPUT='["test",["test video"]]'
    run bash "$(get_script apis/youtube-suggest.sh)" "test"
    assert_mock_called_with "curl" "ds=yt"
}

# ── Wikipedia Suggest ────────────────────────────────────────

@test "api: wikipedia-suggest calls opensearch API" {
    CURL_OUTPUT='["test",["Test page"]]'
    run bash "$(get_script apis/wikipedia-suggest.sh)" "test"
    assert_mock_called_with "curl" "action=opensearch"
}

@test "api: wikipedia-suggest exits on empty query" {
    run bash "$(get_script apis/wikipedia-suggest.sh)" ""
    assert_mock_not_called "curl"
}
```

Run: `cd ~/.config/rofi/tests && bats test_api_scripts.bats`
Expected: All tests pass.

---

## Task 15: Test i3 Keybinding Validation

**Files:**
- Create: `~/.config/rofi/tests/test_i3_keybindings.bats`

This test parses the REAL i3 config and validates that every planned keybinding exists, points to the correct script/command, and uses the correct theme.

```bash
#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    # Use REAL_HOME since we're testing the actual i3 config
    I3_CONFIG="$REAL_HOME/.config/i3/config"
    if [[ ! -f "$I3_CONFIG" ]]; then
        skip "i3 config not found at $I3_CONFIG"
    fi
}

# Helper: check if a bindsym line exists containing all given substrings
assert_binding() {
    local key="$1"
    shift
    local line
    line=$(grep "bindsym.*$key" "$I3_CONFIG" | head -1)
    if [[ -z "$line" ]]; then
        echo "No binding found for key: $key"
        return 1
    fi
    for substr in "$@"; do
        if [[ "$line" != *"$substr"* ]]; then
            echo "Binding for $key missing '$substr'"
            echo "Actual: $line"
            return 1
        fi
    done
}

# ── Core Rofi Bindings ────────────────────────────────────────

@test "i3: mod+d launches drun with launcher theme" {
    assert_binding '$mod+d' "rofi -show drun" "launcher.rasi"
}

@test "i3: mod+Shift+d launches run with launcher theme" {
    assert_binding '$mod+Shift+d' "rofi -show run" "launcher.rasi"
}

@test "i3: mod+Tab launches window switcher" {
    assert_binding '$mod+Tab' "rofi -show window" "launcher.rasi"
}

@test "i3: mod+Shift+s launches SSH" {
    assert_binding '$mod+Shift+s' "rofi -show ssh" "launcher.rasi"
}

@test "i3: mod+Shift+f launches filebrowser" {
    assert_binding '$mod+Shift+f' "rofi -show filebrowser" "launcher.rasi"
}

@test "i3: mod+F1 launches rofi keys" {
    assert_binding '$mod+F1' "rofi -show keys" "keybindings.rasi"
}

# ── System Bindings ───────────────────────────────────────────

@test "i3: mod+Shift+e launches power menu" {
    assert_binding '$mod+Shift+e' "rofi-power.sh"
}

@test "i3: mod+c launches clipboard" {
    assert_binding '$mod+c' "rofi-clipboard.sh"
}

@test "i3: mod+Shift+b launches bluetooth" {
    assert_binding '$mod+Shift+b' "rofi-bluetooth.sh"
}

@test "i3: mod+Shift+m launches display manager" {
    assert_binding '$mod+Shift+m' "rofi-display.sh"
}

@test "i3: mod+Shift+w launches wallpaper" {
    assert_binding '$mod+Shift+w' "rofi-wallpaper.sh"
}

@test "i3: Print launches screenshot" {
    assert_binding 'Print' "rofi-screenshot.sh"
}

@test "i3: mod+Shift+p launches systemd" {
    assert_binding '$mod+Shift+p' "rofi-systemd.sh"
}

# ── Productivity Bindings ─────────────────────────────────────

@test "i3: mod+equal launches calculator with calc theme" {
    assert_binding '$mod+equal' "rofi -show calc" "calculator.rasi"
}

@test "i3: mod+period launches rofimoji with emoji theme" {
    assert_binding '$mod+period' "rofimoji" "emoji.rasi"
}

@test "i3: mod+slash launches websearch" {
    assert_binding '$mod+slash' "rofi-websearch.sh"
}

# ── Developer Bindings ────────────────────────────────────────

@test "i3: mod+p launches project manager" {
    assert_binding '$mod+p' "rofi-projects.sh"
}

@test "i3: mod+g launches git profile" {
    assert_binding '$mod+g' "rofi-git-profile.sh"
}

@test "i3: mod+t launches tmux" {
    assert_binding '$mod+t' "rofi-tmux.sh"
}

# ── Browser Bindings ─────────────────────────────────────────

@test "i3: mod+Shift+o launches bookmarks" {
    assert_binding '$mod+Shift+o' "rofi-bookmarks.sh"
}

# ── Notes Bindings ────────────────────────────────────────────

@test "i3: mod+n launches obsidian actions" {
    assert_binding '$mod+n' "rofi-obsidian.sh"
}

@test "i3: mod+Shift+n launches obsidian search" {
    assert_binding '$mod+Shift+n' "rofi-obsidian-search.sh"
}

# ── Other Bindings ────────────────────────────────────────────

@test "i3: mod+F2 launches keybinding viewer" {
    assert_binding '$mod+F2' "rofi-keybindings.sh"
}

@test "i3: mod+m launches media controls" {
    assert_binding '$mod+m' "rofi-media.sh"
}

# ── Autostart ─────────────────────────────────────────────────

@test "i3: greenclip daemon in autostart" {
    grep -q "greenclip daemon" "$I3_CONFIG"
}

@test "i3: fehbg in autostart" {
    grep -q "fehbg" "$I3_CONFIG"
}

# ── Script Existence ─────────────────────────────────────────

@test "i3: all referenced scripts exist and are executable" {
    local scripts_dir="$REAL_HOME/.config/rofi/scripts"
    local failures=""
    while IFS= read -r script; do
        if [[ ! -x "$script" ]]; then
            failures+="Not executable: $script\n"
        fi
    done < <(grep -oP '~/.config/rofi/scripts/\S+' "$I3_CONFIG" | sed "s|~|$REAL_HOME|g" | sort -u)

    if [[ -n "$failures" ]]; then
        echo -e "$failures"
        return 1
    fi
}
```

Run: `cd ~/.config/rofi/tests && bats test_i3_keybindings.bats`
Expected: All tests pass.

---

## Task 16: Create Test Runner and Verify

**Files:**
- Create: `~/.config/rofi/tests/run_tests.sh`

**Step 1: Create the runner script**

```bash
#!/usr/bin/env bash
#
# run_tests.sh — Runs the complete rofi test suite
#
# Usage:
#   ./run_tests.sh              # Run all tests
#   ./run_tests.sh test_power   # Run specific test file
#   ./run_tests.sh -v           # Verbose output

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check BATS is installed
if ! command -v bats &> /dev/null; then
    echo "ERROR: bats not found. Install with: sudo apt install bats"
    exit 1
fi

# Check bats-support/bats-assert are installed
if [[ ! -d "$TESTS_DIR/test_helper/bats-support" ]]; then
    echo "Installing bats-support..."
    git clone --depth 1 https://github.com/bats-core/bats-support.git \
        "$TESTS_DIR/test_helper/bats-support"
fi

if [[ ! -d "$TESTS_DIR/test_helper/bats-assert" ]]; then
    echo "Installing bats-assert..."
    git clone --depth 1 https://github.com/bats-core/bats-assert.git \
        "$TESTS_DIR/test_helper/bats-assert"
fi

# Run tests
if [[ $# -gt 0 ]]; then
    if [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
        bats --verbose-run "$TESTS_DIR"/test_*.bats
    elif [[ -f "$TESTS_DIR/${1}.bats" ]]; then
        bats "$TESTS_DIR/${1}.bats"
    elif [[ -f "$TESTS_DIR/$1" ]]; then
        bats "$TESTS_DIR/$1"
    else
        echo "Test file not found: $1"
        exit 1
    fi
else
    echo "Running all rofi tests..."
    echo "========================="
    bats "$TESTS_DIR"/test_*.bats
    echo ""
    echo "All tests complete."
fi
```

**Step 2: Make runner executable**

```bash
chmod +x ~/.config/rofi/tests/run_tests.sh
```

**Step 3: Run the full test suite**

```bash
cd ~/.config/rofi/tests && ./run_tests.sh
```

Expected: All test files run, all tests pass. Output shows test counts per file.

**Step 4: Run individual test files to verify isolation**

```bash
cd ~/.config/rofi/tests && bats test_smoke.bats
cd ~/.config/rofi/tests && bats test_power.bats
cd ~/.config/rofi/tests && bats test_i3_keybindings.bats
```

Expected: Each file passes independently.

---

## Summary

| Test File | Tests | What It Covers |
|---|---|---|
| `test_smoke.bats` | 5 | Mock infrastructure validation |
| `test_power.bats` | 11 | Power menu: all 5 actions + confirmation + cancel |
| `test_media.bats` | 8 | Media controls: all 5 actions + track info |
| `test_screenshot.bats` | 8 | Screenshot: 3 modes + clipboard + notification |
| `test_keybindings_viewer.bats` | 4 | Keybinding parser + markup |
| `test_wallpaper.bats` | 5 | Wallpaper picker + feh + empty dir |
| `test_clipboard.bats` | 4 | Greenclip daemon mgmt + rofi modi |
| `test_git_profile.bats` | 7 | Profile parsing + git config + errors |
| `test_tmux.bats` | 7 | Sessions list/create/kill + TMUX detection |
| `test_projects.bats` | 7 | Project type detection + sub-menu actions |
| `test_obsidian.bats` | 12 | Daily notes + search + create + idempotency |
| `test_bluetooth.bats` | 8 | Power on + scan + connect/disconnect |
| `test_display.bats` | 7 | Monitor detection + 5 layout modes |
| `test_systemd.bats` | 5 | Service listing + start/stop/restart/logs |
| `test_bookmarks.bats` | 5 | Firefox DB + sqlite + URL opening |
| `test_websearch.bats` | 7 | 4 engines + empty handling |
| `test_api_scripts.bats` | 8 | 4 API scripts: endpoints + parameters |
| `test_i3_keybindings.bats` | 27 | All 24 bindings + autostart + script existence |
| **Total** | **~149** | |
