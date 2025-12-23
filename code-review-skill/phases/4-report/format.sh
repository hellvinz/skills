#!/usr/bin/env bash
# Format context for Phase 4: REPORT

STATE_FILE="$1"

echo "=== Phase 4: REPORT ==="
echo ""

# Branch info
echo "Branch: $(jq -r '.branch' "$STATE_FILE")"

# Context
ticket=$(jq -r '.context.ticket.id // "none"' "$STATE_FILE")
pr=$(jq -r '.context.pr.number // "none"' "$STATE_FILE")
[[ "$ticket" != "none" && "$ticket" != "null" ]] && \
  echo "Ticket: $ticket - $(jq -r '.context.ticket.title // ""' "$STATE_FILE")"
[[ "$pr" != "none" && "$pr" != "null" ]] && \
  echo "PR: #$pr"

# Files
file_count=$(jq '.files | length // 0' "$STATE_FILE")
echo "Files: $file_count"

# Findings summary
echo ""
total=$(jq '.findings | length // 0' "$STATE_FILE")
echo "Total findings: $total"

if [[ "$total" -eq 0 ]]; then
  echo "No issues found."
else
  # Count by severity
  critical=$(jq '[.findings[] | select(.severity == "critical")] | length' "$STATE_FILE")
  high=$(jq '[.findings[] | select(.severity == "high")] | length' "$STATE_FILE")
  medium=$(jq '[.findings[] | select(.severity == "medium")] | length' "$STATE_FILE")
  low=$(jq '[.findings[] | select(.severity == "low")] | length' "$STATE_FILE")

  echo "By severity: critical=$critical high=$high medium=$medium low=$low"
  echo ""

  # List all findings with details
  echo "Findings:"
  jq -r '.findings[] | "  #\(.id) [\(.source | if . == "agent" then "A" else "H" end)] [\(.severity)] \(.file)\(if .line then ":\(.line)" else "" end) - \(.description)"' "$STATE_FILE"
fi
