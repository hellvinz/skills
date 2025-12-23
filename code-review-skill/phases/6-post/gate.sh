#!/usr/bin/env bash
# Gate 6: Comments ready
# Passes if each non-skipped finding has a comment at same file:line

STATE_FILE="$1"
REVIEW_DIR="$2"
BRANCH_SAFE="$3"

comments_file="$REVIEW_DIR/comments-${BRANCH_SAFE}.json"

# Get non-skipped findings locations
findings=$(jq -r '.findings // [] | .[] | select(.status != "skipped") | "\(.file):\(.line)"' "$STATE_FILE" 2>/dev/null)

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
