# Phase 4: Knowledge Persistence

> **STOP - READ THIS FIRST**
>
> All tools below are CLAUDE TOOLS. Call them directly like `Read` or `Bash`.
>
> **NEVER** create Python scripts, bash wrappers, or any code to call MCP tools.
> **NEVER** use `uv run`, `python -c`, or import statements.

## Purpose

Save the consolidated knowledge to Helix (knowledge graph) and Obsidian (veille notes), with user confirmation before each write.

## Inputs

Use the data from **CONTEXT FROM PREVIOUS PHASES** above:
- `url`, `mode`, `existing_node_id` (if update mode)
- `resource_metadata.title`
- `consolidated_summary` (title, main_idea, content, key_takeaways)

## Actions

### 1. Find Related Nodes (for suggestions)

Use semantic search to find related knowledge:

```
1. mcp__helix-memory__init() → connection_id
2. mcp__helix-memory__n_from_type(connection_id, node_type="KnowledgeEmbedding")
3. mcp__helix-memory__search_vector(
     connection_id,
     query=consolidated_summary.main_idea,
     k=5,
     min_score=0.7
   )
4. mcp__helix-memory__in_step(connection_id, edge_type="node", edge_label="has_embedding")
5. mcp__helix-memory__collect(connection_id) → related nodes
```

### 2. Get Existing Tags

Fetch all tags for reuse suggestions:

```
mcp__helix-memory__list_all_tags() → existing_tags
```

### 3. Suggest Tags and Relationships

Present suggestions to the user:

```markdown
## Suggested Tags

Based on content and existing tags:
- [x] agents (existing)
- [x] architecture (existing)
- [ ] anthropic (new tag)

## Suggested Relationships

Based on semantic similarity:
- [ ] **relates_to**: "Context Engineering Patterns" (score: 0.82)
- [ ] **builds_on**: "LLM Best Practices" (score: 0.75)
```

Use `AskUserQuestion` with multiSelect for tag/relationship confirmation.

### 4. Confirm Before Writing

```markdown
## Ready to Save

**Helix Knowledge Node:**
- Title: {consolidated_summary.title}
- Tags: {selected_tags}
- Relationships: {selected_relationships}

**Obsidian Note:**
- Path: veille/{date}-{slug}.md
- Linked to Helix node

Proceed with saving?
```

### 5. Create Helix Node

For new nodes (mode=create):

```
mcp__helix-memory__create_knowledge_node(
  title: consolidated_summary.title,
  main_idea: consolidated_summary.main_idea,
  content: consolidated_summary.content,
  status: "raw",
  created_at: <ISO timestamp>,
  updated_at: <ISO timestamp>,
  source_url: url,
  source_title: resource_metadata.title
)
```

For updates (mode=update):

```
mcp__helix-memory__update_knowledge_node(
  node_id: existing_node_id,
  title: consolidated_summary.title,
  main_idea: consolidated_summary.main_idea,
  content: <merged content>,
  updated_at: <ISO timestamp>
)
```

### 6. Add Tags

For each confirmed tag:

```
mcp__helix-memory__add_tag_to_node(node_id, tag_value)
```

### 7. Create Relationships

For each confirmed relationship:

```
mcp__helix-memory__create_relationship(
  from_node_id: created_node_id,
  to_node_id: relationship.to_node_id,
  relationship_type: relationship.type
)
```

### 8. Discover Veille Folder

```
mcp__obsidian__list_directory(path="/") → find "veille" folder
```

### 9. Create Obsidian Note

Use the veille note template:

```
mcp__obsidian__write_note(
  path: "veille/{YYYY-MM-DD}-{url_slug}.md",
  content: <formatted from template>,
  frontmatter: {
    title: consolidated_summary.title,
    source: url,
    created: <ISO date>,
    tags: confirmed_tags,
    helix_node_id: created_node_id
  },
  mode: "overwrite"
)
```

### 10. Save State with Results

```bash
echo '{
  "result": {
    "helix_node_id": "<created node id>",
    "obsidian_note_path": "veille/2026-01-08-example-article.md"
  }
}' | ./scripts/curation.sh save -u "$URL"
```

### 11. Confirm Completion

```markdown
## Curation Complete

✅ Created Helix node: {helix_node_id}
✅ Created veille note: {obsidian_note_path}

Tags: {tags}
Relationships: {relationships}

The knowledge has been saved to your knowledge base.
```

## Gate Criteria

Phase 4 gate verifies:
1. Helix node ID is recorded in result
2. Obsidian note path is recorded in result
3. Both write confirmations received

Run the gate check:

```bash
./scripts/curation.sh gate -u "$URL"
```

## Completion

After the gate passes, the curation workflow is complete. The state file can be cleaned up:

```bash
./scripts/curation.sh clean -u "$URL"
```
