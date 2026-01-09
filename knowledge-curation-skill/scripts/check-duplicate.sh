#!/usr/bin/env bash
# check-duplicate.sh - Check if URL already exists in Helix knowledge base
#
# Usage:
#   ./scripts/check-duplicate.sh <url>
#
# This script provides guidance for the agent to check for duplicates.
# The actual check uses MCP tools which must be called by the agent directly.
#
# MCP Tool Sequence:
#   1. mcp__helix-memory__init() → connection_id
#   2. mcp__helix-memory__search_keyword(
#        connection_id=connection_id,
#        query=<url>,
#        label="Source",
#        limit=1
#      )
#   3. If results found → mode="update", extract existing_node_id
#   4. If no results → mode="create"
#
# Output (simulated):
#   { "mode": "create" }
#   or
#   { "mode": "update", "existing_node_id": "...", "existing_title": "..." }

set -euo pipefail

usage() {
    cat <<EOF
Usage: check-duplicate.sh <url>

Check if a URL already exists in the Helix knowledge base.

NOTE: This script cannot directly call MCP tools. The agent must use
the MCP tools as documented below.

MCP Tool Sequence:
  1. mcp__helix-memory__init() → connection_id
  2. mcp__helix-memory__search_keyword(
       connection_id=connection_id,
       query=<url>,
       label="Source",
       limit=1
     )
  3. Parse results:
     - Found → mode="update", record existing_node_id
     - Not found → mode="create"

Options:
  -h, --help    Show this help message
EOF
}

# Parse arguments
URL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            URL="$1"
            shift
            ;;
    esac
done

if [[ -z "$URL" ]]; then
    echo "Error: URL is required" >&2
    usage
    exit 1
fi

# This script serves as documentation - actual check requires MCP tools
cat <<EOF
To check for duplicates, the agent should:

1. Initialize Helix connection:
   mcp__helix-memory__init()

2. Search for existing source with this URL:
   mcp__helix-memory__search_keyword(
     connection_id=<from step 1>,
     query="$URL",
     label="Source",
     limit=1
   )

3. If results are returned:
   - Set mode="update"
   - Extract existing_node_id from the result
   - Optionally fetch the existing node for comparison

4. If no results:
   - Set mode="create"

The result should be stored in the state file as:
{
  "mode": "create|update",
  "existing_node_id": "<id if update mode>"
}
EOF
