#!/usr/bin/env bash
# suggest-links.sh - Find related knowledge nodes for linking suggestions
#
# Usage:
#   ./scripts/suggest-links.sh <query_text>
#
# This script documents the MCP tool sequence for finding related nodes.
# The agent must execute these MCP calls directly.
#
# MCP Tool Sequence:
#   1. mcp__helix-memory__init() → connection_id
#   2. mcp__helix-memory__n_from_type(connection_id, node_type="KnowledgeEmbedding")
#   3. mcp__helix-memory__search_vector(connection_id, query=<main_idea>, k=5, min_score=0.7)
#   4. mcp__helix-memory__in_step(connection_id, edge_type="node", edge_label="has_embedding")
#   5. mcp__helix-memory__collect(connection_id) → related nodes
#
# Relationship Types:
#   - relates_to: General topical connection
#   - builds_on: This content extends/deepens the related content
#   - contradicts: This content disagrees with the related content
#   - supersedes: This content replaces/updates the related content

set -euo pipefail

usage() {
    cat <<EOF
Usage: suggest-links.sh <query_text>

Find related knowledge nodes using semantic search.

NOTE: This script documents the MCP tool sequence. The agent must
execute these MCP calls directly.

MCP Tool Sequence:
  1. mcp__helix-memory__init() → connection_id
  2. mcp__helix-memory__n_from_type(connection_id, node_type="KnowledgeEmbedding")
  3. mcp__helix-memory__search_vector(
       connection_id,
       query=<main_idea>,
       k=5,
       min_score=0.7
     )
  4. mcp__helix-memory__in_step(
       connection_id,
       edge_type="node",
       edge_label="has_embedding"
     )
  5. mcp__helix-memory__collect(connection_id) → related nodes

Relationship Types:
  - relates_to: General topical connection
  - builds_on: Extends/deepens related content
  - contradicts: Disagrees with related content
  - supersedes: Replaces/updates related content

Options:
  -h, --help    Show this help message
EOF
}

QUERY="${1:-}"

if [[ "$QUERY" == "-h" || "$QUERY" == "--help" ]]; then
    usage
    exit 0
fi

if [[ -z "$QUERY" ]]; then
    echo "Error: Query text required" >&2
    usage
    exit 1
fi

cat <<EOF
To find related nodes for: "$QUERY"

The agent should execute:

1. Initialize connection:
   connection_id = mcp__helix-memory__init()

2. Start from embeddings:
   mcp__helix-memory__n_from_type(connection_id, "KnowledgeEmbedding")

3. Search by semantic similarity:
   mcp__helix-memory__search_vector(
     connection_id,
     query="$QUERY",
     k=5,
     min_score=0.7
   )

4. Navigate to parent nodes:
   mcp__helix-memory__in_step(connection_id, "node", "has_embedding")

5. Collect results:
   results = mcp__helix-memory__collect(connection_id)

For each result, suggest a relationship type based on content analysis.
EOF
