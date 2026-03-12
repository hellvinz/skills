#!/usr/bin/env bash
# Gate 6: Comments ready
# Passes if each "commented" finding has a comment at same file:line

STATE_FILE="$1"
REVIEW_DIR=".review"
BRANCH=$(jq -r '.branch // ""' "$STATE_FILE")
BRANCH_SAFE="${BRANCH//\//-}"

comments_file="$REVIEW_DIR/comments-${BRANCH_SAFE}.json"

# Get "commented" findings locations (skipped and addressed don't need comments)
findings=$(jq -r '.findings // [] | .[] | select(.status == "commented") | "\(.file):\(.line)"' "$STATE_FILE" 2>/dev/null)

# No findings = pass
[[ -z "$findings" ]] && exit 0

# Need comments file
if [[ ! -f "$comments_file" ]]; then
  echo "  Need: comments file ($comments_file)" >&2
  exit 1
fi

# Get comment locations
comments=$(jq -r '.comments[] | "\(.path):\(.line)"' "$comments_file" 2>/dev/null)

# Check each finding has a comment
while IFS= read -r loc; do
  [[ -z "$loc" ]] && continue
  if ! echo "$comments" | grep -qF "$loc"; then
    echo "  Need: comment for $loc" >&2
    exit 1
  fi
done <<< "$findings"

exit 0
