#!/usr/bin/env bats
# test_start.bats — Task 5: start ritual (pick → focus → context)

setup() {
    load 'test_helper/common'
    common_setup
    export TASK_BIN=task

    # The start script under test (chezmoi source path).
    START_SCRIPT="$TESTS_DIR/../private_dot_local/bin/executable_adhd-start.sh"
    export START_SCRIPT

    # Drop a mock adhd-focus.sh into the injected mocks dir so the start
    # script (which calls it via PATH, not an absolute path) resolves to a
    # mock that logs to $MOCK_LOG.
    cat > "$MOCKS_DIR/adhd-focus.sh" <<'EOF'
#!/usr/bin/env bash
echo "adhd-focus.sh $*" >> "$MOCK_LOG"
EOF
    chmod +x "$MOCKS_DIR/adhd-focus.sh"
}

teardown() {
    rm -f "$MOCKS_DIR/adhd-focus.sh"
    common_teardown
}

@test "start: selecting a task starts a focus block via adhd-focus.sh" {
    set_rofi_outputs "1 boolgen otel"
    run bash "$START_SCRIPT"
    assert_mock_called_with "adhd-focus.sh" "start"
}

@test "start: selecting a task invokes adhd-focus.sh start with the id" {
    set_rofi_outputs "1 boolgen otel"
    run bash "$START_SCRIPT"
    assert_mock_called_with "adhd-focus.sh" "start 1"
}

@test "start: empty selection starts nothing" {
    set_rofi_outputs ""
    run bash "$START_SCRIPT"
    assert_mock_not_called "adhd-focus.sh"
}
