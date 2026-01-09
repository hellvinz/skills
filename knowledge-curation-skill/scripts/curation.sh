#!/usr/bin/env bash
# curation.sh - Main workflow state machine for knowledge curation
#
# Usage:
#   ./scripts/curation.sh status [-u|--url URL]
#   ./scripts/curation.sh clean -u|--url URL
#   ./scripts/curation.sh clean --all
#   ./scripts/curation.sh state -u|--url URL
#   ./scripts/curation.sh phase -u|--url URL
#   ./scripts/curation.sh slug -u|--url URL
#   ./scripts/curation.sh next -u|--url URL    # Returns instructions for current phase
#   ./scripts/curation.sh gate -u|--url URL    # Run gate check for current phase
#   ./scripts/curation.sh save -u|--url URL    # Save JSON data to state (reads from stdin)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
STATE_DIR="$SKILL_DIR/.curation"
PHASES_DIR="$SKILL_DIR/phases"

# Phase directory names (source of truth - never expose to LLM)
declare -a PHASE_DIRS=("" "1-input" "2-analysis" "3-discussion" "4-persist")

# Ensure state directory exists
mkdir -p "$STATE_DIR"

#######################################
# Print usage information
#######################################
usage() {
    cat <<EOF
Usage: curation.sh <command> [options]

Commands:
  status              Show all in-progress curations
  status -u URL       Show status for specific URL
  clean -u URL        Remove state for URL
  clean --all         Remove all curation state
  state -u URL        Get state file path for URL
  phase -u URL        Get current phase number for URL
  slug -u URL         Generate URL slug

Options:
  -u, --url URL       Target URL for the command
  -a, --all           Apply to all curations (clean only)
  -h, --help          Show this help message
  -j, --json          Output in JSON format (status only)
EOF
}

#######################################
# Generate URL slug for state file naming
# Arguments:
#   URL string
# Outputs:
#   Hyphenated slug (max 50 chars)
#######################################
url_to_slug() {
    local url="$1"
    local slug="${url#*://}"
    slug="${slug%/}"
    # Replace non-alphanumeric with hyphens
    slug="${slug//[^a-zA-Z0-9]/-}"
    # Collapse multiple hyphens (requires loop since bash doesn't support + quantifier)
    while [[ "$slug" == *--* ]]; do
        slug="${slug//--/-}"
    done
    slug="${slug#-}"
    slug="${slug%-}"
    echo "${slug:0:50}"
}

#######################################
# Get state file path for a URL
#######################################
get_state_file() {
    local url="$1"
    local slug
    slug=$(url_to_slug "$url")
    echo "$STATE_DIR/state-$slug.json"
}

#######################################
# Load state from file
#######################################
load_state() {
    local url="$1"
    local state_file
    state_file=$(get_state_file "$url")

    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo "{}"
    fi
}

#######################################
# Save state to file (exported for use by other scripts)
#######################################
save_state() {
    local url="$1"
    local state_file
    state_file=$(get_state_file "$url")

    if [[ -n "${2:-}" ]]; then
        echo "$2" > "$state_file"
    else
        cat > "$state_file"
    fi
}

#######################################
# Get current phase from state
#######################################
get_phase() {
    local url="$1"
    local state
    state=$(load_state "$url")

    if [[ "$state" == "{}" ]]; then
        echo "0"
    else
        echo "$state" | jq -r '.phase // 0'
    fi
}

#######################################
# Status command
#######################################
cmd_status() {
    local url="${1:-}"
    local json_output="${2:-false}"

    if [[ -n "$url" ]]; then
        local state_file
        state_file=$(get_state_file "$url")

        if [[ -f "$state_file" ]]; then
            if [[ "$json_output" == "true" ]]; then
                jq '.' "$state_file"
            else
                echo "Status for: $url"
                echo "State file: $state_file"
                echo ""
                jq '.' "$state_file"
            fi
        else
            if [[ "$json_output" == "true" ]]; then
                echo '{"error": "not_found", "url": "'"$url"'"}'
            else
                echo "No curation in progress for: $url"
            fi
            exit 1
        fi
    else
        local count=0
        local results=()

        for state_file in "$STATE_DIR"/state-*.json; do
            if [[ -f "$state_file" ]]; then
                if [[ "$json_output" == "true" ]]; then
                    results+=("$(cat "$state_file")")
                else
                    local url_val phase last_updated
                    url_val=$(jq -r '.url // "unknown"' "$state_file")
                    phase=$(jq -r '.phase // 0' "$state_file")
                    last_updated=$(jq -r '.last_updated // "unknown"' "$state_file")

                    echo "  URL: $url_val"
                    echo "  Phase: $phase"
                    echo "  Last updated: $last_updated"
                    echo "  State: $state_file"
                    echo ""
                fi
                ((count++)) || true
            fi
        done

        if [[ "$json_output" == "true" ]]; then
            if [[ $count -eq 0 ]]; then
                echo "[]"
            else
                printf '%s\n' "${results[@]}" | jq -s '.'
            fi
        else
            echo "In-progress curations:"
            echo ""
            if [[ $count -eq 0 ]]; then
                echo "  No curations in progress."
            fi
        fi
    fi
}

#######################################
# Next command - returns instructions for current phase
# This is the ONLY way to get phase instructions (progressive disclosure)
#######################################
cmd_next() {
    local url="$1"

    if [[ -z "$url" ]]; then
        echo "Error: next requires -u URL"
        exit 1
    fi

    local state_file phase phase_dir instructions_file
    state_file=$(get_state_file "$url")

    # Determine phase: if no state exists, start at phase 1
    if [[ -f "$state_file" ]]; then
        phase=$(jq -r '.phase // 1' "$state_file")

        # Check if current gate passes - if so, advance to next phase
        # (only if phase is within valid range)
        if [[ "$phase" -le 4 ]]; then
            local phase_dir_check="${PHASE_DIRS[$phase]}"
            local gate_script="$PHASES_DIR/$phase_dir_check/gate.sh"

            if [[ -f "$gate_script" ]] && STATE_FILE="$state_file" bash "$gate_script" "$state_file" > /dev/null 2>&1; then
                # Gate passed - advance
                local next_phase=$((phase + 1))
                local now
                now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

                jq --argjson phase "$next_phase" --arg now "$now" \
                    '.phase = $phase | .last_updated = $now' "$state_file" > "${state_file}.tmp"
                mv "${state_file}.tmp" "$state_file"

                echo ">>> Gate $phase passed. Advanced to phase $next_phase."
                echo ""
                phase=$next_phase
            fi
        fi
    else
        phase=1
    fi

    # Check if workflow complete
    if [[ "$phase" -gt 4 ]]; then
        echo "=== WORKFLOW COMPLETE ==="
        echo ""
        echo "Curation for this URL has been completed."
        echo "Use 'clean -u URL' to start fresh if needed."
        exit 0
    fi

    # Get phase directory and instructions
    phase_dir="${PHASE_DIRS[$phase]}"
    instructions_file="$PHASES_DIR/$phase_dir/instructions.md"

    if [[ ! -f "$instructions_file" ]]; then
        echo "Error: Instructions not found for phase $phase"
        exit 1
    fi

    # Output header with context
    echo "=== PHASE $phase: ${phase_dir#*-} ==="
    echo "URL: $url"
    echo ""

    # Output relevant state data for this phase (progressive disclosure)
    if [[ -f "$state_file" && "$phase" -gt 1 ]]; then
        echo "--- CONTEXT FROM PREVIOUS PHASES ---"
        echo ""
        case "$phase" in
            2)
                # Phase 2 needs: url, resource_metadata
                jq '{url, mode, resource_metadata}' "$state_file"
                ;;
            3)
                # Phase 3 needs: agent_analysis, human_analysis
                jq '{url, resource_metadata: {title: .resource_metadata.title, kagi_takeaways: .resource_metadata.kagi_takeaways}, agent_analysis, human_analysis}' "$state_file"
                ;;
            4)
                # Phase 4 needs: consolidated_summary, suggested_tags, suggested_relationships
                jq '{url, mode, existing_node_id, resource_metadata: {title: .resource_metadata.title}, consolidated_summary, suggested_tags, suggested_relationships}' "$state_file"
                ;;
        esac
        echo ""
    fi

    echo "--- INSTRUCTIONS ---"
    echo ""

    # Return the actual instructions content
    cat "$instructions_file"
}

#######################################
# Save command - merge JSON data into state
# Reads JSON from stdin and deep-merges with existing state
#######################################
cmd_save() {
    local url="$1"

    if [[ -z "$url" ]]; then
        echo "Error: save requires -u URL"
        exit 1
    fi

    local state_file slug now input_json current_state new_state
    state_file=$(get_state_file "$url")
    slug=$(url_to_slug "$url")
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Read JSON from stdin
    input_json=$(cat)

    if [[ -z "$input_json" ]]; then
        echo "Error: No JSON data provided on stdin"
        exit 1
    fi

    # Validate input is valid JSON
    if ! echo "$input_json" | jq -e . > /dev/null 2>&1; then
        echo "Error: Invalid JSON provided"
        exit 1
    fi

    # Load existing state or create from template
    if [[ -f "$state_file" ]]; then
        current_state=$(cat "$state_file")
    else
        local template="$SKILL_DIR/templates/analysis-state.json"
        if [[ -f "$template" ]]; then
            current_state=$(jq --arg url "$url" --arg slug "$slug" --arg now "$now" \
                '.url = $url | .url_slug = $slug | .started_at = $now' "$template")
        else
            current_state="{\"url\": \"$url\", \"url_slug\": \"$slug\", \"started_at\": \"$now\"}"
        fi
    fi

    # Deep merge: input overwrites current, update last_updated
    new_state=$(echo "$current_state" | jq --argjson input "$input_json" --arg now "$now" \
        '. * $input | .last_updated = $now')

    # Save
    echo "$new_state" > "$state_file"
    echo "State saved for: $url"
}

#######################################
# Gate command - run gate check for current phase
#######################################
cmd_gate() {
    local url="$1"

    if [[ -z "$url" ]]; then
        echo "Error: gate requires -u URL"
        exit 1
    fi

    local state_file phase phase_dir gate_script
    state_file=$(get_state_file "$url")

    if [[ ! -f "$state_file" ]]; then
        echo "Error: No state found for this URL. Run 'next' first."
        exit 1
    fi

    phase=$(jq -r '.phase // 1' "$state_file")
    phase_dir="${PHASE_DIRS[$phase]}"
    gate_script="$PHASES_DIR/$phase_dir/gate.sh"

    if [[ ! -f "$gate_script" ]]; then
        echo "Error: Gate script not found for phase $phase"
        exit 1
    fi

    # Run the gate script with state file path
    STATE_FILE="$state_file" bash "$gate_script" "$state_file"
}

#######################################
# Clean command
#######################################
cmd_clean() {
    local url="${1:-}"
    local all="${2:-false}"

    if [[ "$all" == "true" ]]; then
        local count=0
        for state_file in "$STATE_DIR"/state-*.json; do
            if [[ -f "$state_file" ]]; then
                rm "$state_file"
                ((count++)) || true
            fi
        done
        echo "Removed $count state file(s)"
    elif [[ -n "$url" ]]; then
        local state_file
        state_file=$(get_state_file "$url")

        if [[ -f "$state_file" ]]; then
            rm "$state_file"
            echo "Removed state for: $url"
        else
            echo "No state found for: $url"
            exit 1
        fi
    else
        echo "Error: clean requires -u URL or --all"
        exit 1
    fi
}

#######################################
# Main entry point
#######################################
main() {
    local cmd=""
    local url=""
    local all_flag="false"
    local json_flag="false"

    # Parse command (first non-option argument)
    if [[ $# -gt 0 && "${1:0:1}" != "-" ]]; then
        cmd="$1"
        shift
    fi

    # Parse options manually for portability (BSD/GNU compatible)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--url)
                if [[ -n "${2:-}" ]]; then
                    url="$2"
                    shift 2
                else
                    echo "Error: -u requires a URL argument"
                    exit 1
                fi
                ;;
            -a|--all)
                all_flag="true"
                shift
                ;;
            -j|--json)
                json_flag="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                # Positional argument after command
                break
                ;;
        esac
    done

    # Dispatch command
    case "$cmd" in
        status)
            cmd_status "$url" "$json_flag"
            ;;
        clean)
            cmd_clean "$url" "$all_flag"
            ;;
        next)
            cmd_next "$url"
            ;;
        gate)
            cmd_gate "$url"
            ;;
        save)
            cmd_save "$url"
            ;;
        state)
            if [[ -z "$url" ]]; then
                echo "Error: state requires -u URL"
                exit 1
            fi
            get_state_file "$url"
            ;;
        phase)
            if [[ -z "$url" ]]; then
                echo "Error: phase requires -u URL"
                exit 1
            fi
            get_phase "$url"
            ;;
        slug)
            if [[ -z "$url" ]]; then
                echo "Error: slug requires -u URL"
                exit 1
            fi
            url_to_slug "$url"
            ;;
        "")
            usage
            exit 0
            ;;
        *)
            echo "Unknown command: $cmd"
            usage
            exit 1
            ;;
    esac
}

main "$@"
