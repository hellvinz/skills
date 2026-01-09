# Data Model: Knowledge Curation Skill

**Date**: 2026-01-08
**Branch**: `001-knowledge-curation-skill`

## Entities

### 1. WorkflowState

Persisted in `.curation/state-{url-slug}.json` where `url-slug` is derived from the resource URL.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| url | string | Yes | Target resource URL (primary identifier) |
| url_slug | string | Yes | URL-derived slug for file naming |
| phase | number | Yes | Current phase (1-4) |
| started_at | ISO timestamp | Yes | Workflow start time |
| last_updated | ISO timestamp | Yes | Last state change |
| resource_metadata | ResourceMetadata | No | Extracted metadata (set in Phase 1) |
| existing_node_id | string | No | If duplicate URL, the existing Helix node ID |
| mode | "create" \| "update" | No | Whether creating new or updating existing |
| agent_analysis | AgentAnalysis | No | Agent's analysis state (Phase 2) |
| human_analysis | HumanAnalysis | No | Human's analysis state (Phase 2) |
| consolidated_summary | ConsolidatedSummary | No | Discussion output (Phase 3) |
| suggested_tags | string[] | No | Tag suggestions (Phase 4) |
| suggested_relationships | Relationship[] | No | Link suggestions (Phase 4) |
| gates | Record<string, GateResult> | No | Gate pass/fail history |

**URL Slug Generation**:
```
https://example.com/article/my-post → example-com-my-post
```
- Extract domain + path
- Replace non-alphanumeric with hyphens
- Truncate to reasonable length (50 chars)

### 2. ResourceMetadata

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| title | string | Yes | Page/article title |
| description | string | No | Meta description or excerpt |
| author | string | No | Author if available |
| published_date | string | No | Publication date if available |
| domain | string | Yes | Source domain |

### 3. AgentAnalysis

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| status | "pending" \| "running" \| "complete" \| "timeout" | Yes | Analysis state |
| task_id | string | No | Background task ID |
| started_at | ISO timestamp | No | When analysis started |
| completed_at | ISO timestamp | No | When analysis finished |
| main_idea | string | No | Agent's extracted main idea |
| key_points | string[] | No | Agent's key takeaways |
| suggested_tags | string[] | No | Agent's tag suggestions |

### 4. HumanAnalysis

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| status | "pending" \| "complete" | Yes | Input state |
| completed_at | ISO timestamp | No | When input was provided |
| key_points | string[] | No | Human's key takeaways |
| notes | string | No | Additional human notes |

### 5. ConsolidatedSummary

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| title | string | Yes | Agreed-upon title |
| main_idea | string | Yes | Merged main idea |
| key_takeaways | string[] | Yes | Consolidated list of insights |
| content | string | Yes | Full formatted content for storage |
| agreements | string[] | No | Points both agent and human agreed on |
| human_additions | string[] | No | Points human added that agent missed |
| agent_additions | string[] | No | Points agent added that human missed |
| approved_at | ISO timestamp | Yes | User approval timestamp |

### 6. Relationship (for suggestions)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| to_node_id | string | Yes | Target node ID |
| to_node_title | string | Yes | Target node title (for display) |
| type | "relates_to" \| "builds_on" \| "contradicts" \| "supersedes" | Yes | Relationship type |
| confidence | number | No | Suggestion confidence 0-1 |

### 7. GateResult

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| passed | boolean | Yes | Whether gate passed |
| at | ISO timestamp | Yes | When gate was checked |
| message | string | No | Failure reason if applicable |

---

## External Entities (Helix)

### KnowledgeNode

Managed by Helix MCP server.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | Yes | Helix node ID |
| title | string | Yes | Knowledge title |
| main_idea | string | Yes | Brief summary |
| content | string | Yes | Full content |
| status | "raw" \| "exploring" \| "actionable" \| "archived" | Yes | Lifecycle status |
| created_at | ISO timestamp | Yes | Creation time |
| updated_at | ISO timestamp | Yes | Last update time |

### Source

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | Yes | Source ID |
| url | string | Yes | Source URL |
| title | string | Yes | Source title |
| node_id | string | Yes | Linked knowledge node |

### Tag

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | Yes | Tag ID |
| value | string | Yes | Tag value/name |

### Relationship (Helix Edge)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| from_node_id | string | Yes | Source node |
| to_node_id | string | Yes | Target node |
| type | string | Yes | relates_to, builds_on, contradicts, supersedes |

---

## External Entities (Obsidian)

### VeilleNote

Markdown file in Obsidian vault.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| path | string | Yes | File path relative to vault |
| frontmatter.title | string | Yes | Note title |
| frontmatter.source | string | Yes | Original URL |
| frontmatter.created | ISO date | Yes | Creation date |
| frontmatter.tags | string[] | No | Obsidian tags |
| frontmatter.helix_node_id | string | Yes | Linked Helix node ID |
| content | markdown | Yes | Note body with takeaways |

---

## State Transitions

### Phase Flow

```
Phase 1 (Input) ──► Phase 2 (Analysis) ──► Phase 3 (Discussion) ──► Phase 4 (Persist)
     │                    │                       │                       │
     ▼                    ▼                       ▼                       ▼
  url validated      both analyses            summary approved       nodes created
  metadata fetched   complete                 by user                writes confirmed
  mode determined
```

### Analysis Status Transitions

```
AgentAnalysis.status:
  pending ──► running ──► complete
                   └──► timeout (uses partial results)

HumanAnalysis.status:
  pending ──► complete (no timeout, blocking required)
```

### Lifecycle Status (Helix)

New nodes are created with status `raw`. User can change status in future sessions:
```
raw ──► exploring ──► actionable ──► archived
```

---

## Validation Rules

1. **URL uniqueness**: Before Phase 1 completes, check if URL exists in Helix sources
2. **Human input required**: Phase 2 cannot advance until human_analysis.status = "complete"
3. **Summary approval**: Phase 3 cannot advance until consolidated_summary.approved_at is set
4. **Write confirmation**: Phase 4 requires explicit user confirmation before MCP writes
5. **Tag reuse**: Suggest existing tags before creating new ones
6. **Relationship types**: Only allow valid types (relates_to, builds_on, contradicts, supersedes)

---

## File Organization

```
.curation/
├── state-example-com-article-title.json      # Active curation for URL
├── state-another-site-post-name.json         # Another parallel curation
└── ...
```

Multiple curations can run in parallel since each URL has its own state file.
