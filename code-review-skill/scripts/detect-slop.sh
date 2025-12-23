#!/usr/bin/env bash
# detect-slop.sh - Detect LLM slop patterns in code changes

# Relaunch as user's login shell to get aliases (e.g., gh with pass-cli)
if [ -z "$_LOGIN_SHELL_SOURCED" ]; then
  export _LOGIN_SHELL_SOURCED=1
  # Run in login shell and filter terminal escape sequences
  "$SHELL" -l "$0" "$@" 2>&1 | sed $'s/\x1b][0-9]*;[^\x07]*\x07//g'
  exit $?
fi

set -e

# Parse arguments
BASE_BRANCH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --base) BASE_BRANCH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$BASE_BRANCH" ]; then
  echo "Error: --base <branch> is required" >&2
  exit 1
fi

echo "=== SLOP DETECTION REPORT ==="
echo ""

# Get the diff content
DIFF_CONTENT=$(git diff "origin/$BASE_BRANCH...HEAD" 2>/dev/null || echo "")
CHANGED_FILES=$(git diff "origin/$BASE_BRANCH...HEAD" --name-only 2>/dev/null | grep -E '\.(ts|tsx|js|jsx)$' || echo "")

if [ -z "$DIFF_CONTENT" ]; then
  echo "No changes found."
  exit 0
fi

# 1. Useless comments in diff
echo "## Useless Comments (in new code)"
echo ""

echo "### 'Get/Set/Return' style comments"
GETSET=$(echo "$DIFF_CONTENT" | \
  grep -cE '^\+.*//\s*(Get|Set|Return|Loop|Check|If|Create|Update|Delete|Handle|Process)\s+\w+' 2>/dev/null || echo "0")
GETSET="${GETSET##*$'\n'}"  # Keep only last line
echo "Found: $GETSET occurrences"

if [ "$GETSET" -gt 0 ] 2>/dev/null; then
  echo "$DIFF_CONTENT" | \
    grep -E '^\+.*//\s*(Get|Set|Return|Loop|Check|If|Create|Update|Delete|Handle|Process)\s+\w+' | \
    head -5
  echo "..."
fi
echo ""

echo "### 'This function/method' comments"
THISFUNC=$(echo "$DIFF_CONTENT" | \
  grep -cE '^\+.*//\s*(This function|This method|This class|This variable)' 2>/dev/null || echo "0")
THISFUNC="${THISFUNC##*$'\n'}"
echo "Found: $THISFUNC occurrences"

if [ "$THISFUNC" -gt 0 ] 2>/dev/null; then
  echo "$DIFF_CONTENT" | \
    grep -E '^\+.*//\s*(This function|This method|This class|This variable)' | \
    head -5
  echo "..."
fi
echo ""

# 2. Over-engineering patterns
echo "## Potential Over-Engineering"
echo ""

echo "### Single-use helpers/utils"
# Files with 'helper' or 'util' in name that are only imported once
HELPER_FILES=$(echo "$CHANGED_FILES" | grep -iE '(helper|util)' || echo "")
if [ -n "$HELPER_FILES" ]; then
  for f in $HELPER_FILES; do
    IMPORT_COUNT=$(rg -l "from.*$f" --type ts 2>/dev/null | wc -l | tr -d ' ')
    if [ "$IMPORT_COUNT" -le 1 ]; then
      echo "⚠️ $f - imported $IMPORT_COUNT time(s)"
    fi
  done
else
  echo "None found in changed files"
fi
echo ""

echo "### Interfaces with single implementation"
# New interfaces that might be premature
INTERFACES=$(echo "$DIFF_CONTENT" | grep -E '^\+.*interface\s+I[A-Z]' | head -5 || echo "")
if [ -n "$INTERFACES" ]; then
  echo "$INTERFACES"
else
  echo "None found in diff"
fi
echo ""

# 3. Commit message slop
echo "## Commit Message Issues"
echo ""

echo "### Messages with implementation details"
COMMITS=$(git log "origin/$BASE_BRANCH..HEAD" --format="%h %s" 2>/dev/null || echo "")

if [ -n "$COMMITS" ]; then
  echo "$COMMITS" | while read -r line; do
    # Check for slop patterns
    if echo "$line" | grep -qiE '(by changing|by updating|by adding|by removing|by modifying)'; then
      echo "⚠️ $line"
    fi
    # Check for code in message
    if echo "$line" | grep -qE '[\(\)\{\}\[\]].*[\(\)\{\}\[\]]'; then
      echo "⚠️ $line (contains code-like patterns)"
    fi
  done
fi
echo ""

# 4. Architecture smells (only in changed files)
echo "## Architecture Smells"
echo ""

# Filter changed files to UI components
UI_CHANGED=$(echo "$CHANGED_FILES" | grep -E '(components|pages)/' || echo "")

if [ -n "$UI_CHANGED" ]; then
  echo "### Direct fetch in UI components"
  FETCH_IN_UI=0
  for f in $UI_CHANGED; do
    if [ -f "$f" ] && grep -qE 'fetch\(|axios\.' "$f" 2>/dev/null; then
      echo "⚠️ $f"
      FETCH_IN_UI=$((FETCH_IN_UI + 1))
    fi
  done
  [ "$FETCH_IN_UI" -eq 0 ] && echo "None found in changed files"
  echo ""

  echo "### Service imports in UI"
  SVC_IN_UI=0
  for f in $UI_CHANGED; do
    if [ -f "$f" ] && grep -qE 'import.*from.*(services|api)/' "$f" 2>/dev/null; then
      echo "⚠️ $f"
      SVC_IN_UI=$((SVC_IN_UI + 1))
    fi
  done
  [ "$SVC_IN_UI" -eq 0 ] && echo "None found in changed files"
else
  echo "### Direct fetch in UI components"
  echo "No UI files changed"
  echo ""
  echo "### Service imports in UI"
  echo "No UI files changed"
  FETCH_IN_UI=0
  SVC_IN_UI=0
fi
echo ""

# Summary
echo "=== SUMMARY ==="
TOTAL_SLOP=$((GETSET + THISFUNC))
echo "Comment slop: $TOTAL_SLOP"
echo "Architecture smells: $((FETCH_IN_UI + SVC_IN_UI))"
echo ""

if [ "$TOTAL_SLOP" -gt 5 ]; then
  echo "⚠️ HIGH slop level detected - consider cleanup pass"
elif [ "$TOTAL_SLOP" -gt 0 ]; then
  echo "⚡ Some slop detected - minor cleanup recommended"
else
  echo "✓ No obvious slop patterns found"
fi
