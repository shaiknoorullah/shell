#!/usr/bin/env bash
#
# wikipedia-suggest.sh -- Wikipedia Article Title Suggestions API Helper
#
# Description:
#   Fetches article title suggestions from Wikipedia's official OpenSearch
#   API. Returns matching article titles (not full article content) as one
#   suggestion per line to stdout, suitable for piping into rofi or
#   rofi-blocks.
#
# API endpoint:
#   https://en.wikipedia.org/w/api.php
#   (MediaWiki API -- the same API that powers Wikipedia's search bar)
#
# Query parameters:
#   - action=opensearch : uses the OpenSearch protocol, which is a standard
#                         for search suggestions. This returns a lightweight
#                         response with just titles and URLs (no article bodies).
#   - search=<query>    : the search prefix string (URL-encoded)
#
# Response format (OpenSearch):
#   ["query", ["Title 1", "Title 2", ...], ["Description 1", ...], ["URL 1", ...]]
#   A four-element JSON array:
#     [0] = the original search query
#     [1] = array of matching article titles
#     [2] = array of short descriptions (often empty strings)
#     [3] = array of full article URLs
#   Only the titles at index [1] are extracted by this script.
#
# Parsing:
#   jq -r '.[1][]' extracts each title from the array at index 1 and prints
#   them as raw strings, one per line.
#
# Dependencies:
#   - curl    : HTTP client for the API request
#   - jq      : JSON parser to extract article titles
#   - python3 : URL-encodes the query via urllib.parse.quote_plus
#
# Parameters:
#   $1 - The search query string (plain text, will be URL-encoded)
#
# Output:
#   One article title per line to stdout. Empty output if query is empty.
#
# Usage:
#   ./wikipedia-suggest.sh "quantum"
#

query="$1"
[[ -z "$query" ]] && exit 0

# URL-encode the query to safely handle spaces and special characters
encoded=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))' "$query")

# Fetch Wikipedia article title suggestions via the OpenSearch API
curl -s "https://en.wikipedia.org/w/api.php?action=opensearch&search=${encoded}" | jq -r '.[1][]'
