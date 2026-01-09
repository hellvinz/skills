#!/usr/bin/env bash
# gate.sh - Phase 1 (Input) gate validation
#
# Usage:
#   ./phases/1-input/gate.sh <state_file>
#
# Exit codes:
#   0 - Gate passes, ready for Phase 2
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
check '.url' || ERRORS+=("URL not set")
check '.url_slug' || ERRORS+=("URL slug not set")
check '.resource_metadata.title' || ERRORS+=("Title not extracted")
check '.resource_metadata.domain' || ERRORS+=("Domain not extracted")
check_array '.resource_metadata.kagi_takeaways' || ERRORS+=("Kagi takeaways missing")

MODE=$(echo "$STATE" | jq -r '.mode // empty')
[[ "$MODE" == "create" || "$MODE" == "update" ]] || ERRORS+=("Mode not determined")

# Result
if [[ ${#ERRORS[@]} -eq 0 ]]; then
    echo "Gate 1 PASSED"
    echo "  Title: $(echo "$STATE" | jq -r '.resource_metadata.title')"
    echo "  Mode: $MODE"
    exit 0
else
    echo "Gate 1 FAILED"
    printf '  - %s\n' "${ERRORS[@]}"
    exit 1
fi
