# Phase 1: CONTEXT

Gather the "why" behind the changes.

## Steps

### 1.1 Parallel: Collect context
Run these in parallel:

```bash
"$SKILL_DIR/scripts/gather-context.sh" --json
"$SKILL_DIR/scripts/read-docs.sh"
```

Also fetch Linear ticket context if ticket ID detected in branch name (e.g., "PRA-990"):
```
mcp__linear__list_documents(issueId: "PRA-990")
mcp__linear__get_document(documentId: "...")
mcp__linear__list_comments(issueId: "PRA-990")
```

**If Linear MCP is unavailable**, note it and continue — but flag that ticket context is missing.

### 1.2 Sequential: Review history
Use `base_branch` from gather-context output:
```bash
"$SKILL_DIR/scripts/get-reviews.sh" --base <base_branch>
```

### 1.3 Additional instructions

Ask the user:
> "Do you have additional instructions for this review? (e.g., URL to test, alternative spec, specific focus areas)"

If the user provides instructions, save them:
```bash
"$SKILL_DIR/scripts/review.sh" set user_instructions '"Test against https://example.com/staging. Spec is in the Linear doc, not the ticket description."'
```

If none, skip — the field is optional.

## Save context

After gathering all information, save it:
```bash
"$SKILL_DIR/scripts/review.sh" set context '{
  "branch": "feature/xyz",
  "base": "main",
  "ticket": {"id": "PRA-990", "title": "...", "description": "..."},
  "pr": {"number": 481, "title": "..."},
  "docs": ["CLAUDE.md loaded", "..."]
}'
```

## Gate criteria

| Check | Action if failed |
|-------|------------------|
| On feature branch? | STOP: ask which branch to compare |
| Can identify base branch? | STOP: ask for reference |
| Project context loaded? | WARN: continue but flag it |

## When ready

Call `"$SKILL_DIR/scripts/review.sh" next` — it checks the gate and advances automatically.
