# MCP Tool Contracts: Knowledge Curation Skill

**Date**: 2026-01-08

## Overview

This document defines the MCP tool usage patterns for each phase of the knowledge curation workflow.

---

## Phase 1: Reference Input

### Check for Duplicate URL

**Tool**: `mcp__helix-memory__init` + `mcp__helix-memory__search_keyword`

```
1. init() → connection_id
2. search_keyword(connection_id, query=url, label="Source", limit=1)
3. If results: mode="update", existing_node_id from result
4. Else: mode="create"
```

### Fetch URL Metadata

**Tool**: `WebFetch`

```
WebFetch(url, prompt="Extract: title, description, author, published date")
```

---

## Phase 2: Parallel Analysis

### Agent Analysis (Background)

**Tool**: `Task` with `run_in_background=true`

```
Task(
  subagent_type: "general-purpose",
  run_in_background: true,
  prompt: "Analyze {url}. Extract: main idea, key points (5-7), suggested tags. Output as JSON.",
  timeout: 120000
)
```

**Output stored in state**:
```json
{
  "agent_analysis": {
    "status": "complete",
    "main_idea": "...",
    "key_points": ["...", "..."],
    "suggested_tags": ["...", "..."]
  }
}
```

### Human Analysis (Foreground)

**Tool**: `AskUserQuestion`

```
AskUserQuestion(
  questions: [{
    question: "After reading the resource, what are your key takeaways?",
    header: "Takeaways",
    options: [
      { label: "Enter takeaways", description: "Provide 3-5 key insights" }
    ],
    multiSelect: false
  }]
)
```

---

## Phase 3: Collaborative Discussion

No MCP tools required. Agent presents both analyses and facilitates discussion via conversation.

---

## Phase 4: Knowledge Persistence

### Find Related Nodes

**Tool**: `mcp__helix-memory__init` + `mcp__helix-memory__search_vector`

```
1. init() → connection_id
2. n_from_type(connection_id, node_type="KnowledgeEmbedding")
3. search_vector(connection_id, query=consolidated_summary.main_idea, k=5, min_score=0.7)
4. in_step(connection_id, edge_type="node", edge_label="has_embedding") → related nodes
5. collect(connection_id) → suggested relationships
```

### Get Existing Tags

**Tool**: `mcp__helix-memory__list_all_tags`

```
list_all_tags() → existing tags for suggestion matching
```

### Create Knowledge Node

**Tool**: `mcp__helix-memory__create_knowledge_node`

```
create_knowledge_node(
  title: consolidated_summary.title,
  main_idea: consolidated_summary.main_idea,
  content: consolidated_summary.content,
  status: "raw",
  created_at: ISO timestamp,
  updated_at: ISO timestamp,
  source_url: state.url,
  source_title: state.resource_metadata.title
)
```

**Returns**: node_id

### Update Existing Node (if mode="update")

**Tool**: `mcp__helix-memory__update_knowledge_node`

```
update_knowledge_node(
  node_id: state.existing_node_id,
  title: consolidated_summary.title,
  main_idea: consolidated_summary.main_idea,
  content: merged_content,
  status: existing_status,
  updated_at: ISO timestamp
)
```

### Add Tags

**Tool**: `mcp__helix-memory__add_tag_to_node`

```
For each confirmed tag:
  add_tag_to_node(node_id, tag_value)
```

### Create Relationships

**Tool**: `mcp__helix-memory__create_relationship`

```
For each confirmed relationship:
  create_relationship(
    from_node_id: created_node_id,
    to_node_id: relationship.to_node_id,
    relationship_type: relationship.type
  )
```

### Discover Veille Folder

**Tool**: `mcp__obsidian__list_directory`

```
list_directory(path="/") → find "veille" folder
```

### Create Veille Note

**Tool**: `mcp__obsidian__write_note`

```
write_note(
  path: "veille/{YYYY-MM-DD}-{slug}.md",
  content: formatted_markdown,
  frontmatter: {
    title: consolidated_summary.title,
    source: state.url,
    created: ISO date,
    tags: confirmed_tags,
    helix_node_id: created_node_id
  },
  mode: "overwrite"
)
```

---

## Error Handling

| Scenario | Response |
|----------|----------|
| MCP connection failed | Abort with clear error, preserve state |
| Helix write failed | Retry once, then abort with state preserved |
| Obsidian write failed | Warn user, Helix node already created |
| Duplicate URL detected | Switch to update mode automatically |
| Agent timeout | Use partial results, mark as timeout |

---

## Tool Dependencies by Phase

| Phase | Required Tools |
|-------|---------------|
| 1 | WebFetch, helix-memory (search) |
| 2 | Task (background), AskUserQuestion |
| 3 | None (conversation only) |
| 4 | helix-memory (all), obsidian (write, list) |
