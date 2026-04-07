# Phase 2: OBSERVE & ANALYZE

Identify what changed and detect issues.

## Steps

### 2.0 User instructions

```bash
"$SKILL_DIR/scripts/review.sh" get user_instructions
```

If non-null, treat these as **priority directives** for the analysis:
- Adjust analysis scope/focus as instructed
- Use any referenced URLs or specs as additional context
- Flag in findings if an instruction couldn't be applied

### 2.1 List changes
Use `base` from context. Pass the bare branch name (e.g. `uat`, `master`), not the full ref — the script adds `origin/` automatically.
```bash
"$SKILL_DIR/scripts/list-changes.sh" --base <branch_name> --json --filter ts,tsx,js,jsx
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
"$SKILL_DIR/scripts/detect-slop.sh" --base <branch_name>
```

**Load principles:**
```bash
cat "$SKILL_DIR/principles/review-principles.md"
```

### 2.A Live verification (mandatory when dev_url is known)

Check `dev_url` from state:
```bash
"$SKILL_DIR/scripts/review.sh" get dev_url
```

**If `dev_url` is empty**, skip this step entirely — there is nothing to verify live without a URL. The phase 2 gate will not require `live_check_done` in this case.

**If `dev_url` is set**, this step is mandatory. Open the running app via the `chrome-devtools-mcp` MCP server on the page(s) impacted by the diff. Many issues are only visible at runtime.

**What to check live**:
- Navigate to the modified page(s) under `dev_url`
- `list_console_messages` for errors/warnings introduced by the change
- `list_network_requests` for failed requests
- Try the modified interaction (click, fill, navigate)
- `take_screenshot` of the modified zone for the report

**Mark the check done** before the phase 2 gate:
```bash
"$SKILL_DIR/scripts/review.sh" set live_check_done true
```

### 2.B Live a11y check (mandatory when UI files changed and dev_url known)

If the diff contains `.tsx`/`.jsx`/`.html`/`.vue`/`.svelte` files **and** `dev_url` is set, invoke the **`chrome-devtools-mcp:a11y-debugging`** skill on the modified pages. Static a11y checks miss almost everything that matters (focus order, contrast, label association, target size). The empirical audit via Chrome DevTools is the only reliable detector.

```
Use the chrome-devtools-mcp:a11y-debugging skill to audit
<dev_url>/<modified-page-path> for accessibility issues.
Focus on the elements changed by this diff:
<list of changed UI files>
```

Add any findings returned by the skill into `agent_findings`, then mark the check done:
```bash
"$SKILL_DIR/scripts/review.sh" set a11y_check_done true
```

If no UI files are changed, or `dev_url` is not set, skip this step — the gate stays silent.

### 2.4 React/Next.js analysis (if applicable)

If React files (.tsx/.jsx) are present in the changed files list:

1. Filter the changed files to get only React files
2. Invoke the `react-best-practices` skill with those specific files:

```
Review these files for React/Next.js performance issues using react-best-practices guidelines:
<list of .tsx/.jsx files from diff>
Focus only on the changes, not the entire codebase.
```

This applies Vercel's 57 performance rules (waterfalls, bundle size, server-side, re-renders) to the modified code only.

### 2.5 Manual analysis

Apply principles to each modified file.

For each issue found:
1. Identify the issue and the file
2. **Verify the exact line number** — use `grep -n` on the source file to confirm (do NOT guess from the diff)
3. Identify violated principle (with ID)
4. Evaluate severity: critical | high | medium | low

### 2.6 Ticket correspondence

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
| live_check_done set? | Required only if `dev_url` is known (otherwise the check is skipped) |
| a11y_check_done set? | Required only if UI files changed AND `dev_url` is known |

## When ready

Call `"$SKILL_DIR/scripts/review.sh" next` — it checks the gate and advances automatically.
