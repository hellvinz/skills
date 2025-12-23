# Phase 3: COLLECT

Gather human reviewer observations before compiling the report.

## Purpose

Let the human reviewer do their own analysis. Don't bias them with agent findings - they may catch different things.

## Show hotspots only

Present the zones where most changes occurred:
```bash
"$SKILL_DIR/scripts/list-changes.sh" --base <base_branch> --hotspots
```

```markdown
## Review Hotspots

Files with most changes:
1. `src/components/VideoPlayer.tsx` (+142 / -38) - new playback logic
2. `src/hooks/useMediaSession.ts` (+89 / -12) - session handling
3. `src/api/streaming.ts` (+45 / -8) - API calls

---

Take your time to review. What concerns do you have?
(describe an issue, or "done" when finished)
```

## Interaction loop

**CRITICAL**: Loop until human says "done".

### For each human input

#### 1. Clarify to understand the real problem

Don't accept vague input. Ask questions:
- "Which file/function?"
- "What's the expected vs actual behavior?"
- "Is this blocking or a suggestion?"

Keep asking until you understand:
- Where (file, approximate location)
- What (the actual concern)
- Why it matters (severity)

#### 2. Record the observation

```bash
"$SKILL_DIR/scripts/add-finding.sh" '{
  "file": "src/api/streaming.ts",
  "description": "No retry logic for failed requests",
  "severity": "high"
}'
```

#### 3. Continue loop

```markdown
Noted. Anything else?
(describe an issue, or "done" when finished)
```

### Exit condition

When human indicates they're done:
```bash
"$SKILL_DIR/scripts/review.sh" set human_done true
"$SKILL_DIR/scripts/merge-findings.sh"
```

This combines `agent_findings` + `human_findings` into unified `findings` array.

## Gate criteria

| Check | Required |
|-------|----------|
| human_done == true | Yes |
| findings array exists | Yes |

## When ready
```bash
"$SKILL_DIR/scripts/review.sh" check-gate
```
Proceed directly to REPORT (human just confirmed they're done).
