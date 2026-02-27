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

What would you like to do?

1. **Discuss** a specific finding (adjust severity, clarify, merge)
2. **Continue** to prepare inline comments
```

## Finding management commands

When the user asks to adjust findings during discussion:

```bash
# Merge overlapping findings (source is removed, target keeps combined info)
"$SKILL_DIR/scripts/update-finding.sh" --merge <source_id> <target_id>

# Update a finding's description
"$SKILL_DIR/scripts/update-finding.sh" --set <id> description "New description text"

# Update severity or status
"$SKILL_DIR/scripts/update-finding.sh" --set <id> severity <critical|high|medium|low>
"$SKILL_DIR/scripts/update-finding.sh" --set <id> status <pending|addressed|skipped>

# Remove a finding entirely
"$SKILL_DIR/scripts/update-finding.sh" --remove <id>
```

After any change, re-display the updated findings table.

## User actions at this phase

- **Discuss**: Let user explore/adjust findings before moving on
- **Continue**: Proceed to prepare inline comments for GitHub

**Do NOT offer**:
- "Generate PR comment" — not at this phase
- "Finish review" — not at this phase

## Gate criteria

`findings` must be saved as an array (can be empty).

## When ready

When user chooses to continue, call `"$SKILL_DIR/scripts/review.sh" next` — it checks the gate and advances automatically.
