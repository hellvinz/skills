#!/usr/bin/env bash
# read-docs.sh - Read project documentation files
# Returns content of CLAUDE.md, AGENTS.md, ARCHITECTURE.md, and ADRs
set -e

JSON_MODE=false
[[ "$1" == "--json" ]] && JSON_MODE=true

# Helper to escape JSON strings
json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || \
  jq -Rs '.' 2>/dev/null || \
  cat
}

# Read files
CLAUDE_MD=""
AGENTS_MD=""
ARCHITECTURE_MD=""
ADRS=""

[ -f CLAUDE.md ] && CLAUDE_MD=$(cat CLAUDE.md)
[ -f AGENTS.md ] && AGENTS_MD=$(cat AGENTS.md)
[ -f ARCHITECTURE.md ] && ARCHITECTURE_MD=$(cat ARCHITECTURE.md)

# Read ADRs
if [ -d docs/adr ]; then
  for f in docs/adr/*.md; do
    [ -f "$f" ] && ADRS+="=== $f ===$"$'\n'"$(cat "$f")"$'\n\n'
  done
fi

if $JSON_MODE; then
  cat <<EOF
{
  "claude_md": $(echo "$CLAUDE_MD" | json_escape),
  "agents_md": $(echo "$AGENTS_MD" | json_escape),
  "architecture_md": $(echo "$ARCHITECTURE_MD" | json_escape),
  "adrs": $(echo "$ADRS" | json_escape)
}
EOF
else
  if [ -n "$CLAUDE_MD" ]; then
    echo "=== CLAUDE.md ==="
    echo "$CLAUDE_MD"
    echo ""
  fi

  if [ -n "$AGENTS_MD" ]; then
    echo "=== AGENTS.md ==="
    echo "$AGENTS_MD"
    echo ""
  fi

  if [ -n "$ARCHITECTURE_MD" ]; then
    echo "=== ARCHITECTURE.md ==="
    echo "$ARCHITECTURE_MD"
    echo ""
  fi

  if [ -n "$ADRS" ]; then
    echo "=== ADRs ==="
    echo "$ADRS"
  fi

  if [ -z "$CLAUDE_MD" ] && [ -z "$AGENTS_MD" ] && [ -z "$ARCHITECTURE_MD" ] && [ -z "$ADRS" ]; then
    echo "No project documentation found."
  fi
fi
