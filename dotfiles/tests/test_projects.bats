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

@test "projects: detects Go project icon" {
    mkdir -p "$HOME/work/myapi"
    touch "$HOME/work/myapi/go.mod"
    # Source the function by extracting it, then call directly
    source <(sed -n '/^get_project_icon/,/^}/p' "$(get_script rofi-projects.sh)")
    run get_project_icon "$HOME/work/myapi"
    assert_output "󰟓"
}

@test "projects: detects Node project icon" {
    mkdir -p "$HOME/work/webapp"
    touch "$HOME/work/webapp/package.json"
    source <(sed -n '/^get_project_icon/,/^}/p' "$(get_script rofi-projects.sh)")
    run get_project_icon "$HOME/work/webapp"
    assert_output ""
}

@test "projects: detects Rust project icon" {
    mkdir -p "$HOME/work/cli-tool"
    touch "$HOME/work/cli-tool/Cargo.toml"
    source <(sed -n '/^get_project_icon/,/^}/p' "$(get_script rofi-projects.sh)")
    run get_project_icon "$HOME/work/cli-tool"
    assert_output ""
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
