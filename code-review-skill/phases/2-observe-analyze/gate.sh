#!/usr/bin/env bash
# Gate 2: Observation and analysis complete
# Passes if files list exists AND agent_findings is an array

STATE_FILE="$1"

files_count=$(jq '.files | length // 0' "$STATE_FILE")
findings_type=$(jq -r '.agent_findings | type' "$STATE_FILE")
dev_url=$(jq -r '.dev_url // empty' "$STATE_FILE")
live_check=$(jq -r '.live_check_done // empty' "$STATE_FILE")
a11y_check=$(jq -r '.a11y_check_done // empty' "$STATE_FILE")
has_jsx=$(jq -r '[.files // [] | .[] | select(test("\\.(tsx|jsx|html|vue|svelte)$"))] | length > 0' "$STATE_FILE")

errors=()

if [[ "$files_count" -eq 0 ]]; then
  errors+=("files list saved (run list-changes and save with 'set files')")
fi

if [[ "$findings_type" != "array" ]]; then
  errors+=("agent_findings saved as array (save with 'set agent_findings')")
fi

# Live verification is only required when a dev URL is known.
# Without a URL, there is nothing to verify live — the gate skips silently.
if [[ -n "$dev_url" && -z "$live_check" ]]; then
  errors+=("live_check_done set (dev_url is known, run live verification via chrome-devtools-mcp on $dev_url)")
fi

# Live a11y check is required when JSX/HTML/template files are touched
# AND a dev URL is known (otherwise no app to audit).
if [[ -n "$dev_url" && "$has_jsx" == "true" && -z "$a11y_check" ]]; then
  errors+=("a11y_check_done set (UI files changed, run skill chrome-devtools-mcp:a11y-debugging on $dev_url)")
fi

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "  Need:" >&2
  for err in "${errors[@]}"; do
    echo "    - $err" >&2
  done
  exit 1
fi

exit 0
