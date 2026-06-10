#!/usr/bin/env bash
# workflow.sh - Common workflow state machine library for skills
#
# Usage:
#   source "$SKILL_DIR/../scripts/lib/workflow.sh"
#   workflow_init <config_array>
#
# Configuration (associative array):
#   [state_file]     - Path to state JSON file (required)
#   [phases_dir]     - Path to phases directory (required)
#   [total_phases]   - Total number of phases (required)
#   [identifier]     - Display identifier (e.g., URL or branch name)
#   [id_label]       - Label for identifier (e.g., "URL" or "Branch")
#
# Callbacks (optional functions to define):
#   workflow_get_context()    - Output context for current phase (receives phase_num, state_file)
#   workflow_on_complete()    - Called when workflow completes
#   workflow_get_phase_dir()  - Custom phase directory lookup (receives phase_num)

set -euo pipefail

#######################################
# Library state (set by workflow_init)
#######################################
declare -g WORKFLOW_STATE_FILE=""
declare -g WORKFLOW_PHASES_DIR=""
declare -g WORKFLOW_TOTAL_PHASES=0
declare -g WORKFLOW_IDENTIFIER=""
declare -g WORKFLOW_ID_LABEL="ID"

#######################################
# Initialize workflow with configuration
# Arguments:
#   Config values as positional args:
#   $1 - state_file
#   $2 - phases_dir
#   $3 - total_phases
#   $4 - identifier (optional)
#   $5 - id_label (optional, default "ID")
#######################################
workflow_init() {
    WORKFLOW_STATE_FILE="${1:?state_file required}"
    WORKFLOW_PHASES_DIR="${2:?phases_dir required}"
    WORKFLOW_TOTAL_PHASES="${3:?total_phases required}"
    WORKFLOW_IDENTIFIER="${4:-}"
    WORKFLOW_ID_LABEL="${5:-ID}"
}

#######################################
# Get current timestamp in ISO format
#######################################
workflow_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

#######################################
# Get current phase from state file
# Returns 0 if no state exists
#######################################
workflow_get_phase() {
    if [[ -f "$WORKFLOW_STATE_FILE" ]]; then
        jq -r '.phase // 1' "$WORKFLOW_STATE_FILE"
    else
        echo "0"
    fi
}

#######################################
# Get phase directory path
# Arguments:
#   $1 - phase number
# Returns:
#   Path to phase directory, or empty if not found
#######################################
workflow_get_phase_dir() {
    local phase_num="$1"

    # Allow override via callback
    if declare -f workflow_get_phase_dir_custom > /dev/null; then
        workflow_get_phase_dir_custom "$phase_num"
        return
    fi

    # Default: find directory matching N-* pattern
    local dir
    dir=$(find "$WORKFLOW_PHASES_DIR" -maxdepth 1 -type d -name "${phase_num}-*" 2>/dev/null | head -1)
    echo "$dir"
}

#######################################
# Get phase name from directory
# Arguments:
#   $1 - phase directory path
#######################################
workflow_get_phase_name() {
    local phase_dir="$1"
    basename "$phase_dir" | sed 's/^[0-9]*-//'
}

#######################################
# Update state file with jq command
# Arguments:
#   All arguments are passed to jq
#######################################
workflow_update_state() {
    jq "$@" "$WORKFLOW_STATE_FILE" > "${WORKFLOW_STATE_FILE}.tmp"
    mv "${WORKFLOW_STATE_FILE}.tmp" "$WORKFLOW_STATE_FILE"
}

#######################################
# Check if gate passes for a phase
# Arguments:
#   $1 - phase number
# Returns:
#   0 if gate passes, 1 otherwise
#######################################
workflow_check_gate() {
    local phase_num="$1"
    local phase_dir
    phase_dir=$(workflow_get_phase_dir "$phase_num")

    if [[ -z "$phase_dir" || ! -f "$phase_dir/gate.sh" ]]; then
        return 1
    fi

    bash "$phase_dir/gate.sh" "$WORKFLOW_STATE_FILE" > /dev/null 2>&1
}

#######################################
# Output phase instructions
# Arguments:
#   $1 - phase number
#######################################
workflow_output_instructions() {
    local phase_num="$1"
    local phase_dir
    phase_dir=$(workflow_get_phase_dir "$phase_num")

    if [[ -d "$phase_dir" && -f "$phase_dir/instructions.md" ]]; then
        echo ""
        echo "================================================================================"
        cat "$phase_dir/instructions.md"
        echo "================================================================================"
    fi
}

#######################################
# Output context for a phase
# Uses format.sh if exists, or callback if defined
# Arguments:
#   $1 - phase number
#######################################
workflow_output_context() {
    local phase_num="$1"
    local phase_dir
    phase_dir=$(workflow_get_phase_dir "$phase_num")

    # Try callback first
    if declare -f workflow_get_context > /dev/null; then
        workflow_get_context "$phase_num" "$WORKFLOW_STATE_FILE"
        return
    fi

    # Fall back to format.sh
    if [[ -f "$phase_dir/format.sh" ]]; then
        bash "$phase_dir/format.sh" "$WORKFLOW_STATE_FILE"
    fi
}

#######################################
# Main next command implementation
# Checks gate, advances if passed, outputs instructions
# Creates initial state if not exists (no explicit init needed)
#######################################
workflow_cmd_next() {
    # Create initial state if not exists
    if [[ ! -f "$WORKFLOW_STATE_FILE" ]]; then
        # Call init callback if defined, otherwise create minimal state
        if declare -f workflow_create_initial_state > /dev/null; then
            workflow_create_initial_state
        else
            local now
            now=$(workflow_now)
            local dir
            dir=$(dirname "$WORKFLOW_STATE_FILE")
            mkdir -p "$dir"
            echo "{\"phase\": 1, \"started_at\": \"$now\", \"last_updated\": \"$now\"}" > "$WORKFLOW_STATE_FILE"
        fi
        echo "Started new workflow."
        echo ""
    fi

    local phase_num phase_dir
    phase_num=$(workflow_get_phase)
    phase_dir=$(workflow_get_phase_dir "$phase_num")

    # Check if current gate passes - if so, advance to next phase
    if [[ -n "$phase_dir" && -f "$phase_dir/gate.sh" ]]; then
        if workflow_check_gate "$phase_num"; then
            local next_phase=$((phase_num + 1))
            local next_dir
            next_dir=$(workflow_get_phase_dir "$next_phase")

            # Check if workflow complete
            if [[ -z "$next_dir" ]] || [[ "$next_phase" -gt "$WORKFLOW_TOTAL_PHASES" ]]; then
                echo "=== WORKFLOW COMPLETE ==="
                echo ""
                if declare -f workflow_on_complete > /dev/null; then
                    workflow_on_complete
                else
                    echo "All phases completed."
                    echo "Use 'clean' to start fresh if needed."
                fi
                exit 0
            fi

            # Record gate passage and advance
            local now
            now=$(workflow_now)
            workflow_update_state \
                --argjson p "$phase_num" \
                --argjson np "$next_phase" \
                --arg t "$now" \
                ".gates[\$p | tostring] = {\"passed\": true, \"at\": \$t} | .phase = \$np | .last_updated = \$t"

            echo ">>> Gate $phase_num passed. Advanced to phase $next_phase."
            echo ""
            phase_num=$next_phase
            phase_dir=$(workflow_get_phase_dir "$phase_num")
        fi
    fi

    # Output current phase header
    local phase_name
    phase_name=$(workflow_get_phase_name "$phase_dir")
    echo "=== PHASE $phase_num: $phase_name ==="
    if [[ -n "$WORKFLOW_IDENTIFIER" ]]; then
        echo "$WORKFLOW_ID_LABEL: $WORKFLOW_IDENTIFIER"
    fi
    echo ""

    # Output context from previous phases
    if [[ "$phase_num" -gt 1 ]]; then
        echo "--- CONTEXT FROM PREVIOUS PHASES ---"
        echo ""
        workflow_output_context "$phase_num"
        echo ""
    fi

    # Output instructions
    echo "--- INSTRUCTIONS ---"
    workflow_output_instructions "$phase_num"
}

#######################################
# Gate command - check gate only (with full output)
#######################################
workflow_cmd_gate() {
    if [[ ! -f "$WORKFLOW_STATE_FILE" ]]; then
        echo "Error: No workflow in progress." >&2
        exit 1
    fi

    local phase_num phase_dir
    phase_num=$(workflow_get_phase)
    phase_dir=$(workflow_get_phase_dir "$phase_num")

    if [[ -z "$phase_dir" || ! -f "$phase_dir/gate.sh" ]]; then
        echo "Error: No gate script for phase $phase_num" >&2
        exit 1
    fi

    # Run gate with full output (not silenced)
    bash "$phase_dir/gate.sh" "$WORKFLOW_STATE_FILE"
}

#######################################
# Status command - show raw state
#######################################
workflow_cmd_status() {
    if [[ ! -f "$WORKFLOW_STATE_FILE" ]]; then
        echo "No workflow in progress."
        exit 0
    fi

    cat "$WORKFLOW_STATE_FILE"
}

#######################################
# Set a value in state
# Arguments:
#   $1 - key
#   $2 - JSON value
#######################################
workflow_set_value() {
    local key="$1"
    local json="$2"

    if [[ ! -f "$WORKFLOW_STATE_FILE" ]]; then
        echo "Error: No workflow in progress." >&2
        exit 1
    fi

    # printf, not echo: under zsh login shells echo interprets backslash
    # escapes (\n, \t) and corrupts JSON string values
    if ! printf '%s' "$json" | jq -e . > /dev/null 2>&1; then
        {
            echo "Error: Invalid JSON for key '$key'"
            printf '%s' "$json" | jq . 2>&1 | head -2 | sed 's/^/  jq: /' || true
            echo "Hint: pass ONE JSON value as a single argument:"
            echo "  set $key '\"some text\"'      set $key '{\"a\": 1}'"
            echo "  set $key \"\$(jq -Rs . < file)\"   # file content as JSON string"
        } >&2
        exit 1
    fi

    local now
    now=$(workflow_now)
    jq --arg k "$key" --argjson v "$json" --arg t "$now" \
        '.[$k] = $v | .last_updated = $t' \
        "$WORKFLOW_STATE_FILE" > "${WORKFLOW_STATE_FILE}.tmp"
    mv "${WORKFLOW_STATE_FILE}.tmp" "$WORKFLOW_STATE_FILE"
}

#######################################
# Get a value from state
# Arguments:
#   $1 - key
#######################################
workflow_get_value() {
    local key="$1"

    if [[ ! -f "$WORKFLOW_STATE_FILE" ]]; then
        echo "null"
        return
    fi

    jq -r --arg k "$key" '.[$k] // null' "$WORKFLOW_STATE_FILE"
}

#######################################
# Save/merge JSON into state from stdin
# Arguments:
#   $1 - template file path (optional, for new state)
#   $2 - initial state JSON (optional, for new state)
#######################################
workflow_save_state() {
    local template="${1:-}"
    local initial_state="${2:-}"
    local now
    now=$(workflow_now)

    # Read JSON from stdin
    local input_json
    input_json=$(cat)

    if [[ -z "$input_json" ]]; then
        echo "Error: No JSON data provided on stdin" >&2
        exit 1
    fi

    if ! printf '%s' "$input_json" | jq -e . > /dev/null 2>&1; then
        echo "Error: Invalid JSON provided" >&2
        exit 1
    fi

    local current_state
    if [[ -f "$WORKFLOW_STATE_FILE" ]]; then
        current_state=$(cat "$WORKFLOW_STATE_FILE")
    elif [[ -n "$template" && -f "$template" ]]; then
        current_state=$(cat "$template")
    elif [[ -n "$initial_state" ]]; then
        current_state="$initial_state"
    else
        current_state="{}"
    fi

    # Deep merge
    local new_state
    new_state=$(printf '%s' "$current_state" | jq --argjson input "$input_json" --arg now "$now" \
        '. * $input | .last_updated = $now')

    printf '%s\n' "$new_state" > "$WORKFLOW_STATE_FILE"
    echo "State saved."
}
