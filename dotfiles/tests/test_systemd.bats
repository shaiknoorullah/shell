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
