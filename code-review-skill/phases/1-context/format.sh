#!/usr/bin/env bash
# Format context for Phase 1: CONTEXT

STATE_FILE="$1"

echo "=== Phase 1: CONTEXT ==="
echo ""
echo "Branch: $(jq -r '.branch' "$STATE_FILE")"
echo ""
echo "No context gathered yet. Run gather-context.sh and save with:"
echo "  review.sh set context '<json>'"
