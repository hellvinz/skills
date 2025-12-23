# Phase 5: ITERATE

Prepare PR comments collaboratively.

**IMPORTANT**: This phase prepares review comments. It does NOT modify code or propose implementations — developers are seniors.

## Get findings and choose order

```bash
"$SKILL_DIR/scripts/review.sh" context
```

Ask user how to proceed:

```markdown
How do you want to iterate?

1. Critical issues first
2. High priority first
3. Human observations first
4. All in order
```

## Good Comment Principles

A good code review comment:
- **Short and natural** — one or two sentences, conversational tone
- **Points to the problem**, not the solution — let dev decide "how"
- **Asks questions** when relevant — "What happens if...?"
- **No AI structure** — no emoji, no headers, no bullet points
- **Includes links** for architecture feedback — reference docs rather than pontificate

Examples:
- `This could cause a race condition if the callback fires before state is initialized.`
- `Missing null check — response.data might be undefined here.`
- `This type is getting complex, might be worth simplifying — see https://docs.xstate.js.org/...`

## Workflow

### 5.1 Review each finding

For each finding, discuss with reviewer:

```
[{N}/{Total}] {path}:{line}

Problem: {short factual description}

Draft: "{natural comment, 1-2 sentences, with doc link if relevant}"

→ ok / rephrase / skip ?
```

**When "ok"**: Persist comment immediately:
```bash
"$SKILL_DIR/scripts/add-comment.sh" "src/file.ts" 42 "This could cause a race condition..."
```

### 5.2 View accumulated comments
```bash
"$SKILL_DIR/scripts/add-comment.sh" --list
```

### Commands
- `skip` — skip current issue
- `rephrase` — rework the comment
- `--list` — show all comments
- `--remove N` — remove comment N
- `--clear` — remove all comments

## Update findings

After processing each finding, update the findings array with new statuses:
```bash
"$SKILL_DIR/scripts/review.sh" set findings '[
  {"id": 1, "file": "src/Button.tsx", "line": 42, "severity": "high", "status": "addressed"},
  {"id": 2, "file": "src/hooks/useVideo.ts", "line": 15, "severity": "medium", "status": "skipped"}
]'
```

## Gate criteria
No pending findings (all must be `addressed` or `skipped`).

## When ready
```bash
"$SKILL_DIR/scripts/review.sh" check-gate
```
Then ask user to confirm before calling `next`.
