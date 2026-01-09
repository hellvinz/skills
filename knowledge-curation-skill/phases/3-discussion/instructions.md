# Phase 3: Collaborative Discussion

> **STOP - READ THIS FIRST**
>
> All tools below are CLAUDE TOOLS. Call them directly like `Read` or `Bash`.
>
> **NEVER** create Python scripts, bash wrappers, or any code to call MCP tools.
> **NEVER** use `uv run`, `python -c`, or import statements.

## Purpose

Compare agent and human analyses side-by-side, facilitate discussion to resolve differences, and produce a consolidated summary approved by the user.

## Inputs

Use the data from **CONTEXT FROM PREVIOUS PHASES** above:
- `url`, `resource_metadata.title`, `resource_metadata.kagi_takeaways`
- `agent_analysis`, `human_analysis`

## Actions

### 1. Present Side-by-Side Comparison

Display both analyses for comparison:

```markdown
## Analysis Comparison

### Kagi Summary (Objective)
{resource_metadata.kagi_takeaways as bullet list}

### Agent Analysis (Contextual)
**Connection to your interests:**
{agent_analysis.contextual_relevance}

**Key points identified:**
{agent_analysis.key_points as bullet list}

**Suggested tags:** {agent_analysis.suggested_tags}

---

### Your Analysis
**Key takeaways:**
{human_analysis.key_points as bullet list}

**Notes:** {human_analysis.notes}
```

### 2. Identify Agreements and Differences

Categorize the points:

```markdown
## Synthesis

### Agreements (both identified)
- Point that appears in both analyses
- Another shared insight

### Unique from Agent
- Point only the agent identified
- Another agent-only insight

### Unique from You
- Point only you identified
- Your unique perspective
```

### 3. Facilitate Consolidation

For each unique point, ask the user:

```markdown
The agent identified: "{agent point}"

Do you want to include this in the final summary?
```

Use `AskUserQuestion` with options:
- **Include** - Add to consolidated summary
- **Skip** - Don't include
- **Modify** - Include with changes

### 4. Build Consolidated Summary

Assemble the final summary:

```json
{
  "consolidated_summary": {
    "title": "<agreed title>",
    "main_idea": "<merged main idea>",
    "key_takeaways": ["...", "..."],
    "content": "<full formatted content for storage>",
    "agreements": ["points both identified"],
    "human_additions": ["points human added"],
    "agent_additions": ["points from agent that were accepted"],
    "approved_at": null
  }
}
```

### 5. Request Final Approval

Present the consolidated summary:

```markdown
## Consolidated Summary

**Title:** {title}

**Main Idea:** {main_idea}

**Key Takeaways:**
1. {takeaway 1}
2. {takeaway 2}
...

---

Do you approve this summary for saving to your knowledge base?
```

Use `AskUserQuestion`:
- **Approve** - Set `approved_at` to current timestamp
- **Edit** - Make changes before approving
- **Cancel** - Abandon this curation

### 6. Save State

After approval, save via:

```bash
echo '{
  "consolidated_summary": {
    "title": "...",
    "main_idea": "...",
    "key_takeaways": [...],
    "content": "...",
    "approved_at": "<ISO timestamp>"
  }
}' | ./scripts/curation.sh save -u "$URL"
```

## Gate Criteria

Before advancing to Phase 4:
1. Consolidated summary exists with title and main_idea
2. Key takeaways array is not empty
3. `approved_at` timestamp is set

Run the gate check:

```bash
./scripts/curation.sh gate -u "$URL"
```

## Next Phase

Once the gate passes, advance to **Phase 4: Knowledge Persistence**.
