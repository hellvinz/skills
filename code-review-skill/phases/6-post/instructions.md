# Phase 6: POST

Post comments to GitHub PR.

## Steps

### 6.1 Preview (optional)
```bash
"$SKILL_DIR/scripts/post-comments.sh" --dry-run
```

### 6.2 Post comments
```bash
"$SKILL_DIR/scripts/post-comments.sh"
```

## Gate criteria
Each finding with status `addressed` must have a corresponding comment at the same file:line. Findings with status `skipped` don't need comments.

## When ready

Call `"$SKILL_DIR/scripts/review.sh" next` — it checks the gate and advances automatically.

## Cleanup
After gate passes:
```bash
"$SKILL_DIR/scripts/review.sh" clean
```

Review complete.
