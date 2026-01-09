#!/usr/bin/env bash
# gate.sh - Phase 4 (Persist) gate validation
#
# Usage:
#   ./phases/4-persist/gate.sh <state_file>
#
# Exit codes:
#   0 - Gate passes, curation complete
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

# Validations
check '.result.helix_node_id' || ERRORS+=("Helix node not created")
check '.result.obsidian_note_path' || ERRORS+=("Obsidian note not created")

# Result
if [[ ${#ERRORS[@]} -eq 0 ]]; then
    echo "Gate 4 PASSED - Curation Complete"
    echo "  Helix node: $(echo "$STATE" | jq -r '.result.helix_node_id')"
    echo "  Obsidian note: $(echo "$STATE" | jq -r '.result.obsidian_note_path')"
    exit 0
else
    echo "Gate 4 FAILED"
    printf '  - %s\n' "${ERRORS[@]}"
    exit 1
fi
