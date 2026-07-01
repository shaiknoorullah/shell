#!/usr/bin/env bats
# test_eww_ctx.bats — eww-ctx.sh: context name + Dracula accent as JSON.
#
# eww-ctx reads ~/.cache/ctx and maps the token to the per-context accent
# from .chezmoidata.yaml `context:`. We assert valid JSON with `.ctx` and
# `.accent` keys (via jq), the personal fallback, and the accent mapping.

setup() {
    load 'test_helper/common'
    common_setup
    CTX_SH="$BATS_TEST_DIRNAME/../private_dot_local/bin/executable_eww-ctx.sh"
    mkdir -p "$HOME/.cache"
}

teardown() {
    common_teardown
}

# ── JSON shape ────────────────────────────────────────────────

@test "eww-ctx: emits valid JSON with ctx + accent keys" {
    echo "work" > "$HOME/.cache/ctx"
    run bash "$CTX_SH"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.ctx and .accent' >/dev/null
}

@test "eww-ctx: output is parseable JSON" {
    echo "lab" > "$HOME/.cache/ctx"
    run bash "$CTX_SH"
    echo "$output" | jq -e '.' >/dev/null
}

# ── accent mapping (matches .chezmoidata.yaml context:) ───────

@test "eww-ctx: work -> purple accent" {
    echo "work" > "$HOME/.cache/ctx"
    run bash "$CTX_SH"
    [ "$(echo "$output" | jq -r '.ctx')" = "work" ]
    [ "$(echo "$output" | jq -r '.accent')" = "#bd93f9" ]
}

@test "eww-ctx: lab -> pink accent" {
    echo "lab" > "$HOME/.cache/ctx"
    run bash "$CTX_SH"
    [ "$(echo "$output" | jq -r '.accent')" = "#ff79c6" ]
}

@test "eww-ctx: agents -> cyan accent" {
    echo "agents" > "$HOME/.cache/ctx"
    run bash "$CTX_SH"
    [ "$(echo "$output" | jq -r '.accent')" = "#8be9fd" ]
}

@test "eww-ctx: personal -> green accent" {
    echo "personal" > "$HOME/.cache/ctx"
    run bash "$CTX_SH"
    [ "$(echo "$output" | jq -r '.accent')" = "#50fa7b" ]
}

# ── fallbacks (never blank) ───────────────────────────────────

@test "eww-ctx: missing ctx file falls back to personal/green" {
    rm -f "$HOME/.cache/ctx"
    run bash "$CTX_SH"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.ctx')" = "personal" ]
    [ "$(echo "$output" | jq -r '.accent')" = "#50fa7b" ]
}

@test "eww-ctx: unknown context falls back to personal/green" {
    echo "voyage" > "$HOME/.cache/ctx"
    run bash "$CTX_SH"
    [ "$(echo "$output" | jq -r '.ctx')" = "personal" ]
    [ "$(echo "$output" | jq -r '.accent')" = "#50fa7b" ]
}

@test "eww-ctx: trims whitespace/newlines from ctx token" {
    printf '  work \n' > "$HOME/.cache/ctx"
    run bash "$CTX_SH"
    [ "$(echo "$output" | jq -r '.ctx')" = "work" ]
}
