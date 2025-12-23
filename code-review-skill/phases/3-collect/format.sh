#!/usr/bin/env bash
# Format output for Phase 3: COLLECT

STATE_FILE="$1"

agent_count=$(jq '.agent_findings | length // 0' "$STATE_FILE")
human_count=$(jq '.human_findings | length // 0' "$STATE_FILE")
human_done=$(jq -r '.human_done // false' "$STATE_FILE")

echo "Agent findings: $agent_count"
echo "Human findings: $human_count"
echo "Human done: $human_done"

if [[ "$human_count" -gt 0 ]]; then
  echo ""
  echo "Human observations:"
  jq -r '.human_findings[] | "  - [\(.severity)] \(.file):\(.line // "?") - \(.description)"' "$STATE_FILE" 2>/dev/null
fi
