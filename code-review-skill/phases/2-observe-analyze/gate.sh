#!/usr/bin/env bash
# Gate 2: Observation and analysis complete
# Passes if files list exists AND agent_findings is an array

STATE_FILE="$1"

files_count=$(jq '.files | length // 0' "$STATE_FILE")
findings_type=$(jq -r '.agent_findings | type' "$STATE_FILE")

errors=()

if [[ "$files_count" -eq 0 ]]; then
  errors+=("files list saved (run list-changes and save with 'set files')")
fi

if [[ "$findings_type" != "array" ]]; then
  errors+=("agent_findings saved as array (save with 'set agent_findings')")
fi

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "  Need:" >&2
  for err in "${errors[@]}"; do
    echo "    - $err" >&2
  done
  exit 1
fi

exit 0
