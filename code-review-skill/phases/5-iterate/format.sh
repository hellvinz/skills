#!/usr/bin/env bash
# Format context for Phase 5: ITERATE

STATE_FILE="$1"

echo "=== Phase 5: ITERATE ==="
echo ""

# Findings by status
pending=$(jq '[.findings // [] | .[] | select(.status == "pending")] | length' "$STATE_FILE")
addressed=$(jq '[.findings // [] | .[] | select(.status == "addressed")] | length' "$STATE_FILE")
skipped=$(jq '[.findings // [] | .[] | select(.status == "skipped")] | length' "$STATE_FILE")

echo "Progress: $addressed addressed, $skipped skipped, $pending pending"
echo ""

# List pending findings
if [[ "$pending" -gt 0 ]]; then
  echo "Pending findings:"
  jq -r '.findings[] | select(.status == "pending") | "  [\(.id)] \(.severity) \(.file):\(.line) - \(.description)"' "$STATE_FILE"
fi

echo ""
echo "Update findings with:"
echo "  review.sh set findings '<updated json array>'"
