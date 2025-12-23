#!/usr/bin/env bash
# gather-context.sh - Collect all context needed for code review

# Relaunch as user's login shell to get aliases (e.g., gh with pass-cli)
if [ -z "$_LOGIN_SHELL_SOURCED" ]; then
  export _LOGIN_SHELL_SOURCED=1
  "$SHELL" -l "$0" "$@" 2>&1 | sed $'s/\x1b][0-9]*;[^\x07]*\x07//g'
  exit $?
fi

set -e

JSON_MODE=false
[[ "$1" == "--json" ]] && JSON_MODE=true

# Determine branches
CURRENT_BRANCH=$(git branch --show-current)

# Try PR base first (most accurate), then repo default
PR_BASE=$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null || true)
REPO_DEFAULT=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "main")
BASE_BRANCH="${PR_BASE:-$REPO_DEFAULT}"

# Detect ticket ID
TICKET_ID=$(echo "$CURRENT_BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1)
if [ -z "$TICKET_ID" ]; then
  TICKET_ID=$(git log "origin/$BASE_BRANCH..HEAD" --format="%s %b" 2>/dev/null | grep -oE '[A-Z]+-[0-9]+' | head -1)
fi

# Check for feature branch
IS_FEATURE_BRANCH=false
if [[ "$CURRENT_BRANCH" =~ ^[A-Z]+-[0-9]+ ]] || [[ "$CURRENT_BRANCH" =~ ^(feature|fix|feat|bugfix|hotfix)/ ]]; then
  IS_FEATURE_BRANCH=true
fi

# Project context
HAS_CLAUDE_MD=false
HAS_AGENTS_MD=false
HAS_ARCHITECTURE_MD=false
ADR_COUNT=0

[ -f CLAUDE.md ] && HAS_CLAUDE_MD=true
[ -f AGENTS.md ] && HAS_AGENTS_MD=true
[ -f ARCHITECTURE.md ] && HAS_ARCHITECTURE_MD=true
[ -d docs/adr ] && ADR_COUNT=$(find docs/adr -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

# PR info
PR_NUMBER=""
PR_STATE=""
CI_STATUS=""
if gh pr view --json number,state,statusCheckRollup &>/dev/null; then
  PR_INFO=$(gh pr view --json number,state,statusCheckRollup)
  PR_NUMBER=$(echo "$PR_INFO" | jq -r '.number')
  PR_STATE=$(echo "$PR_INFO" | jq -r '.state')
  CI_STATUS=$(echo "$PR_INFO" | jq -r '.statusCheckRollup[0].conclusion // "pending"')
fi

# Commit count
COMMIT_COUNT=$(git rev-list --count "origin/$BASE_BRANCH..HEAD" 2>/dev/null || echo "0")

# Stats
STATS=$(git diff "origin/$BASE_BRANCH...HEAD" --stat 2>/dev/null | tail -1)
FILES_CHANGED=$(echo "$STATS" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
INSERTIONS=$(echo "$STATS" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
DELETIONS=$(echo "$STATS" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")

if $JSON_MODE; then
  cat <<EOF
{
  "base_branch": "$BASE_BRANCH",
  "current_branch": "$CURRENT_BRANCH",
  "is_feature_branch": $IS_FEATURE_BRANCH,
  "ticket_id": "${TICKET_ID:-null}",
  "has_claude_md": $HAS_CLAUDE_MD,
  "has_agents_md": $HAS_AGENTS_MD,
  "has_architecture_md": $HAS_ARCHITECTURE_MD,
  "adr_count": $ADR_COUNT,
  "pr_number": ${PR_NUMBER:-null},
  "pr_state": "${PR_STATE:-null}",
  "ci_status": "${CI_STATUS:-null}",
  "commit_count": $COMMIT_COUNT,
  "files_changed": $FILES_CHANGED,
  "insertions": $INSERTIONS,
  "deletions": $DELETIONS
}
EOF
else
  echo "=== BRANCH INFO ==="
  echo "Current branch: $CURRENT_BRANCH"
  echo "Base branch: $BASE_BRANCH"
  echo "Is feature branch: $IS_FEATURE_BRANCH"
  echo ""
  echo "=== TICKET ==="
  echo "Detected: ${TICKET_ID:-none}"
  echo ""
  echo "=== PROJECT CONTEXT ==="
  echo "CLAUDE.md: $HAS_CLAUDE_MD"
  echo "AGENTS.md: $HAS_AGENTS_MD"
  echo "ARCHITECTURE.md: $HAS_ARCHITECTURE_MD"
  echo "ADRs: $ADR_COUNT files"
  echo ""
  echo "=== PR INFO ==="
  echo "PR: ${PR_NUMBER:-none}"
  echo "State: ${PR_STATE:-n/a}"
  echo "CI: ${CI_STATUS:-n/a}"
  echo ""
  echo "=== CHANGES ==="
  echo "Commits: $COMMIT_COUNT"
  echo "Files: $FILES_CHANGED"
  echo "Lines: +$INSERTIONS / -$DELETIONS"
fi
