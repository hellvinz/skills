# Phase 2: OBSERVE & ANALYZE

Identify what changed and detect issues.

## Steps

### 2.1 List changes
Use `base` from context:
```bash
"$SKILL_DIR/scripts/list-changes.sh" --base <base_branch> --json --filter ts,tsx,js,jsx
```

### 2.2 Classify scope

| Lines | Classification | Action |
|-------|----------------|--------|
| < 200 | Quick review | Standard flow |
| 200-400 | Standard review | Full analysis |
| > 400 | Large PR | Suggest splitting |

If > 400 lines, ask user: "This PR is {X} lines. Continue anyway or split?"

### 2.3 Parallel detection

Run these in parallel:

**Automatic detection:**
```bash
"$SKILL_DIR/scripts/detect-slop.sh" --base <base_branch>
```

**Load principles:**
```bash
cat "$SKILL_DIR/principles/review-principles.md"
```

### 2.4 Manual analysis

Apply principles to each modified file.

For each issue found:
1. Note file and line
2. Identify violated principle (with ID)
3. Evaluate severity: critical | high | medium | low

### 2.5 Ticket correspondence

If Linear ticket available in context:
- Does code implement what's described?
- Any gaps between intent (specs) and implementation (code)?
- Missing elements from ticket?

## Save state

After listing files:
```bash
"$SKILL_DIR/scripts/review.sh" set files '["src/components/Button.tsx", "src/hooks/useVideo.ts"]'
```

After analysis, save preliminary findings:
```bash
"$SKILL_DIR/scripts/review.sh" set agent_findings '[
  {"id": 1, "file": "src/Button.tsx", "line": 42, "severity": "high", "principle": "SRP", "description": "Function does too much"},
  {"id": 2, "file": "src/hooks/useVideo.ts", "line": 15, "severity": "medium", "principle": "NC", "description": "Unclear variable name"}
]'
```

## Gate criteria

| Check | Action if failed |
|-------|------------------|
| Changes detected? | STOP: "No changes vs {base}" |
| TS/JS files present? | WARN: adapt analysis |
| Files list saved? | Required |
| Agent findings saved? | Required (can be empty array) |

## When ready
```bash
"$SKILL_DIR/scripts/review.sh" check-gate
```
Then ask user to confirm before calling `next`.
