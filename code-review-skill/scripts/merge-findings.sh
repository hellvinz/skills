#!/usr/bin/env bash
# merge-findings.sh - Combine agent_findings + human_findings into unified findings
# Used at end of Phase 3: COLLECT
#
# Usage: merge-findings.sh

# --help: print the header doc block of this script
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
    exit 0
fi

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Get both sources
agent=$("$SCRIPT_DIR/review.sh" get agent_findings)
human=$("$SCRIPT_DIR/review.sh" get human_findings)

if [[ "$agent" == "null" ]]; then
  agent="[]"
fi
if [[ "$human" == "null" ]]; then
  human="[]"
fi

# Merge and renumber
merged=$(jq -n \
  --argjson agent "$agent" \
  --argjson human "$human" '
  # Add source to agent findings if not present
  ($agent | map(. + {source: "agent", status: "pending"})) as $a |
  # Human findings already have source from add-finding.sh
  ($human | map(. + {status: "pending"})) as $h |
  # Combine and renumber
  ($a + $h) | to_entries | map(.value + {id: (.key + 1)})
')

# Save merged findings
"$SCRIPT_DIR/review.sh" set findings "$merged"

count=$(echo "$merged" | jq 'length')
echo "Merged $count findings (agent + human)"
