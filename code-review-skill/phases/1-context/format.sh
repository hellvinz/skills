#!/usr/bin/env bash
# Format context for Phase 1: CONTEXT

STATE_FILE="$1"

echo "=== Phase 1: CONTEXT ==="
echo ""
echo "Branch: $(jq -r '.branch' "$STATE_FILE")"

round=$(jq -r '.round // 1' "$STATE_FILE")
if [[ "$round" -gt 1 ]]; then
    pending=$(jq '[.findings // [] | .[] | select(.status == "pending")] | length' "$STATE_FILE")
    addressed=$(jq '[.findings // [] | .[] | select(.status == "addressed")] | length' "$STATE_FILE")
    skipped=$(jq '[.findings // [] | .[] | select(.status == "skipped")] | length' "$STATE_FILE")
    echo "Round: $round"
    echo "Carried findings: $pending pending, $addressed addressed, $skipped skipped"
    if [[ "$pending" -gt 0 ]]; then
        echo ""
        echo "Pending findings from previous round:"
        jq -r '.findings[] | select(.status == "pending") | "  [\(.id)] \(.severity) \(.file):\(.line) - \(.description)"' "$STATE_FILE"
    fi
else
    echo ""
    echo "No context gathered yet. Run gather-context.sh and save with:"
    echo "  review.sh set context '<json>'"
fi
