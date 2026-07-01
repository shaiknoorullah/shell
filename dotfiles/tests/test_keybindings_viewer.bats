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
