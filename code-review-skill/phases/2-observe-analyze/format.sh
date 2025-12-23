#!/usr/bin/env bash
# Format output for Phase 2: OBSERVE & ANALYZE
# Keep it minimal - don't reveal findings before human review

STATE_FILE="$1"

files_count=$(jq '.files | length // 0' "$STATE_FILE")
findings_count=$(jq '.agent_findings | length // 0' "$STATE_FILE")

echo "Files identified: $files_count"
echo "Agent findings: $findings_count (details in report phase)"
