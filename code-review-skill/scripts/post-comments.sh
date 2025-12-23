#!/usr/bin/env bash
# post-comments.sh - Post review comments from .review/comments-{branch}.json
# Usage: post-comments.sh [--dry-run]

# Relaunch as user's login shell to get aliases (e.g., gh with pass-cli)
if [ -z "$_LOGIN_SHELL_SOURCED" ]; then
  export _LOGIN_SHELL_SOURCED=1
  "$SHELL" -l "$0" "$@" 2>&1 | sed $'s/\x1b][0-9]*;[^\x07]*\x07//g'
  exit $?
fi

set -euo pipefail

REVIEW_DIR=".review"
DRY_RUN=false

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Get current branch (sanitize for filename)
BRANCH=$(git branch --show-current)
BRANCH_SAFE="${BRANCH//\//-}"
COMMENTS_FILE="$REVIEW_DIR/comments-${BRANCH_SAFE}.json"

if [[ ! -f "$COMMENTS_FILE" ]]; then
    echo "No comments file found: $COMMENTS_FILE" >&2
    exit 1
fi

# Get PR info
PR_JSON=$(gh pr view --json number,headRefOid 2>/dev/null || echo "{}")
PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number // empty')

if [[ -z "$PR_NUMBER" ]]; then
    echo "No PR found for branch $BRANCH" >&2
    exit 1
fi

COMMIT_ID=$(echo "$PR_JSON" | jq -r '.headRefOid')
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')

# Get the diff and build a position map using awk
DIFF_FILE=$(mktemp)
POSITION_MAP=$(mktemp)
trap 'rm -f "$DIFF_FILE" "$POSITION_MAP"' EXIT

gh pr diff "$PR_NUMBER" > "$DIFF_FILE"

# Build position map: file:line -> position
# Position = line number in the diff starting from 1 after each @@ header
gawk '
/^diff --git/ {
    current_file = ""
    position = 0
    in_hunk = 0
}
/^\+\+\+ b\// {
    current_file = substr($0, 7)
}
/^@@ / {
    # Parse hunk header: @@ -old,count +new,count @@
    match($0, /\+([0-9]+)/, arr)
    current_line = arr[1] + 0
    position++
    in_hunk = 1
    next
}
/^---/ { next }
{
    if (in_hunk && current_file != "") {
        position++
        c = substr($0, 1, 1)
        if (c == "+" || c == " ") {
            print current_file ":" current_line ":" position
            current_line++
        }
    }
}
' "$DIFF_FILE" > "$POSITION_MAP"

# Read comments and build review payload
COMMENT_COUNT=$(jq '.comments | length' "$COMMENTS_FILE")

if [[ "$COMMENT_COUNT" -eq 0 ]]; then
    echo "No comments to post"
    exit 0
fi

echo "Preparing $COMMENT_COUNT comment(s) for PR #$PR_NUMBER..."
echo ""

# Build payload file with positions
PAYLOAD_FILE=$(mktemp)
GENERAL_COMMENTS=$(mktemp)
trap 'rm -f "$DIFF_FILE" "$POSITION_MAP" "$PAYLOAD_FILE" "$GENERAL_COMMENTS"' EXIT

echo '{"comments":[]}' > "$PAYLOAD_FILE"
echo "" > "$GENERAL_COMMENTS"
INLINE_COUNT=0
GENERAL_COUNT=0

for i in $(seq 0 $((COMMENT_COUNT - 1))); do
    PATH_VAL=$(jq -r ".comments[$i].path" "$COMMENTS_FILE")
    LINE_VAL=$(jq -r ".comments[$i].line" "$COMMENTS_FILE")

    # Lookup position in map
    POSITION=$(grep "^${PATH_VAL}:${LINE_VAL}:" "$POSITION_MAP" | cut -d: -f3 | head -1)

    # Preview (truncate body for display)
    BODY_PREVIEW=$(jq -r ".comments[$i].body" "$COMMENTS_FILE" | head -1 | cut -c1-70)
    echo "[$((i+1))/$COMMENT_COUNT] $PATH_VAL:$LINE_VAL"
    echo "  > $BODY_PREVIEW..."

    if [[ -z "$POSITION" ]]; then
        echo "  → general comment (not in diff)"
        ((GENERAL_COUNT++)) || true
        # Add to general comments body
        BODY_FULL=$(jq -r ".comments[$i].body" "$COMMENTS_FILE")
        {
            echo "**\`$PATH_VAL:$LINE_VAL\`**"
            echo "$BODY_FULL"
            echo ""
        } >> "$GENERAL_COMMENTS"
        continue
    fi

    echo "  → inline (position=$POSITION)"
    ((INLINE_COUNT++)) || true

    # Add comment with position to payload
    jq --argjson pos "$POSITION" \
       --argjson idx "$i" \
       --slurpfile src "$COMMENTS_FILE" \
       '.comments += [($src[0].comments[$idx] | {path, body, position: $pos})]' \
       "$PAYLOAD_FILE" > "${PAYLOAD_FILE}.tmp" && mv "${PAYLOAD_FILE}.tmp" "$PAYLOAD_FILE"
done

echo ""
echo "Ready: $INLINE_COUNT inline, $GENERAL_COUNT general"

if [[ "$INLINE_COUNT" -eq 0 && "$GENERAL_COUNT" -eq 0 ]]; then
    echo "No comments to post"
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "=== Inline comments ==="
    jq . "$PAYLOAD_FILE"
    if [[ "$GENERAL_COUNT" -gt 0 ]]; then
        echo ""
        echo "=== General comments (in review body) ==="
        cat "$GENERAL_COMMENTS"
    fi
    exit 0
fi

# Submit review with all comments
echo ""
echo "Submitting review..."

# Build final payload with body (general comments) + inline comments
GENERAL_BODY=$(cat "$GENERAL_COMMENTS")
jq --arg commit_id "$COMMIT_ID" \
   --arg body "$GENERAL_BODY" \
   '. + {commit_id: $commit_id, event: "COMMENT", body: $body}' \
    "$PAYLOAD_FILE" > "${PAYLOAD_FILE}.final"

RESPONSE=$(gh api "repos/$REPO/pulls/$PR_NUMBER/reviews" \
    --input "${PAYLOAD_FILE}.final" \
    2>&1) && RESULT=$? || RESULT=$?

rm -f "${PAYLOAD_FILE}.final"

if [[ $RESULT -eq 0 ]]; then
    REVIEW_ID=$(echo "$RESPONSE" | jq -r '.id // "unknown"')
    echo "Review submitted (ID: $REVIEW_ID)"
    echo "Done: $FINAL_COUNT comments posted"
else
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // .errors[0].message // "Unknown error"' 2>/dev/null || echo "$RESPONSE")
    echo "FAILED: $ERROR_MSG"
    exit 1
fi
