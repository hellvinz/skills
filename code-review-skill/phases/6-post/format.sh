#!/usr/bin/env bash
# Format context for Phase 6: POST

STATE_FILE="$1"
REVIEW_DIR="${STATE_FILE%/*}"
BRANCH_SAFE=$(jq -r '.branch' "$STATE_FILE" | tr '/' '-')

echo "=== Phase 6: POST ==="
echo ""

# Findings summary
addressed=$(jq '[.findings // [] | .[] | select(.status == "addressed")] | length' "$STATE_FILE")
skipped=$(jq '[.findings // [] | .[] | select(.status == "skipped")] | length' "$STATE_FILE")

echo "Findings: $addressed addressed, $skipped skipped"

# Comments
comments_file="$REVIEW_DIR/comments-${BRANCH_SAFE}.json"
if [[ -f "$comments_file" ]]; then
  comment_count=$(jq '.comments | length' "$comments_file")
  echo "Comments ready: $comment_count"
  echo ""
  echo "Comments:"
  jq -r '.comments[] | "  \(.path):\(.line) - \(.body | .[0:50])..."' "$comments_file"
else
  echo "Comments: none"
fi

echo ""
echo "Post with: post-comments.sh"
