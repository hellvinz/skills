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

# Resolve symlinks to get real path (pwd -P resolves symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$(dirname "$SKILL_DIR")/scripts/lib"
STATE_DIR="$SKILL_DIR/.curation"
PHASES_DIR="$SKILL_DIR/phases"
TOTAL_PHASES=4

# Source workflow library
# shellcheck source=../../scripts/lib/workflow.sh
source "$LIB_DIR/workflow.sh"

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
  next -u URL         Check gate, advance if passed, show instructions
  gate -u URL         Check gate only
  save -u URL         Save JSON from stdin to state

Options:
  -u, --url URL       Target URL for the command
  -a, --all           Apply to all curations (clean only)
  -h, --help          Show this help message
  -j, --json          Output in JSON format (status only)
EOF
}

#######################################
# Generate URL slug for state file naming
#######################################
url_to_slug() {
    local url="$1"
    local slug="${url#*://}"
    slug="${slug%/}"
    slug="${slug//[^a-zA-Z0-9]/-}"
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
# Initialize workflow for a URL
#######################################
init_workflow_for_url() {
    local url="$1"
    local state_file
    state_file=$(get_state_file "$url")
    workflow_init "$state_file" "$PHASES_DIR" "$TOTAL_PHASES" "$url" "URL"
}

#######################################
# Initial state callback - creates state with URL info
# Called by workflow_cmd_next when no state exists
#######################################
workflow_create_initial_state() {
    local url="$WORKFLOW_IDENTIFIER"
    local slug now state_file
    slug=$(url_to_slug "$url")
    now=$(workflow_now)
    state_file="$WORKFLOW_STATE_FILE"

    local template="$SKILL_DIR/templates/analysis-state.json"
    if [[ -f "$template" ]]; then
        jq --arg url "$url" --arg slug "$slug" --arg now "$now" \
            '.url = $url | .url_slug = $slug | .started_at = $now | .phase = 1 | .last_updated = $now' \
            "$template" > "$state_file"
    else
        echo "{\"url\": \"$url\", \"url_slug\": \"$slug\", \"phase\": 1, \"started_at\": \"$now\", \"last_updated\": \"$now\"}" > "$state_file"
    fi
}

#######################################
# Context callback for progressive disclosure
#######################################
workflow_get_context() {
    local phase_num="$1"
    local state_file="$2"

    case "$phase_num" in
        2)
            jq '{url, mode, resource_metadata}' "$state_file"
            ;;
        3)
            jq '{url, resource_metadata: {title: .resource_metadata.title, kagi_takeaways: .resource_metadata.kagi_takeaways}, agent_analysis, human_analysis}' "$state_file"
            ;;
        4)
            jq '{url, mode, existing_node_id, resource_metadata: {title: .resource_metadata.title}, consolidated_summary, suggested_tags, suggested_relationships}' "$state_file"
            ;;
    esac
}

#######################################
# Completion callback
#######################################
workflow_on_complete() {
    echo "Curation for this URL has been completed."
    echo "Use 'clean -u URL' to start fresh if needed."
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
# Save command - merge JSON data into state
#######################################
cmd_save() {
    local url="$1"

    if [[ -z "$url" ]]; then
        echo "Error: save requires -u URL"
        exit 1
    fi

    init_workflow_for_url "$url"

    local state_file slug now input_json current_state new_state
    state_file=$(get_state_file "$url")
    slug=$(url_to_slug "$url")
    now=$(workflow_now)

    # Read JSON from stdin
    input_json=$(cat)

    if [[ -z "$input_json" ]]; then
        echo "Error: No JSON data provided on stdin"
        exit 1
    fi

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

    # Deep merge
    new_state=$(echo "$current_state" | jq --argjson input "$input_json" --arg now "$now" \
        '. * $input | .last_updated = $now')

    echo "$new_state" > "$state_file"
    echo "State saved for: $url"
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

    # Parse command
    if [[ $# -gt 0 && "${1:0:1}" != "-" ]]; then
        cmd="$1"
        shift
    fi

    # Parse options
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
            if [[ -z "$url" ]]; then
                echo "Error: next requires -u URL"
                exit 1
            fi
            init_workflow_for_url "$url"
            workflow_cmd_next
            ;;
        gate)
            if [[ -z "$url" ]]; then
                echo "Error: gate requires -u URL"
                exit 1
            fi
            init_workflow_for_url "$url"
            workflow_cmd_gate
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
            init_workflow_for_url "$url"
            workflow_get_phase
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
