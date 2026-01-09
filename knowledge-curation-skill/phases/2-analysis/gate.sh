#!/usr/bin/env bash
# gate.sh - Phase 2 (Analysis) gate validation
#
# Usage:
#   ./phases/2-analysis/gate.sh <state_file>
#
# Exit codes:
#   0 - Gate passes, ready for Phase 3
#   1 - Gate fails, requirements not met

set -euo pipefail

STATE_FILE="${1:-}"

if [[ -z "$STATE_FILE" ]]; then
    echo "Error: State file path required" >&2
    exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
    echo "Error: State file not found: $STATE_FILE" >&2
    exit 1
fi

STATE=$(cat "$STATE_FILE")
ERRORS=()

# Get statuses
AGENT_STATUS=$(echo "$STATE" | jq -r '.agent_analysis.status // "pending"')
HUMAN_STATUS=$(echo "$STATE" | jq -r '.human_analysis.status // "pending"')

# Agent must not be pending or running
if [[ "$AGENT_STATUS" == "pending" || "$AGENT_STATUS" == "running" ]]; then
    ERRORS+=("Agent analysis not complete (status: $AGENT_STATUS)")
fi

# Human must be complete
if [[ "$HUMAN_STATUS" != "complete" ]]; then
    ERRORS+=("Human analysis not complete (status: $HUMAN_STATUS)")
fi

# Result
if [[ ${#ERRORS[@]} -eq 0 ]]; then
    echo "Gate 2 PASSED"
    echo "  Agent: $AGENT_STATUS"
    echo "  Human: $HUMAN_STATUS"
    exit 0
else
    echo "Gate 2 FAILED"
    printf '  - %s\n' "${ERRORS[@]}"
    exit 1
fi
