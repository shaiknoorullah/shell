#!/usr/bin/env bash
#
# run_tests.sh — Runs the complete rofi test suite
#
# Usage:
#   ./run_tests.sh              # Run all tests
#   ./run_tests.sh test_power   # Run specific test file
#   ./run_tests.sh -v           # Verbose output

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check BATS is installed
if ! command -v bats &> /dev/null; then
    echo "ERROR: bats not found. Install with: sudo apt install bats"
    exit 1
fi

# Check bats-support/bats-assert are installed
if [[ ! -d "$TESTS_DIR/test_helper/bats-support" ]]; then
    echo "Installing bats-support..."
    git clone --depth 1 https://github.com/bats-core/bats-support.git \
        "$TESTS_DIR/test_helper/bats-support"
fi

if [[ ! -d "$TESTS_DIR/test_helper/bats-assert" ]]; then
    echo "Installing bats-assert..."
    git clone --depth 1 https://github.com/bats-core/bats-assert.git \
        "$TESTS_DIR/test_helper/bats-assert"
fi

# Run tests
if [[ $# -gt 0 ]]; then
    if [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
        bats --verbose-run "$TESTS_DIR"/test_*.bats
    elif [[ -f "$TESTS_DIR/${1}.bats" ]]; then
        bats "$TESTS_DIR/${1}.bats"
    elif [[ -f "$TESTS_DIR/$1" ]]; then
        bats "$TESTS_DIR/$1"
    else
        echo "Test file not found: $1"
        exit 1
    fi
else
    echo "Running all rofi tests..."
    echo "========================="
    bats "$TESTS_DIR"/test_*.bats
    echo ""
    echo "All tests complete."
fi
