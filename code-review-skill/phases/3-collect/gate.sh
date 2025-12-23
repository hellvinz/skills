#!/usr/bin/env bash
# Gate 3: Human collection complete and findings merged
# Passes if human_done is true AND findings array exists

STATE_FILE="$1"

errors=()

human_done=$(jq -r '.human_done // false' "$STATE_FILE")
findings_type=$(jq -r '.findings | type' "$STATE_FILE")

if [[ "$human_done" != "true" ]]; then
  errors+=("human_done set to true")
fi

if [[ "$findings_type" != "array" ]]; then
  errors+=("findings merged (run merge-findings)")
fi

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "  Need:" >&2
  for err in "${errors[@]}"; do
    echo "    - $err" >&2
  done
  exit 1
fi

exit 0
