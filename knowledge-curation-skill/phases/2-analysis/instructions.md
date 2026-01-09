# Phase 2: Parallel Analysis

> **STOP - READ THIS FIRST**
>
> All tools below are CLAUDE TOOLS. Call them directly like `Read` or `Bash`.
>
> **NEVER** create Python scripts, bash wrappers, or any code to call MCP tools.
> **NEVER** use `uv run`, `python -c`, or import statements.

## Purpose

Analyze the resource from two perspectives simultaneously:
1. **Agent**: RAG-based contextual analysis connecting to user's existing knowledge
2. **Human**: User's direct insights from reading the resource

## Inputs

Use the data from **CONTEXT FROM PREVIOUS PHASES** above:
- `url`, `mode`, `resource_metadata` (title, description, author, kagi_takeaways)

## Actions

### 1. Launch Background RAG Analysis

Start a background task that analyzes the content in context of the user's interests:

```
Task(
  subagent_type: "general-purpose",
  run_in_background: true,
  timeout: 120000,
  prompt: """
  Analyze this resource in context of the user's knowledge base.

  Resource: {url}
  Title: {resource_metadata.title}
  Kagi Summary: {resource_metadata.kagi_takeaways}

  Steps:
  1. Query Helix for recent knowledge nodes (last 30 days)
  2. Query Helix for frequently used tags
  3. Find semantically similar existing nodes
  4. Analyze how this resource connects to existing knowledge

  Output JSON:
  {
    "contextual_relevance": "How this connects to user's interests",
    "key_points": ["Points relevant to user's context"],
    "connections": ["Existing nodes this relates to"],
    "suggested_tags": ["Tags based on existing tag patterns"]
  }
  """
)
```

Store the task_id in state:

```json
{
  "agent_analysis": {
    "status": "running",
    "task_id": "<task_id>",
    "started_at": "<ISO timestamp>"
  }
}
```

### 2. Prompt Human for Analysis

While agent runs in background, engage the user:

```markdown
## Your Turn to Analyze

The article is: **{resource_metadata.title}**
Source: {url}

Please read the article and share your key takeaways.

**Kagi's objective summary:**
{kagi_takeaways as bullet list}

---

What are **your** main insights? (3-5 points)
What stands out to you personally?
Any notes or context you want to add?
```

Use `AskUserQuestion` or direct conversation to collect:
- Key points (3-5 items)
- Personal notes/context

### 3. Collect Human Input

Store human analysis:

```json
{
  "human_analysis": {
    "status": "complete",
    "completed_at": "<ISO timestamp>",
    "key_points": ["user point 1", "user point 2", ...],
    "notes": "Additional context from user"
  }
}
```

### 4. Check Agent Task Status

Periodically check the background task:

```
TaskOutput(task_id=agent_analysis.task_id, block=false)
```

- If complete: Parse result, update `agent_analysis`
- If still running: Wait or continue with human input
- If timeout: Use partial results, mark as `timeout`

### 5. Handle Agent Results

On completion:

```json
{
  "agent_analysis": {
    "status": "complete",
    "task_id": "...",
    "started_at": "...",
    "completed_at": "<ISO timestamp>",
    "contextual_relevance": "...",
    "key_points": ["...", "..."],
    "connections": ["...", "..."],
    "suggested_tags": ["...", "..."]
  }
}
```

On timeout:

```json
{
  "agent_analysis": {
    "status": "timeout",
    "task_id": "...",
    "started_at": "...",
    "completed_at": "<ISO timestamp>",
    "key_points": [],
    "note": "Analysis timed out, using Kagi takeaways only"
  }
}
```

### 6. Save State

When both analyses are ready, save via:

```bash
echo '{
  "agent_analysis": { ... },
  "human_analysis": { ... }
}' | ./scripts/curation.sh save -u "$URL"
```

## Gate Criteria

Before advancing to Phase 3:
1. Agent analysis status is NOT `pending` or `running` (complete or timeout)
2. Human analysis status is `complete`

Run the gate check:

```bash
./scripts/curation.sh gate -u "$URL"
```

## Next Phase

Once the gate passes, advance to **Phase 3: Collaborative Discussion** where both analyses are compared and consolidated.
