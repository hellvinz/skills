#!/usr/bin/env bash
# get-reviews.sh - Get PR review comments and commit messages

# Relaunch as user's login shell to get aliases (e.g., gh with pass-cli)
if [ -z "$_LOGIN_SHELL_SOURCED" ]; then
  export _LOGIN_SHELL_SOURCED=1
  "$SHELL" -l "$0" "$@" 2>&1 | sed $'s/\x1b][0-9]*;[^\x07]*\x07//g'
  exit $?
fi

set -e

JSON_MODE=false
BASE_BRANCH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --json) JSON_MODE=true; shift ;;
    --base) BASE_BRANCH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$BASE_BRANCH" ]; then
  echo "Error: --base <branch> is required" >&2
  exit 1
fi

# Get PR reviews if PR exists
PR_EXISTS=false
REVIEWS=""
COMMENTS=""

if gh pr view &>/dev/null; then
  PR_EXISTS=true
  REVIEWS=$(gh pr view --json reviews --jq '.reviews[] | "[\(.author.login)] \(.state): \(.body)"' 2>/dev/null || echo "")
  COMMENTS=$(gh pr view --json comments --jq '.comments[] | "[\(.author.login)]: \(.body)"' 2>/dev/null || echo "")
fi

# Get commit messages
COMMITS=$(git log "origin/$BASE_BRANCH..HEAD" --format="--- %h ---
%s
%b" 2>/dev/null || echo "")

if $JSON_MODE; then
  # Helper to escape JSON strings
  json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || \
    jq -Rs '.' 2>/dev/null || \
    echo '""'
  }

  cat <<EOF
{
  "pr_exists": $PR_EXISTS,
  "reviews": $(echo "$REVIEWS" | json_escape),
  "comments": $(echo "$COMMENTS" | json_escape),
  "commits": $(echo "$COMMITS" | json_escape)
}
EOF
else
  echo "=== COMMIT MESSAGES ==="
  if [ -n "$COMMITS" ]; then
    echo "$COMMITS"
  else
    echo "No commits found."
  fi
  echo ""

  if $PR_EXISTS; then
    echo "=== PR REVIEWS ==="
    if [ -n "$REVIEWS" ]; then
      echo "$REVIEWS"
    else
      echo "No reviews yet."
    fi
    echo ""

    echo "=== PR COMMENTS ==="
    if [ -n "$COMMENTS" ]; then
      echo "$COMMENTS"
    else
      echo "No comments."
    fi
  else
    echo "=== PR ==="
    echo "No PR found for this branch."
  fi
fi
