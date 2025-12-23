#!/usr/bin/env bash
# review.sh - Code review workflow state machine (generic JSON store)

# Relaunch as user's login shell to get aliases
if [ -z "$_LOGIN_SHELL_SOURCED" ]; then
  export _LOGIN_SHELL_SOURCED=1
  "$SHELL" -l "$0" "$@" 2>&1 | sed $'s/\x1b][0-9]*;[^\x07]*\x07//g'
  exit $?
fi

set -e

REVIEW_DIR=".review"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BRANCH=$(git branch --show-current)
BRANCH_SAFE="${BRANCH//\//-}"
STATE_FILE="$REVIEW_DIR/state-${BRANCH_SAFE}.json"

CMD="${1:-status}"
shift || true

now() {
  date -Iseconds
}

get_current_phase() {
  jq -r '.phase' "$STATE_FILE"
}

get_phase_dir() {
  local phase_num="$1"
  # Find directory matching pattern N-*
  local dir
  dir=$(find "$SKILL_DIR/phases" -maxdepth 1 -type d -name "${phase_num}-*" | head -1)
  echo "$dir"
}

output_phase_instructions() {
  local phase_num="$1"
  local phase_dir
  phase_dir=$(get_phase_dir "$phase_num")

  if [[ -d "$phase_dir" && -f "$phase_dir/instructions.md" ]]; then
    echo ""
    echo "================================================================================"
    cat "$phase_dir/instructions.md"
    echo "================================================================================"
  fi
}

# === Core commands ===

init_state() {
  mkdir -p "$REVIEW_DIR"
  cat > "$STATE_FILE" <<EOF
{
  "branch": "$BRANCH",
  "phase": 1,
  "started_at": "$(now)",
  "last_updated": "$(now)"
}
EOF
  echo "Initialized review state for $BRANCH"
  output_phase_instructions 1
}

set_value() {
  local key="$1"
  local json="$2"

  if [[ ! -f "$STATE_FILE" ]]; then
    echo "Error: No review in progress. Run 'init' first." >&2
    exit 1
  fi

  if ! echo "$json" | jq . > /dev/null 2>&1; then
    echo "Error: Invalid JSON" >&2
    exit 1
  fi

  jq --arg k "$key" --argjson v "$json" --arg t "$(now)" \
    '.[$k] = $v | .last_updated = $t' \
    "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
}

get_value() {
  local key="$1"

  if [[ ! -f "$STATE_FILE" ]]; then
    echo "null"
    exit 0
  fi

  jq -r --arg k "$key" '.[$k] // null' "$STATE_FILE"
}

check_gate() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "Error: No review in progress. Run 'init' first." >&2
    exit 1
  fi

  local phase_num
  phase_num=$(get_current_phase)
  local phase_dir
  phase_dir=$(get_phase_dir "$phase_num")

  if [[ ! -f "$phase_dir/gate.sh" ]]; then
    echo "Error: No gate.sh found for phase $phase_num" >&2
    exit 1
  fi

  # Run gate script with state file path
  if bash "$phase_dir/gate.sh" "$STATE_FILE" "$REVIEW_DIR" "$BRANCH_SAFE"; then
    jq --argjson p "$phase_num" --arg t "$(now)" \
      '.gates[$p | tostring] = {"passed": true, "at": $t} | .last_updated = $t' \
      "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    echo "Gate: PASSED"
  else
    echo "Gate: FAILED"
    exit 1
  fi
}

advance_phase() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "Error: No review in progress." >&2
    exit 1
  fi

  local current_phase
  current_phase=$(get_current_phase)

  local gate_passed
  gate_passed=$(jq -r ".gates[\"$current_phase\"].passed // false" "$STATE_FILE")

  if [[ "$gate_passed" != "true" ]]; then
    echo "Error: Gate not passed. Run 'check-gate' first." >&2
    exit 1
  fi

  local next_phase=$((current_phase + 1))
  local next_dir
  next_dir=$(get_phase_dir "$next_phase")

  if [[ -z "$next_dir" ]]; then
    echo "Review complete."
    exit 0
  fi

  jq --argjson p "$next_phase" --arg t "$(now)" \
    '.phase = $p | .last_updated = $t' \
    "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

  local phase_name
  phase_name=$(basename "$next_dir" | sed 's/^[0-9]*-//')
  echo "Phase $next_phase: $phase_name"
  output_phase_instructions "$next_phase"
}

show_context() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "No review in progress."
    exit 0
  fi

  local phase_num
  phase_num=$(get_current_phase)
  local phase_dir
  phase_dir=$(get_phase_dir "$phase_num")

  if [[ -f "$phase_dir/format.sh" ]]; then
    bash "$phase_dir/format.sh" "$STATE_FILE"
  else
    # Default: just dump the state
    cat "$STATE_FILE"
  fi
}

show_status() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "No review in progress."
    exit 0
  fi

  cat "$STATE_FILE"
}

clean() {
  local comments_file="$REVIEW_DIR/comments-${BRANCH_SAFE}.json"
  rm -f "$STATE_FILE" "$comments_file"
  echo "Cleaned up review files for $BRANCH"
}

case "$CMD" in
  init)
    init_state
    ;;
  set)
    set_value "$1" "$2"
    ;;
  get)
    get_value "$1"
    ;;
  check-gate)
    check_gate
    ;;
  next)
    advance_phase
    ;;
  context)
    show_context
    ;;
  status)
    show_status
    ;;
  clean)
    clean
    ;;
  *)
    echo "Usage: review.sh <command> [args]"
    echo ""
    echo "Workflow commands:"
    echo "  init                    Start new review"
    echo "  check-gate              Verify current phase gate"
    echo "  next                    Advance to next phase"
    echo "  context                 Show context for current phase"
    echo "  status                  Show raw state (JSON)"
    echo "  clean                   Remove state and comments files"
    echo ""
    echo "Data commands:"
    echo "  set <key> <json>        Store JSON value"
    echo "  get <key>               Retrieve JSON value"
    ;;
esac
