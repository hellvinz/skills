#!/usr/bin/env bash
# gate.sh - Phase 1 gate validation
#
# Exit 0 = gate passes, ready for next phase
# Exit 1 = gate fails, stay on current phase

set -euo pipefail

STATE_FILE="${1:-}"

if [[ -z "$STATE_FILE" || ! -f "$STATE_FILE" ]]; then
    echo "Error: State file required" >&2
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

# ============================================================
# CUSTOMIZE: Add your validations here
# ============================================================
check '.field1' || ERRORS+=("field1 not set")
check '.field2' || ERRORS+=("field2 not set")

# Result
if [[ ${#ERRORS[@]} -eq 0 ]]; then
    echo "Gate 1 PASSED"
    exit 0
else
    echo "Gate 1 FAILED"
    printf '  - %s\n' "${ERRORS[@]}"
    exit 1
fi
