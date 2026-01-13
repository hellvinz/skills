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

cmd_next() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "Error: No review in progress. Run 'init' first." >&2
    exit 1
  fi

  local phase_num phase_dir
  phase_num=$(get_current_phase)
  phase_dir=$(get_phase_dir "$phase_num")

  # Check if current gate passes - if so, advance to next phase
  if [[ -n "$phase_dir" && -f "$phase_dir/gate.sh" ]]; then
    if bash "$phase_dir/gate.sh" "$STATE_FILE" "$REVIEW_DIR" "$BRANCH_SAFE" 2>/dev/null; then
      # Gate passed - record it and advance
      local next_phase=$((phase_num + 1))
      local next_dir
      next_dir=$(get_phase_dir "$next_phase")

      if [[ -z "$next_dir" ]]; then
        echo "=== REVIEW COMPLETE ==="
        echo ""
        echo "All phases completed for branch: $BRANCH"
        echo "Use 'clean' to start fresh if needed."
        exit 0
      fi

      jq --argjson p "$phase_num" --argjson np "$next_phase" --arg t "$(now)" \
        '.gates[$p | tostring] = {"passed": true, "at": $t} | .phase = $np | .last_updated = $t' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

      echo ">>> Gate $phase_num passed. Advanced to phase $next_phase."
      echo ""
      phase_num=$next_phase
      phase_dir=$(get_phase_dir "$phase_num")
    fi
  fi

  # Output current phase header
  local phase_name
  phase_name=$(basename "$phase_dir" | sed 's/^[0-9]*-//')
  echo "=== PHASE $phase_num: $phase_name ==="
  echo "Branch: $BRANCH"
  echo ""

  # Output context from previous phases (if format.sh exists)
  if [[ "$phase_num" -gt 1 && -f "$phase_dir/format.sh" ]]; then
    echo "--- CONTEXT FROM PREVIOUS PHASES ---"
    echo ""
    bash "$phase_dir/format.sh" "$STATE_FILE"
    echo ""
  fi

  # Output instructions
  echo "--- INSTRUCTIONS ---"
  output_phase_instructions "$phase_num"
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
  gate)
    check_gate
    ;;
  next)
    cmd_next
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
    echo "  init                    Start new review (outputs phase 1 instructions)"
    echo "  next                    Check gate, advance if passed, show instructions"
    echo "  gate                    Check gate only (without advancing)"
    echo "  context                 Show context for current phase"
    echo "  status                  Show raw state (JSON)"
    echo "  clean                   Remove state and comments files"
    echo ""
    echo "Data commands:"
    echo "  set <key> <json>        Store JSON value"
    echo "  get <key>               Retrieve JSON value"
    ;;
esac
