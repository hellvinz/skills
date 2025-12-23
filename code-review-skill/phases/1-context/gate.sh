#!/usr/bin/env bash
# Gate 1: Context gathered
# Passes if context has been saved to state

STATE_FILE="$1"

# Check that context exists in state
context=$(jq -r '.context // empty' "$STATE_FILE")

if [[ -z "$context" || "$context" == "null" ]]; then
  echo "  Need: context saved (run gather-context and save with 'set context')" >&2
  exit 1
fi

exit 0
