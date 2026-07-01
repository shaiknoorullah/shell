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
    export TMUX_SESSIONS="dev (3 windows) [attached]
staging (1 windows) "
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-tmux.sh)"
    assert_mock_called_with "tmux" "list-sessions"
}

@test "tmux: new session creates and attaches" {
    export TMUX_SESSIONS=""
    set_rofi_outputs "+ New Session" "my-session"
    run bash "$(get_script rofi-tmux.sh)"
    assert_mock_called_with "tmux" "new-session"
    assert_mock_called_with "notify-send" "Created session"
}

@test "tmux: kill session prompts for target" {
    export TMUX_SESSIONS="dev (3 windows) "
    set_rofi_outputs " Kill Session" "dev"
    run bash "$(get_script rofi-tmux.sh)"
    assert_mock_called_with "tmux" "kill-session"
    assert_mock_called_with "tmux" "-t dev"
}

@test "tmux: selecting session attaches via kitty (outside tmux)" {
    export TMUX_SESSIONS="dev (3 windows) "
    ROFI_MOCK_OUTPUT="dev (3 windows) "
    unset TMUX
    run bash "$(get_script rofi-tmux.sh)"
    assert_mock_called "kitty"
}

@test "tmux: selecting session switches client (inside tmux)" {
    export TMUX_SESSIONS="dev (3 windows) "
    ROFI_MOCK_OUTPUT="dev (3 windows) "
    export TMUX="/tmp/tmux-1000/default,12345,0"
    run bash "$(get_script rofi-tmux.sh)"
    assert_mock_called_with "tmux" "switch-client"
}

@test "tmux: empty selection does nothing" {
    export TMUX_SESSIONS="dev (3 windows) "
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-tmux.sh)"
    local action_calls
    action_calls=$(grep "^tmux " "$MOCK_LOG" | grep -v "list-sessions" | wc -l)
    assert_equal "$action_calls" "0"
}

@test "tmux: rofi called with tmux theme" {
    export TMUX_SESSIONS=""
    ROFI_MOCK_OUTPUT=""
    run bash "$(get_script rofi-tmux.sh)"
    assert_mock_called_with "rofi" "tmux.rasi"
}
