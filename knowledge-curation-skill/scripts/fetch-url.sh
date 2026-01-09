#!/usr/bin/env bash
# fetch-url.sh - Validate URL accessibility and extract basic info
#
# Usage:
#   ./scripts/fetch-url.sh <url>
#   ./scripts/fetch-url.sh -j|--json <url>
#
# This script validates that a URL is accessible via HTTP.
# For full metadata extraction, the agent should use:
#   - WebFetch for structured metadata (title, author, date)
#   - mcp__kagi__kagi_summarizer for content takeaways
#
# Output (JSON mode):
#   { "accessible": true, "status_code": 200, "content_type": "text/html", "url": "..." }

set -euo pipefail

usage() {
    cat <<EOF
Usage: fetch-url.sh [options] <url>

Validate URL accessibility and extract basic HTTP info.

Options:
  -j, --json    Output in JSON format
  -h, --help    Show this help message

Examples:
  ./scripts/fetch-url.sh https://example.com/article
  ./scripts/fetch-url.sh --json https://example.com/article
EOF
}

# Parse arguments
JSON_OUTPUT=false
URL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -j|--json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            URL="$1"
            shift
            ;;
    esac
done

if [[ -z "$URL" ]]; then
    echo "Error: URL is required" >&2
    usage
    exit 1
fi

# Validate URL format
if [[ ! "$URL" =~ ^https?:// ]]; then
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo '{"accessible": false, "error": "Invalid URL format - must start with http:// or https://", "url": "'"$URL"'"}'
    else
        echo "Error: Invalid URL format - must start with http:// or https://"
    fi
    exit 1
fi

# Fetch URL headers
RESPONSE=$(curl -sI -L -o /dev/null -w '%{http_code}|%{content_type}|%{url_effective}' --max-time 10 "$URL" 2>/dev/null || echo "000||$URL")

IFS='|' read -r STATUS_CODE CONTENT_TYPE FINAL_URL <<< "$RESPONSE"

# Determine accessibility
ACCESSIBLE=false
if [[ "$STATUS_CODE" =~ ^2[0-9][0-9]$ ]]; then
    ACCESSIBLE=true
fi

# Extract domain from URL
DOMAIN=$(echo "$URL" | sed -E 's|^https?://([^/]+).*|\1|')

if [[ "$JSON_OUTPUT" == "true" ]]; then
    cat <<EOF
{
  "accessible": $ACCESSIBLE,
  "status_code": $STATUS_CODE,
  "content_type": "${CONTENT_TYPE%%;}",
  "domain": "$DOMAIN",
  "url": "$URL",
  "final_url": "$FINAL_URL"
}
EOF
else
    if [[ "$ACCESSIBLE" == "true" ]]; then
        echo "URL is accessible"
        echo "  Status: $STATUS_CODE"
        echo "  Content-Type: ${CONTENT_TYPE%%;}}"
        echo "  Domain: $DOMAIN"
        if [[ "$URL" != "$FINAL_URL" ]]; then
            echo "  Redirected to: $FINAL_URL"
        fi
    else
        echo "URL is not accessible"
        echo "  Status: $STATUS_CODE"
        echo "  URL: $URL"
        exit 1
    fi
fi
