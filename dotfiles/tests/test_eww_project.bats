#!/usr/bin/env bats
# test_eww_project.bats — eww-project.sh: project name + git branch as JSON
# for the bottom bar's left cell.
#
# eww-project reads ~/.cache/ctx-project (a recorded directory path, NOT the
# eww process $PWD), derives the project name from its basename, and reads
# that repo's current branch with `git -C <dir>`. We assert valid JSON with
# `.project` + `.branch`, the basename derivation, the branch read against a
# real temp git repo, and the calm fallbacks (missing file / non-git dir).

setup() {
    load 'test_helper/common'
    common_setup
    PROJECT_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_eww-project.sh"
    mkdir -p "$HOME/.cache"
    # common_setup injects a no-op `git` mock onto PATH; use the real binary
    # both for test repo setup and for the script (via its GIT_BIN override).
    REAL_GIT=/usr/bin/git
}

teardown() {
    common_teardown
}

# ── JSON shape ────────────────────────────────────────────────

@test "eww-project: emits valid JSON with project + branch keys" {
    printf '%s\n' "$TEST_TEMP/pnow-ats-v2" > "$HOME/.cache/ctx-project"
    mkdir -p "$TEST_TEMP/pnow-ats-v2"
    run bash "$PROJECT_SH"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'has("project") and has("branch")' >/dev/null
}

@test "eww-project: output is parseable JSON" {
    printf '%s\n' "$TEST_TEMP/demo" > "$HOME/.cache/ctx-project"
    mkdir -p "$TEST_TEMP/demo"
    run bash "$PROJECT_SH"
    echo "$output" | jq -e '.' >/dev/null
}

# ── project name = basename of recorded path ──────────────────

@test "eww-project: project name is the basename of the recorded path" {
    mkdir -p "$TEST_TEMP/work/pnow-ats-v2"
    printf '%s\n' "$TEST_TEMP/work/pnow-ats-v2" > "$HOME/.cache/ctx-project"
    run bash "$PROJECT_SH"
    [ "$(echo "$output" | jq -r '.project')" = "pnow-ats-v2" ]
}

# ── branch read against a real git repo (git -C <dir>, not $PWD) ──

@test "eww-project: reads current branch of the recorded git repo" {
    repo="$TEST_TEMP/repo"
    mkdir -p "$repo"
    "$REAL_GIT" -C "$repo" init -q
    "$REAL_GIT" -C "$repo" config user.email t@t.t
    "$REAL_GIT" -C "$repo" config user.name t
    "$REAL_GIT" -C "$repo" commit -q --allow-empty -m init
    "$REAL_GIT" -C "$repo" checkout -q -b feat/boolgen-otel
    printf '%s\n' "$repo" > "$HOME/.cache/ctx-project"
    export GIT_BIN="$REAL_GIT"
    run bash "$PROJECT_SH"
    [ "$(echo "$output" | jq -r '.project')" = "repo" ]
    [ "$(echo "$output" | jq -r '.branch')" = "feat/boolgen-otel" ]
}

@test "eww-project: ignores the process PWD (uses recorded path only)" {
    # A git repo as cwd must NOT leak into output; only ctx-project counts.
    cwdrepo="$TEST_TEMP/cwdrepo"
    mkdir -p "$cwdrepo"
    "$REAL_GIT" -C "$cwdrepo" init -q
    "$REAL_GIT" -C "$cwdrepo" config user.email t@t.t
    "$REAL_GIT" -C "$cwdrepo" config user.name t
    "$REAL_GIT" -C "$cwdrepo" commit -q --allow-empty -m init
    "$REAL_GIT" -C "$cwdrepo" checkout -q -b should-not-appear

    target="$TEST_TEMP/target"
    mkdir -p "$target"
    printf '%s\n' "$target" > "$HOME/.cache/ctx-project"

    export GIT_BIN="$REAL_GIT"
    run bash -c "cd '$cwdrepo' && bash '$PROJECT_SH'"
    [ "$(echo "$output" | jq -r '.project')" = "target" ]
    [ "$(echo "$output" | jq -r '.branch')" != "should-not-appear" ]
}

# ── calm fallbacks (never blank, never error) ─────────────────

@test "eww-project: missing cache file falls back to em-dash, empty branch" {
    rm -f "$HOME/.cache/ctx-project"
    run bash "$PROJECT_SH"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.project')" = "—" ]
    [ "$(echo "$output" | jq -r '.branch')" = "" ]
}

@test "eww-project: non-git project dir yields a project name and empty branch" {
    mkdir -p "$TEST_TEMP/plain-dir"
    printf '%s\n' "$TEST_TEMP/plain-dir" > "$HOME/.cache/ctx-project"
    export GIT_BIN="$REAL_GIT"
    run bash "$PROJECT_SH"
    [ "$(echo "$output" | jq -r '.project')" = "plain-dir" ]
    [ "$(echo "$output" | jq -r '.branch')" = "" ]
}

@test "eww-project: non-existent dir path still yields basename, empty branch" {
    printf '%s\n' "$TEST_TEMP/gone/myproj" > "$HOME/.cache/ctx-project"
    run bash "$PROJECT_SH"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.project')" = "myproj" ]
    [ "$(echo "$output" | jq -r '.branch')" = "" ]
}

@test "eww-project: trims trailing newline from the recorded path" {
    mkdir -p "$TEST_TEMP/trimmed"
    printf '%s\n\n' "$TEST_TEMP/trimmed" > "$HOME/.cache/ctx-project"
    run bash "$PROJECT_SH"
    [ "$(echo "$output" | jq -r '.project')" = "trimmed" ]
}
