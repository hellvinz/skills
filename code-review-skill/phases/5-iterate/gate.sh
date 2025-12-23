#!/usr/bin/env bash
# Gate 5: All findings addressed
# Passes if no pending findings remain

STATE_FILE="$1"

pending=$(jq '[.findings // [] | .[] | select(.status == "pending")] | length' "$STATE_FILE")

if [[ "$pending" -gt 0 ]]; then
  echo "  Need: all findings addressed or skipped ($pending pending)" >&2
  exit 1
fi

exit 0
