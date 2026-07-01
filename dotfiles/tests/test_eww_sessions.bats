#!/usr/bin/env bats
# test_eww_sessions.bats — eww-sessions.sh: tmux sessions grouped by context.
#
# Owns ONLY eww-sessions.sh. Self-contained: builds its OWN tmux mock in a temp
# dir prepended to PATH (does not depend on the shared rofi mock harness), so the
# mock can echo whatever `-F` format the script requests. Real jq runs.

setup() {
    SESSIONS_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_eww-sessions.sh"
    TEST_TEMP="$(mktemp -d)"
    MOCK_BIN="$TEST_TEMP/bin"
    mkdir -p "$MOCK_BIN"
    export TMUX_SESSIONS_OUT="$TEST_TEMP/sessions.txt"
    : > "$TMUX_SESSIONS_OUT"

    # tmux mock: list-sessions echoes the prepared "name attached" lines; exits
    # non-zero (like a dead server) when the file is empty.
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "list-sessions" ]]; then
    if [[ -s "$TMUX_SESSIONS_OUT" ]]; then
        cat "$TMUX_SESSIONS_OUT"
        exit 0
    fi
    exit 1
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/tmux"
    export PATH="$MOCK_BIN:$PATH"
}

teardown() {
    rm -rf "$TEST_TEMP"
}

# set_sessions <lines...> — each arg is one "name attached" line.
set_sessions() {
    : > "$TMUX_SESSIONS_OUT"
    local l
    for l in "$@"; do
        printf '%s\n' "$l" >> "$TMUX_SESSIONS_OUT"
    done
}

# ── basic shape ───────────────────────────────────────────────

@test "eww-sessions: emits a JSON array" {
    set_sessions "work:pnow-ats 1"
    run bash "$SESSIONS_SH"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'type == "array"' >/dev/null
}

@test "eww-sessions: groups sessions by context prefix" {
    set_sessions "work:pnow-ats 1" "work:boolgen 0" "lab:exp1 0"
    run bash "$SESSIONS_SH"
    # two groups: work, lab
    [ "$(echo "$output" | jq 'length')" -eq 2 ]
    echo "$output" | jq -e '.[] | select(.context=="work") | .sessions | length == 2' >/dev/null
    echo "$output" | jq -e '.[] | select(.context=="lab")  | .sessions | length == 1' >/dev/null
}

@test "eww-sessions: each group exposes context + sessions keys" {
    set_sessions "work:pnow-ats 1"
    run bash "$SESSIONS_SH"
    echo "$output" | jq -e '.[0] | has("context") and has("sessions")' >/dev/null
}

@test "eww-sessions: session name is stripped of its context prefix" {
    set_sessions "work:pnow-ats 1"
    run bash "$SESSIONS_SH"
    [ "$(echo "$output" | jq -r '.[0].sessions[0].name')" = "pnow-ats" ]
}

# ── attached flag ─────────────────────────────────────────────

@test "eww-sessions: attached flag becomes a JSON boolean" {
    set_sessions "work:pnow-ats 1" "work:idle 0"
    run bash "$SESSIONS_SH"
    [ "$(echo "$output" | jq -r '.[0].sessions[] | select(.name=="pnow-ats") | .attached')" = "true" ]
    [ "$(echo "$output" | jq -r '.[0].sessions[] | select(.name=="idle") | .attached')" = "false" ]
}

# ── prefix-less sessions ──────────────────────────────────────

@test "eww-sessions: a session with no prefix lands in the misc group" {
    set_sessions "scratch 0"
    run bash "$SESSIONS_SH"
    [ "$(echo "$output" | jq -r '.[0].context')" = "misc" ]
    [ "$(echo "$output" | jq -r '.[0].sessions[0].name')" = "scratch" ]
}

# ── ordering ──────────────────────────────────────────────────

@test "eww-sessions: groups are sorted by context" {
    set_sessions "work:a 0" "agents:b 0" "lab:c 0"
    run bash "$SESSIONS_SH"
    [ "$(echo "$output" | jq -r '[.[].context] | join(",")')" = "agents,lab,work" ]
}

# ── empty / no server ─────────────────────────────────────────

@test "eww-sessions: no tmux server yields an empty array, exit 0" {
    set_sessions  # leave the file empty -> mock exits 1
    run bash "$SESSIONS_SH"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq 'length')" -eq 0 ]
    echo "$output" | jq -e 'type == "array"' >/dev/null
}
