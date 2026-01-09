# Research: Knowledge Curation Skill

**Date**: 2026-01-08
**Branch**: `001-knowledge-curation-skill`

## Research Questions

1. What Helix MCP tools are available for knowledge node management?
2. What Obsidian MCP tools are available for veille note creation?
3. How to implement parallel agent/human analysis with background tasks?

---

## 1. Helix Memory MCP Tools

### Decision
Use the comprehensive Helix MCP tool set for knowledge graph operations.

### Available Tools

**Knowledge Node CRUD**:
| Tool | Purpose |
|------|---------|
| `mcp__helix-memory__create_knowledge_node` | Create node with title, main_idea, content, status, timestamps, source_url, source_title |
| `mcp__helix-memory__get_knowledge_node` | Retrieve by ID |
| `mcp__helix-memory__update_knowledge_node` | Update all fields |
| `mcp__helix-memory__delete_knowledge_node` | Delete node and edges |
| `mcp__helix-memory__list_knowledge_nodes` | List all nodes |

**Source & Tag Management**:
| Tool | Purpose |
|------|---------|
| `mcp__helix-memory__add_source_to_node` | Add URL+title source reference |
| `mcp__helix-memory__get_node_sources` | Get all sources for node |
| `mcp__helix-memory__add_tag_to_node` | Add tag to node |
| `mcp__helix-memory__get_node_tags` | Get all tags for node |
| `mcp__helix-memory__list_all_tags` | List all tags in system |
| `mcp__helix-memory__get_nodes_by_tag` | Find nodes by tag |

**Relationships**:
| Tool | Purpose |
|------|---------|
| `mcp__helix-memory__create_relationship` | Create edge (relates_to, builds_on, contradicts, supersedes) |
| `mcp__helix-memory__get_related_nodes_outgoing` | Get nodes this relates to |
| `mcp__helix-memory__get_related_nodes_incoming` | Get nodes that relate to this |

**Search & Discovery**:
| Tool | Purpose |
|------|---------|
| `mcp__helix-memory__search_vector` | Semantic similarity search |
| `mcp__helix-memory__search_keyword` | BM25 keyword search |
| `mcp__helix-memory__init` | Initialize traversal connection |
| `mcp__helix-memory__collect` | Collect traversal results |

### Key Parameters for create_knowledge_node
```
title: string (required)
main_idea: string (required)
content: string (required)
status: "raw" | "exploring" | "actionable" | "archived" (required)
created_at: ISO timestamp (required)
updated_at: ISO timestamp (required)
source_url: string (required)
source_title: string (required)
```

### Duplicate Detection Strategy
Use `search_keyword` with the URL as query against the Source entity type, or use graph traversal to find nodes with matching source URLs.

---

## 2. Obsidian MCP Tools

### Decision
Use write_note with MCP discovery for folder location.

### Available Tools

**Note Operations**:
| Tool | Purpose |
|------|---------|
| `mcp__obsidian__write_note` | Create/update note with content and frontmatter |
| `mcp__obsidian__read_note` | Read note content |
| `mcp__obsidian__patch_note` | Update specific string in note |
| `mcp__obsidian__list_directory` | List files in folder |
| `mcp__obsidian__search_notes` | Search by content or frontmatter |

**Frontmatter & Tags**:
| Tool | Purpose |
|------|---------|
| `mcp__obsidian__update_frontmatter` | Update note metadata |
| `mcp__obsidian__manage_tags` | Add/remove/list tags |
| `mcp__obsidian__get_frontmatter` | Extract frontmatter only |

### Key Parameters for write_note
```
path: string (required) - relative to vault root
content: string (required) - markdown content
frontmatter: object (optional) - YAML metadata
mode: "overwrite" | "append" | "prepend" (default: overwrite)
```

### Veille Folder Discovery
1. Use `list_directory` to scan vault root for "veille" folder
2. If found, use that path for new notes
3. Naming convention: `{YYYY-MM-DD}-{slug}.md` for chronological ordering

---

## 3. Parallel Agent Analysis Implementation

### Decision
Use Claude Code Task tool with `run_in_background: true` for agent analysis.

### Pattern

**Phase 2 Workflow**:
```
1. Store URL in state
2. Launch agent analysis: Task(run_in_background=true, timeout=120000ms)
3. Prompt human for input (foreground, blocking)
4. Check agent status periodically via TaskOutput
5. Gate: Both complete → proceed to Phase 3
```

### Background Task Parameters
```
run_in_background: true
timeout: 120000 (2 minutes in ms)
```

### State Tracking
```json
{
  "phase": 2,
  "agent_analysis": {
    "status": "running|complete|timeout",
    "task_id": "...",
    "result": { ... }
  },
  "human_analysis": {
    "status": "pending|complete",
    "takeaways": [ ... ]
  }
}
```

### Timeout Handling
- On timeout: retrieve partial results from agent
- Mark `agent_analysis.status = "timeout"`
- Still allow progression to discussion (partial results are valuable)
- User can supplement missing insights during discussion

### Synchronization Gate
```bash
# gate.sh for Phase 2
agent_status=$(jq -r '.agent_analysis.status' "$STATE_FILE")
human_status=$(jq -r '.human_analysis.status' "$STATE_FILE")

if [[ "$agent_status" != "pending" && "$agent_status" != "running" ]] && \
   [[ "$human_status" == "complete" ]]; then
  exit 0  # Gate passes
else
  echo "Waiting for: agent=$agent_status, human=$human_status"
  exit 1  # Gate fails
fi
```

---

## Alternatives Considered

### Helix Integration
- **Alternative**: Direct database access
- **Rejected because**: MCP provides clean abstraction, auto-generates embeddings, handles graph operations

### Obsidian Integration
- **Alternative**: Hardcoded veille folder path
- **Rejected because**: Dynamic discovery via MCP is more flexible and respects user vault organization

### Parallel Analysis
- **Alternative**: Sequential processing (agent first, then human)
- **Rejected because**: Spec requires parallel execution for efficiency and unbiased independent analysis

---

## Implementation Notes

1. **Error handling**: All MCP calls should handle connection failures gracefully
2. **State persistence**: JSON state files stored in `.curation/` directory per-branch
3. **Timeout**: 2 minutes for agent analysis aligns with spec clarification
4. **Duplicate handling**: Auto-update mode merges new insights into existing nodes
