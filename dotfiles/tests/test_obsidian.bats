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

# -- Quick Actions (rofi-obsidian.sh) --

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

# -- Note Search (rofi-obsidian-search.sh) --

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

# -- Note Create (rofi-obsidian-create.sh) --

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
