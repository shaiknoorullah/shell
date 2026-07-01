#!/usr/bin/env bash
#
# google-suggest.sh -- Google Autocomplete Suggestions API Helper
#
# Description:
#   Fetches search autocomplete suggestions from Google's undocumented
#   suggestions API. Returns one suggestion per line to stdout, suitable
#   for piping into rofi or rofi-blocks.
#
# API endpoint:
#   https://suggestqueries.google.com/complete/search
#
# Query parameters:
#   - client=firefox : requests the response in JSON array format (as
#                      opposed to client=chrome which returns a different
#                      structure, or JSONP for other clients). The "firefox"
#                      client format returns a clean two-element JSON array.
#   - q=<query>      : the search query string (URL-encoded)
#
# Response format (client=firefox):
#   ["original query", ["suggestion 1", "suggestion 2", ...]]
#   A JSON array where index [0] is the original query string and index [1]
#   is an array of suggestion strings.
#
# Parsing:
#   jq -r '.[1][]' extracts each element from the suggestions array (index 1)
#   and prints them as raw strings, one per line.
#
# Dependencies:
#   - curl    : HTTP client for the API request
#   - jq      : JSON parser to extract suggestions from the response
#   - python3 : URL-encodes the query via urllib.parse.quote_plus
#
# Parameters:
#   $1 - The search query string (plain text, will be URL-encoded)
#
# Output:
#   One suggestion per line to stdout. Empty output if query is empty.
#
# Usage:
#   ./google-suggest.sh "how to"
#

query="$1"
[[ -z "$query" ]] && exit 0

# URL-encode the query to safely handle spaces and special characters
encoded=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))' "$query")

# Fetch suggestions and extract the suggestion strings from the JSON response
curl -s "https://suggestqueries.google.com/complete/search?client=firefox&q=${encoded}" | jq -r '.[1][]'
