#!/usr/bin/env bash
# gate.sh - Phase 3 (Discussion) gate validation
#
# Usage:
#   ./phases/3-discussion/gate.sh <state_file>
#
# Exit codes:
#   0 - Gate passes, ready for Phase 4
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

# Helper: check field exists and is not null/empty
check() {
    local val
    val=$(echo "$STATE" | jq -r "$1 // empty")
    [[ -n "$val" && "$val" != "null" ]]
}

# Helper: check array has items
check_array() {
    [[ $(echo "$STATE" | jq -r "$1 | length // 0") -gt 0 ]]
}

# Validations
check '.consolidated_summary.title' || ERRORS+=("Consolidated title missing")
check '.consolidated_summary.main_idea' || ERRORS+=("Main idea missing")
check_array '.consolidated_summary.key_takeaways' || ERRORS+=("Key takeaways empty")
check '.consolidated_summary.approved_at' || ERRORS+=("Summary not approved by user")

# Result
if [[ ${#ERRORS[@]} -eq 0 ]]; then
    echo "Gate 3 PASSED"
    echo "  Title: $(echo "$STATE" | jq -r '.consolidated_summary.title')"
    echo "  Takeaways: $(echo "$STATE" | jq -r '.consolidated_summary.key_takeaways | length') points"
    exit 0
else
    echo "Gate 3 FAILED"
    printf '  - %s\n' "${ERRORS[@]}"
    exit 1
fi
