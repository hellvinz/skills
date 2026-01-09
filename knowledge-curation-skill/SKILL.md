---
name: knowledge-curation
description: |
  Collaborative knowledge curation from web resources to Helix and Obsidian.

  Triggers:
  - /knowledge-curation <url>
  - "curate this: <url>"
  - "add to knowledge base: <url>"
  - "veille: <url>"
  - "I want to curate <url>"
tools: Read, Grep, Glob, Bash, WebFetch, Task, TaskOutput, AskUserQuestion, mcp__kagi__kagi_summarizer, mcp__helix-memory__init, mcp__helix-memory__collect, mcp__helix-memory__search_keyword, mcp__helix-memory__search_vector, mcp__helix-memory__create_knowledge_node, mcp__helix-memory__update_knowledge_node, mcp__helix-memory__get_knowledge_node, mcp__helix-memory__list_knowledge_nodes, mcp__helix-memory__list_all_tags, mcp__helix-memory__add_tag_to_node, mcp__helix-memory__create_relationship, mcp__helix-memory__get_node_sources, mcp__helix-memory__add_source_to_node, mcp__helix-memory__n_from_type, mcp__helix-memory__in_step, mcp__helix-memory__add_embedding_to_node, mcp__obsidian__read_note, mcp__obsidian__write_note, mcp__obsidian__list_directory, mcp__obsidian__search_notes
---

# Knowledge Curation Skill

> **CRITICAL: MCP TOOLS ARE CLAUDE TOOLS**
>
> `mcp__helix-memory__*`, `mcp__kagi__*`, `mcp__obsidian__*` are native Claude tools.
> Invoke them DIRECTLY like `Read` or `Bash`. Example: `mcp__helix-memory__init()`
>
> **FORBIDDEN**: Python scripts, `uv run`, `python -c`, bash wrappers, imports.
> If you write Python to call MCP, you are doing it WRONG.

Curate knowledge from web resources through a collaborative 4-phase workflow.

## Getting Started

When triggered with a URL, run:

```bash
./scripts/curation.sh next -u "$URL"
```

This returns the instructions for the current phase. Follow them exactly.

## Workflow Loop

1. Run `next -u URL` to get current phase instructions (auto-advances if gate passes)
2. Execute the instructions
3. Save data via `save -u URL` (do NOT include "phase" - managed automatically)
4. Run `next -u URL` again to advance to next phase
5. Repeat until complete

## Commands

```bash
# Get instructions (auto-advances phase if gate passes)
./scripts/curation.sh next -u "$URL"

# Save data to state (pipe JSON to stdin, NO "phase" field)
echo '{"key": "value", ...}' | ./scripts/curation.sh save -u "$URL"

# Check gate status (optional feedback)
./scripts/curation.sh gate -u "$URL"

# Check status / clean
./scripts/curation.sh status -u "$URL"
./scripts/curation.sh clean -u "$URL"
```
