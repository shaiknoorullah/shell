#!/usr/bin/env bash
#
# youtube-suggest.sh -- YouTube Search Suggestions API Helper
#
# Description:
#   Fetches YouTube-specific search autocomplete suggestions. Uses Google's
#   suggestions API with the ds=yt parameter to scope results to YouTube
#   content rather than general web search. Returns one suggestion per line
#   to stdout, suitable for piping into rofi or rofi-blocks.
#
# API endpoint:
#   https://suggestqueries.google.com/complete/search
#   (Same endpoint as Google web search, but scoped to YouTube via ds=yt)
#
# Query parameters:
#   - client=firefox : requests JSON array response format
#   - ds=yt          : "data source = YouTube" -- restricts suggestions to
#                      YouTube search queries rather than general Google web
#                      search. This is the key parameter that differentiates
#                      this script from google-suggest.sh.
#   - q=<query>      : the search query string (URL-encoded)
#
# Response format:
#   ["original query", ["suggestion 1", "suggestion 2", ...]]
#   Identical structure to the Google web suggestions response.
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
#   ./youtube-suggest.sh "lofi beats"
#

query="$1"
[[ -z "$query" ]] && exit 0

# URL-encode the query to safely handle spaces and special characters
encoded=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))' "$query")

# Fetch YouTube-scoped suggestions (ds=yt) and extract suggestion strings
curl -s "https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=${encoded}" | jq -r '.[1][]'
