#!/usr/bin/env bash
# add-finding.sh - Add a human observation to human_findings array
# Used in Phase 3: COLLECT
#
# Usage: add-finding.sh '{"file": "src/api.ts", "description": "...", "severity": "high"}'

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FINDING_JSON="$1"

if [[ -z "$FINDING_JSON" ]]; then
  echo "Usage: add-finding.sh '<json>'" >&2
  echo "Example: add-finding.sh '{\"file\": \"src/api.ts\", \"description\": \"Missing error handling\", \"severity\": \"high\"}'" >&2
  exit 1
fi

# Validate JSON
if ! echo "$FINDING_JSON" | jq . > /dev/null 2>&1; then
  echo "Error: Invalid JSON" >&2
  exit 1
fi

# Get current human_findings
current=$("$SCRIPT_DIR/review.sh" get human_findings)
if [[ "$current" == "null" ]]; then
  current="[]"
fi

# Calculate next ID
next_id=$(echo "$current" | jq 'length + 1')

# Enrich finding with id and source
enriched=$(echo "$FINDING_JSON" | jq --argjson id "$next_id" '. + {id: $id, source: "human"}')

# Append to array
updated=$(echo "$current" | jq --argjson f "$enriched" '. + [$f]')

# Save back
"$SCRIPT_DIR/review.sh" set human_findings "$updated"

echo "Added human finding #$next_id"
