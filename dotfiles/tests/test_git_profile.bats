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
