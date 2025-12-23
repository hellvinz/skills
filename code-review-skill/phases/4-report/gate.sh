#!/usr/bin/env bash
# Gate 4: Analysis complete
# Passes if findings is an array (not null)

STATE_FILE="$1"

findings_type=$(jq -r '.findings | type' "$STATE_FILE")

if [[ "$findings_type" != "array" ]]; then
  echo "  Need: findings saved as array (save with 'set findings')" >&2
  exit 1
fi

exit 0
