#!/usr/bin/env bash
# workflow.sh - State machine for multi-phase skills
#
# Usage:
#   ./scripts/workflow.sh next     # Get current phase instructions
#   ./scripts/workflow.sh save     # Save JSON from stdin to state
#   ./scripts/workflow.sh gate     # Check current phase gate
#   ./scripts/workflow.sh status   # Show current status
#   ./scripts/workflow.sh clean    # Reset state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
STATE_DIR="$SKILL_DIR/.state"
PHASES_DIR="$SKILL_DIR/phases"
STATE_FILE="$STATE_DIR/state.json"

# ============================================================
# CUSTOMIZE: Phase directory names (source of truth)
# ============================================================
declare -a PHASE_DIRS=("" "1-example" "2-example" "3-example")

mkdir -p "$STATE_DIR"

#######################################
# Load state from file
#######################################
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "{}"
    fi
}

#######################################
# Get current phase number
#######################################
get_phase() {
    local state
    state=$(load_state)
    if [[ "$state" == "{}" ]]; then
        echo "0"
    else
        echo "$state" | jq -r '.phase // 0'
    fi
}

#######################################
# cmd_next - Get instructions for current phase
# Auto-advances if gate passes
#######################################
cmd_next() {
    local phase phase_dir instructions_file

    # Determine phase
    if [[ -f "$STATE_FILE" ]]; then
        phase=$(jq -r '.phase // 1' "$STATE_FILE")

        # Check if current gate passes - if so, advance
        local phase_dir_check="${PHASE_DIRS[$phase]}"
        local gate_script="$PHASES_DIR/$phase_dir_check/gate.sh"

        if [[ -f "$gate_script" ]] && bash "$gate_script" "$STATE_FILE" > /dev/null 2>&1; then
            local next_phase=$((phase + 1))
            local now
            now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

            jq --argjson phase "$next_phase" --arg now "$now" \
                '.phase = $phase | .last_updated = $now' "$STATE_FILE" > "${STATE_FILE}.tmp"
            mv "${STATE_FILE}.tmp" "$STATE_FILE"

            echo ">>> Gate $phase passed. Advanced to phase $next_phase."
            echo ""
            phase=$next_phase
        fi
    else
        phase=1
    fi

    # Check if workflow complete
    local max_phase=${#PHASE_DIRS[@]}
    if [[ "$phase" -ge "$max_phase" ]]; then
        echo "=== WORKFLOW COMPLETE ==="
        echo ""
        echo "All phases completed. Use 'clean' to start fresh."
        exit 0
    fi

    # Get phase directory and instructions
    phase_dir="${PHASE_DIRS[$phase]}"
    instructions_file="$PHASES_DIR/$phase_dir/instructions.md"

    if [[ ! -f "$instructions_file" ]]; then
        echo "Error: Instructions not found: $instructions_file"
        exit 1
    fi

    # Output header
    echo "=== PHASE $phase: ${phase_dir#*-} ==="
    echo ""

    # ============================================================
    # CUSTOMIZE: Context extraction per phase
    # ============================================================
    if [[ -f "$STATE_FILE" && "$phase" -gt 1 ]]; then
        echo "--- CONTEXT FROM PREVIOUS PHASES ---"
        echo ""
        case "$phase" in
            2)
                # Phase 2: what it needs from phase 1
                jq '{field1, field2}' "$STATE_FILE"
                ;;
            3)
                # Phase 3: what it needs from phases 1-2
                jq '{field1, summary_from_phase2}' "$STATE_FILE"
                ;;
            *)
                # Default: show minimal context
                jq '{phase}' "$STATE_FILE"
                ;;
        esac
        echo ""
    fi

    echo "--- INSTRUCTIONS ---"
    echo ""
    cat "$instructions_file"
}

#######################################
# cmd_save - Merge JSON into state
#######################################
cmd_save() {
    local now input_json current_state new_state
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Read JSON from stdin
    input_json=$(cat)

    if [[ -z "$input_json" ]]; then
        echo "Error: No JSON data provided on stdin"
        exit 1
    fi

    if ! echo "$input_json" | jq -e . > /dev/null 2>&1; then
        echo "Error: Invalid JSON"
        exit 1
    fi

    # Load or initialize state
    if [[ -f "$STATE_FILE" ]]; then
        current_state=$(cat "$STATE_FILE")
    else
        local template="$SKILL_DIR/templates/state.json"
        if [[ -f "$template" ]]; then
            current_state=$(jq --arg now "$now" '.started_at = $now' "$template")
        else
            current_state="{\"phase\": 1, \"started_at\": \"$now\"}"
        fi
    fi

    # Deep merge
    new_state=$(echo "$current_state" | jq --argjson input "$input_json" --arg now "$now" \
        '. * $input | .last_updated = $now')

    echo "$new_state" > "$STATE_FILE"
    echo "State saved."
}

#######################################
# cmd_gate - Check current phase gate
#######################################
cmd_gate() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "Error: No state found. Run 'next' first."
        exit 1
    fi

    local phase phase_dir gate_script
    phase=$(jq -r '.phase // 1' "$STATE_FILE")
    phase_dir="${PHASE_DIRS[$phase]}"
    gate_script="$PHASES_DIR/$phase_dir/gate.sh"

    if [[ ! -f "$gate_script" ]]; then
        echo "Error: Gate script not found: $gate_script"
        exit 1
    fi

    bash "$gate_script" "$STATE_FILE"
}

#######################################
# cmd_status - Show current status
#######################################
cmd_status() {
    if [[ -f "$STATE_FILE" ]]; then
        echo "Current state:"
        jq '.' "$STATE_FILE"
    else
        echo "No state found. Workflow not started."
    fi
}

#######################################
# cmd_clean - Reset state
#######################################
cmd_clean() {
    if [[ -f "$STATE_FILE" ]]; then
        rm "$STATE_FILE"
        echo "State cleared."
    else
        echo "No state to clear."
    fi
}

#######################################
# Main
#######################################
main() {
    local cmd="${1:-}"

    case "$cmd" in
        next)   cmd_next ;;
        save)   cmd_save ;;
        gate)   cmd_gate ;;
        status) cmd_status ;;
        clean)  cmd_clean ;;
        -h|--help|"")
            echo "Usage: workflow.sh <command>"
            echo ""
            echo "Commands:"
            echo "  next    Get current phase instructions"
            echo "  save    Save JSON from stdin to state"
            echo "  gate    Check current phase gate"
            echo "  status  Show current status"
            echo "  clean   Reset state"
            ;;
        *)
            echo "Unknown command: $cmd"
            exit 1
            ;;
    esac
}

main "$@"
