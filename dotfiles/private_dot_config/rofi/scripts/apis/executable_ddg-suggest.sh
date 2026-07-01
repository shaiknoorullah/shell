#!/usr/bin/env bash
#
# ddg-suggest.sh -- DuckDuckGo Autocomplete Suggestions API Helper
#
# Description:
#   Fetches search autocomplete suggestions from DuckDuckGo's public
#   autocomplete API. Returns one suggestion per line to stdout, suitable
#   for piping into rofi or rofi-blocks.
#
# API endpoint:
#   https://ac.duckduckgo.com/ac/
#
# Query parameters:
#   - q=<query>   : the search query string (URL-encoded)
#   - type=list   : requests the response in OpenSearch Suggestion format
#                   (a JSON array), rather than the default format which
#                   returns an array of objects with {phrase: "..."} keys.
#                   The "list" format matches the same structure as Google's
#                   firefox-client format, making the jq parsing identical.
#
# Response format (type=list):
#   ["original query", ["suggestion 1", "suggestion 2", ...]]
#   A JSON array where index [0] is the original query and index [1] is an
#   array of suggestion strings.
#
# Parsing:
#   jq -r '.[1][]' extracts each suggestion from the array at index 1
#   and prints them as raw strings, one per line.
#
# Dependencies:
#   - curl    : HTTP client for the API request
#   - jq      : JSON parser to extract suggestions
#   - python3 : URL-encodes the query via urllib.parse.quote_plus
#
# Parameters:
#   $1 - The search query string (plain text, will be URL-encoded)
#
# Output:
#   One suggestion per line to stdout. Empty output if query is empty.
#
# Usage:
#   ./ddg-suggest.sh "how to"
#

query="$1"
[[ -z "$query" ]] && exit 0

# URL-encode the query to safely handle spaces and special characters
encoded=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))' "$query")

# Fetch suggestions and extract the suggestion strings from the JSON response
curl -s "https://ac.duckduckgo.com/ac/?q=${encoded}&type=list" | jq -r '.[1][]'
