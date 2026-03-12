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
Each finding with status `commented` must have a corresponding comment at the same file:line. Findings with status `skipped` or `addressed` don't need comments.

## When ready

Call `"$SKILL_DIR/scripts/review.sh" next` — it checks the gate and advances automatically.

## After posting

Ask the user:
> "Review posted. Will there be another review round after the developer addresses feedback?"

- **Yes** → run `"$SKILL_DIR/scripts/review.sh" restart` — keeps findings, resets for next round. Suggest naming the session with `/rename review-{branch}` for easy resumption.
- **No** → run `"$SKILL_DIR/scripts/review.sh" clean`
