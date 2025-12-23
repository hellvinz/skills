# Phase 4: REPORT

Present the compiled findings from agent analysis and human observations.

## Get findings

```bash
"$SKILL_DIR/scripts/review.sh" context
```

This outputs all findings with their source (agent/human), severity, and details.

## Report Format

Use the context output to build this report:

```markdown
# Code Review: {branch}

## TL;DR
{2-3 sentences: overall state, ticket alignment, main concerns}

## Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Files modified | X | — |
| Lines | +X / -X | {OK/warning} |
| Agent findings | X | — |
| Human findings | X | — |
| Total issues | X | — |

## Issues by Priority

### Critical (blocks merge)
{list with source indicator: [A] for agent, [H] for human}

### High Priority
{list}

### Medium Priority
{list}

### Low / Suggestions
{list}

---

Ready to iterate on findings?
```

## Gate criteria

`findings` must be saved as an array (can be empty).

## When ready
```bash
"$SKILL_DIR/scripts/review.sh" check-gate
```
Then **wait for user choice** (1-5) before calling `next`.
