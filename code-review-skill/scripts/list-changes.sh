#!/usr/bin/env bash
# list-changes.sh - List changed files with metadata for review iteration

# Relaunch as user's login shell to get aliases (e.g., gh with pass-cli)
if [ -z "$_LOGIN_SHELL_SOURCED" ]; then
  export _LOGIN_SHELL_SOURCED=1
  "$SHELL" -l "$0" "$@" 2>&1 | sed $'s/\x1b][0-9]*;[^\x07]*\x07//g'
  exit $?
fi

set -e

JSON_MODE=false
FILTER=""
BASE_BRANCH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --json) JSON_MODE=true; shift ;;
    --filter) FILTER="$2"; shift 2 ;;
    --base) BASE_BRANCH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$BASE_BRANCH" ]; then
  echo "Error: --base <branch> is required" >&2
  echo "Usage: list-changes.sh --base <branch> [--json] [--filter ts,tsx]" >&2
  exit 1
fi

# Get list of changed files with status
# A=Added, M=Modified, D=Deleted, R=Renamed, C=Copied
FILES=$(git diff "origin/$BASE_BRANCH...HEAD" --name-status --diff-filter=ACMR 2>/dev/null)

# Apply filter if specified (e.g., "ts,tsx,js,jsx")
if [ -n "$FILTER" ]; then
  PATTERN="${FILTER//,/|}"
  FILES=$(echo "$FILES" | grep -E "\.($PATTERN)$" || true)
fi

if $JSON_MODE; then
  echo "{"
  echo "  \"base_branch\": \"$BASE_BRANCH\","
  echo '  "files": ['

  FIRST=true
  while IFS=$'\t' read -r fstatus file; do
    [ -z "$file" ] && continue

    # Get line counts for this file
    STATS=$(git diff "origin/$BASE_BRANCH...HEAD" --numstat -- "$file" 2>/dev/null | head -1)
    ADDED=$(echo "$STATS" | awk '{print $1}')
    DELETED=$(echo "$STATS" | awk '{print $2}')

    # Determine file type
    EXT="${file##*.}"

    if ! $FIRST; then echo ","; fi
    FIRST=false

    cat <<EOF
    {
      "path": "$file",
      "status": "$fstatus",
      "extension": "$EXT",
      "added": ${ADDED:-0},
      "deleted": ${DELETED:-0}
    }
EOF
  done <<< "$FILES"

  echo ""
  echo "  ]"
  echo "}"
else
  echo "=== CHANGED FILES ==="
  echo "Base: origin/$BASE_BRANCH"
  echo ""

  TOTAL_ADDED=0
  TOTAL_DELETED=0

  while IFS=$'\t' read -r fstatus file; do
    [ -z "$file" ] && continue

    STATS=$(git diff "origin/$BASE_BRANCH...HEAD" --numstat -- "$file" 2>/dev/null | head -1)
    ADDED=$(echo "$STATS" | awk '{print $1}')
    DELETED=$(echo "$STATS" | awk '{print $2}')

    TOTAL_ADDED=$((TOTAL_ADDED + ${ADDED:-0}))
    TOTAL_DELETED=$((TOTAL_DELETED + ${DELETED:-0}))

    case $fstatus in
      A) STATUS_LABEL="[NEW]" ;;
      M) STATUS_LABEL="[MOD]" ;;
      R) STATUS_LABEL="[REN]" ;;
      C) STATUS_LABEL="[CPY]" ;;
      *) STATUS_LABEL="[$fstatus]" ;;
    esac

    printf "%-6s %s (+%s/-%s)\n" "$STATUS_LABEL" "$file" "${ADDED:-0}" "${DELETED:-0}"
  done <<< "$FILES"

  echo ""
  echo "=== SUMMARY ==="
  FILE_COUNT=$(echo "$FILES" | grep -c '.' || echo "0")
  echo "Files: $FILE_COUNT"
  echo "Total: +$TOTAL_ADDED / -$TOTAL_DELETED"
fi
