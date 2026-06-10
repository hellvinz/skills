#!/usr/bin/env bash
# review.sh - Code review workflow state machine
#
# Usage:
#   ./scripts/review.sh next          Start or continue (auto-creates state)
#   ./scripts/review.sh gate          Check gate only
#   ./scripts/review.sh status        Show raw state (JSON)
#   ./scripts/review.sh context       Show context for current phase
#   ./scripts/review.sh set <k> <v>   Store JSON value
#   ./scripts/review.sh get <k>       Retrieve JSON value
#   ./scripts/review.sh clean         Remove state files
#   ./scripts/review.sh init-config   Create .review/config.md from template
#
# set takes ONE JSON value as a single argument — quote it for the shell:
#   review.sh set my_key '"some text"'
#   review.sh set my_key '{"a": 1, "b": [2, 3]}'
#   review.sh set my_key "$(jq -Rs . < file.md)"   # store a file as a JSON string

# --help: print the header doc block of this script
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
    exit 0
fi

# Determine script directory before login shell relaunch
# Use pwd -P to resolve symlinks
if [ -z "$_SCRIPT_DIR" ]; then
    _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
    export _SCRIPT_DIR
fi

# Relaunch as user's login shell to get aliases
if [ -z "$_LOGIN_SHELL_SOURCED" ]; then
  export _LOGIN_SHELL_SOURCED=1
  "$SHELL" -l "$0" "$@" 2>&1 | sed $'s/\x1b][0-9]*;[^\x07]*\x07//g'
  # exit $? would return sed's status (always 0); take the script's instead
  exit "${PIPESTATUS[0]}"
fi

set -euo pipefail

SCRIPT_DIR="$_SCRIPT_DIR"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$(dirname "$SKILL_DIR")/scripts/lib"

# Source workflow library
# shellcheck source=../../scripts/lib/workflow.sh
source "$LIB_DIR/workflow.sh"

# Configuration
REVIEW_DIR=".review"
BRANCH=$(git branch --show-current)
BRANCH_SAFE="${BRANCH//\//-}"
STATE_FILE="$REVIEW_DIR/state-${BRANCH_SAFE}.json"
PHASES_DIR="$SKILL_DIR/phases"
TOTAL_PHASES=6

# Initialize workflow library
workflow_init "$STATE_FILE" "$PHASES_DIR" "$TOTAL_PHASES" "$BRANCH" "Branch"

# Ensure state directory exists
mkdir -p "$REVIEW_DIR"

CMD="${1:-status}"
shift || true

#######################################
# Initial state callback - creates state with branch info
#######################################
workflow_create_initial_state() {
    local now
    now=$(workflow_now)
    mkdir -p "$REVIEW_DIR"
    cat > "$STATE_FILE" <<EOF
{
  "branch": "$BRANCH",
  "phase": 1,
  "started_at": "$now",
  "last_updated": "$now"
}
EOF
}

#######################################
# Context command - show formatted context
#######################################
cmd_context() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "No review in progress."
        exit 0
    fi

    local phase_num
    phase_num=$(workflow_get_phase)
    workflow_output_context "$phase_num"
}

#######################################
# Restart command - new review round, keep findings
#######################################
cmd_restart() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "No review to restart. Use 'next' to start a new review."
        exit 1
    fi

    local phase
    phase=$(workflow_get_phase)
    if [[ "$phase" -ne "$TOTAL_PHASES" ]]; then
        echo "Error: restart is only available at phase $TOTAL_PHASES (current: $phase)" >&2
        exit 1
    fi

    jq --arg t "$(workflow_now)" '
        .round = ((.round // 1) + 1)
        | .phase = 1
        | .last_updated = $t
        | .findings = [.findings // [] | .[] | if .status == "commented" then .status = "pending" else . end]
        | del(.files, .agent_findings, .human_findings, .human_done, .scope, .principles, .gates)
    ' "$STATE_FILE" > "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"

    rm -f "$REVIEW_DIR/comments-${BRANCH_SAFE}.json"

    echo "Review reset to round $(jq -r '.round' "$STATE_FILE")."
}

#######################################
# Init-config command - bootstrap .review/config.md from template
#######################################
cmd_init_config() {
    local target=".review/config.md"
    local template="$SKILL_DIR/templates/project-config.md"

    if [[ -e "$target" ]]; then
        echo "Error: $target already exists. Refusing to overwrite." >&2
        exit 1
    fi

    if [[ ! -f "$template" ]]; then
        echo "Error: template not found at $template" >&2
        exit 1
    fi

    mkdir -p "$(dirname "$target")"
    cp "$template" "$target"
    echo "Created $target"
    echo "Edit it to add your dev URL, DS reference paths, and project conventions."
}

#######################################
# Clean command
#######################################
cmd_clean() {
    local comments_file="$REVIEW_DIR/comments-${BRANCH_SAFE}.json"
    rm -f "$STATE_FILE" "$comments_file"
    echo "Cleaned up review files for $BRANCH"
}

#######################################
# Workflow completion callback
#######################################
workflow_on_complete() {
    echo "All phases completed for branch: $BRANCH"
    echo "Use 'restart' to begin a new review round (keeps findings)."
    echo "Use 'clean' to remove all state."
}

#######################################
# Main dispatch
#######################################
case "$CMD" in
    next)
        workflow_cmd_next
        ;;
    gate)
        workflow_cmd_gate
        ;;
    context)
        cmd_context
        ;;
    status)
        workflow_cmd_status
        ;;
    set)
        workflow_set_value "$1" "$2"
        ;;
    get)
        workflow_get_value "$1"
        ;;
    restart)
        cmd_restart
        ;;
    clean)
        cmd_clean
        ;;
    init-config)
        cmd_init_config
        ;;
    *)
        echo "Usage: review.sh <command> [args]"
        echo ""
        echo "Workflow commands:"
        echo "  next                    Start or continue review (auto-creates state)"
        echo "  gate                    Check gate only (without advancing)"
        echo "  context                 Show context for current phase"
        echo "  status                  Show raw state (JSON)"
        echo "  restart                 Start new round (keeps findings)"
        echo "  clean                   Remove state and comments files"
        echo "  init-config             Create .review/config.md from template"
        echo ""
        echo "Data commands:"
        echo "  set <key> <json>        Store JSON value"
        echo "  get <key>               Retrieve JSON value"
        ;;
esac
