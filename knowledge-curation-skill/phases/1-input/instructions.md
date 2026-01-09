# Phase 1: Reference Input

> **STOP - READ THIS FIRST**
>
> All tools below are CLAUDE TOOLS. Call them directly like `Read` or `Bash`.
>
> **NEVER** create Python scripts, bash wrappers, or any code to call MCP tools.
> **NEVER** use `uv run`, `python -c`, or import statements.
>
> WRONG: `uv run python -c "from mcp..."`
> CORRECT: Just invoke `mcp__helix-memory__init` as a tool call.

## Purpose

Validate the URL, extract metadata, get initial takeaways via Kagi, and determine whether this is a new curation or an update to an existing one.

## Actions

### 1. Validate URL and Extract Metadata

Invoke tool: **WebFetch**
- url: the target URL
- prompt: "Extract: title, description, author, published date, domain"

### 2. Get Initial Takeaways via Kagi

Invoke tool: **mcp__kagi__kagi_summarizer**
- url: the target URL
- summary_type: "takeaway"

### 3. Check for Duplicates in Helix

Invoke these tools in sequence:

1. **mcp__helix-memory__init** (no args) → returns connection_id
2. **mcp__helix-memory__search_keyword**
   - args.connection_id: from step 1
   - args.query: the URL
   - args.label: "Source"
   - args.limit: 1

If result is not empty: set `mode=update`, record `existing_node_id`
If result is empty: set `mode=create`

### 4. Display Metadata for Confirmation

Present the extracted information to the user:

```markdown
## Resource Preview

**Title**: {resource_metadata.title}
**Source**: {resource_metadata.domain}
**Author**: {resource_metadata.author} (if available)
**Published**: {resource_metadata.published_date} (if available)

**Description**: {resource_metadata.description}

---

### Initial Takeaways (via Kagi)

{kagi_takeaways as bullet list}
```

### 5. Handle Duplicate Detection

If a duplicate is found:

```markdown
## Existing Entry Found

This URL already exists in your knowledge base:
- **Node ID**: {existing_node_id}
- **Title**: {existing title from Helix}

Would you like to:
1. **Update** the existing entry with new insights
2. **Cancel** this curation
```

Use `AskUserQuestion` to get the user's choice.

### 6. Save State

Pipe the gathered data to the save command:

```bash
echo '{
  "mode": "create",
  "resource_metadata": {
    "title": "...",
    "description": "...",
    "author": "...",
    "published_date": "...",
    "domain": "...",
    "kagi_takeaways": ["...", "..."]
  }
}' | ./scripts/curation.sh save -u "$URL"
```

## Gate Criteria

Before advancing to Phase 2, verify:
1. URL is accessible and validated
2. Resource metadata has been extracted (at minimum: title, domain)
3. Kagi takeaways have been retrieved
4. Duplicate check has been performed
5. Mode (create/update) has been determined
6. User has confirmed they want to proceed

Run the gate check:

```bash
./scripts/curation.sh gate -u "$URL"
```

## Next Phase

Once the gate passes, advance to **Phase 2: Parallel Analysis** where:
- Agent performs RAG-based contextual analysis (connecting to your interests)
- Human reads and provides their own insights
