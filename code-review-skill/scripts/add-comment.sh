#!/usr/bin/env bash
# add-comment.sh - Add a review comment to .review/comments-{branch}.json
# Usage: add-comment.sh <path> <line> <body>
#        add-comment.sh --list
#        add-comment.sh --clear
#
# Note: No login shell needed - this script only uses git, jq, mktemp

set -euo pipefail

REVIEW_DIR=".review"
BRANCH=$(git branch --show-current)
BRANCH_SAFE="${BRANCH//\//-}"
COMMENTS_FILE="$REVIEW_DIR/comments-${BRANCH_SAFE}.json"

# Ensure review dir exists
mkdir -p "$REVIEW_DIR"

# Initialize file if missing
init_file() {
    if [[ ! -f "$COMMENTS_FILE" ]]; then
        echo '{"comments":[]}' > "$COMMENTS_FILE"
    fi
}

# List all comments
list_comments() {
    init_file
    local count
    count=$(jq '.comments | length' "$COMMENTS_FILE")
    echo "Comments in $COMMENTS_FILE ($count):"
    echo ""
    jq -r '.comments | to_entries[] | "[\(.key + 1)] \(.value.path):\(.value.line)\n    \(.value.body)\n"' "$COMMENTS_FILE"
}

# Clear all comments
clear_comments() {
    echo '{"comments":[]}' > "$COMMENTS_FILE"
    echo "Cleared $COMMENTS_FILE"
}

# Remove a comment by index (1-based)
remove_comment() {
    local idx=$1
    local zero_idx=$((idx - 1))

    init_file
    local count
    count=$(jq '.comments | length' "$COMMENTS_FILE")

    if [[ $idx -lt 1 || $idx -gt $count ]]; then
        echo "Invalid index: $idx (have $count comments)" >&2
        exit 1
    fi

    local tmp
    tmp=$(mktemp)
    jq "del(.comments[$zero_idx])" "$COMMENTS_FILE" > "$tmp" && mv "$tmp" "$COMMENTS_FILE"
    echo "Removed comment $idx"
}

# Add a comment
add_comment() {
    local path="$1"
    local line="$2"
    local body="$3"

    # Validate
    if [[ -z "$path" || -z "$line" || -z "$body" ]]; then
        echo "Usage: add-comment.sh <path> <line> <body>" >&2
        exit 1
    fi

    if ! [[ "$line" =~ ^[0-9]+$ ]]; then
        echo "Line must be a number: $line" >&2
        exit 1
    fi

    init_file

    # Add comment using jq
    local tmp
    tmp=$(mktemp)
    jq --arg path "$path" --argjson line "$line" --arg body "$body" \
        '.comments += [{"path": $path, "line": $line, "body": $body}]' \
        "$COMMENTS_FILE" > "$tmp" && mv "$tmp" "$COMMENTS_FILE"

    local count
    count=$(jq '.comments | length' "$COMMENTS_FILE")
    echo "Added comment [$count]: $path:$line"
}

# Main
case "${1:-}" in
    --list|-l)
        list_comments
        ;;
    --clear)
        clear_comments
        ;;
    --remove|-r)
        remove_comment "${2:-}"
        ;;
    --help|-h)
        echo "Usage:"
        echo "  add-comment.sh <path> <line> <body>  Add a comment"
        echo "  add-comment.sh --list                List all comments"
        echo "  add-comment.sh --remove <N>          Remove comment N"
        echo "  add-comment.sh --clear               Clear all comments"
        ;;
    *)
        if [[ $# -lt 3 ]]; then
            echo "Usage: add-comment.sh <path> <line> <body>" >&2
            exit 1
        fi
        add_comment "$1" "$2" "$3"
        ;;
esac
