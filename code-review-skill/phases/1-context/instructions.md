# Phase 1: CONTEXT

Gather the "why" behind the changes.

## Steps

### 1.0 Re-review detection

Check the current round:
```bash
"$SKILL_DIR/scripts/review.sh" get round
```

If `round > 1`: this is a follow-up review. Previous findings with status `pending` are carried over from the last round — the developer should have addressed them. Focus this round on:
- Verifying pending findings were fixed
- Checking for new issues introduced by the fixes
- New changes beyond the fixes

Tell the user: "This is review round N. I'll focus on whether previous feedback was addressed."

### 1.1 Parallel: Collect context
Run these in parallel:

```bash
"$SKILL_DIR/scripts/gather-context.sh" --json
"$SKILL_DIR/scripts/read-docs.sh"
"$SKILL_DIR/scripts/load-project-config.sh"
```

If `load-project-config.sh` returns content, save it as **persistent project directives** — they apply to every review on this repo and shape which mandatory checks run in phase 2:

```bash
"$SKILL_DIR/scripts/review.sh" set project_config '"<raw markdown content>"'
```

If it returns nothing, the review continues normally. You may optionally suggest creating one with `review.sh init-config` if the user repeatedly provides the same context (dev URL, DS reference paths) at every review — but never block on it.

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
