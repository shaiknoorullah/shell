#!/usr/bin/env bats

setup() {
    load 'test_helper/common'
    common_setup
}

teardown() {
    common_teardown
}

# ── Google Suggest ────────────────────────────────────────────

@test "api: google-suggest calls correct endpoint" {
    CURL_OUTPUT='["test",["test result","testing"]]'
    run bash "$(get_script apis/google-suggest.sh)" "test"
    assert_mock_called_with "curl" "suggestqueries.google.com"
}

@test "api: google-suggest passes query parameter" {
    CURL_OUTPUT='["test",["test result"]]'
    run bash "$(get_script apis/google-suggest.sh)" "hello world"
    assert_mock_called_with "curl" "q="
}

@test "api: google-suggest exits on empty query" {
    run bash "$(get_script apis/google-suggest.sh)" ""
    assert_mock_not_called "curl"
}

# ── DuckDuckGo Suggest ───────────────────────────────────────

@test "api: ddg-suggest calls correct endpoint" {
    CURL_OUTPUT='["test",["test result","testing"]]'
    run bash "$(get_script apis/ddg-suggest.sh)" "test"
    assert_mock_called_with "curl" "ac.duckduckgo.com"
}

@test "api: ddg-suggest uses type=list parameter" {
    CURL_OUTPUT='["test",["test result"]]'
    run bash "$(get_script apis/ddg-suggest.sh)" "test"
    assert_mock_called_with "curl" "type=list"
}

# ── YouTube Suggest ──────────────────────────────────────────

@test "api: youtube-suggest calls google endpoint with ds=yt" {
    CURL_OUTPUT='["test",["test video"]]'
    run bash "$(get_script apis/youtube-suggest.sh)" "test"
    assert_mock_called_with "curl" "ds=yt"
}

# ── Wikipedia Suggest ────────────────────────────────────────

@test "api: wikipedia-suggest calls opensearch API" {
    CURL_OUTPUT='["test",["Test page"]]'
    run bash "$(get_script apis/wikipedia-suggest.sh)" "test"
    assert_mock_called_with "curl" "action=opensearch"
}

@test "api: wikipedia-suggest exits on empty query" {
    run bash "$(get_script apis/wikipedia-suggest.sh)" ""
    assert_mock_not_called "curl"
}
