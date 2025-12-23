# Review Checklist: {{BRANCH}}

**Generated**: {{DATE}}
**Ticket**: {{TICKET_ID}}
**Scope**: {{LINES}} lines across {{FILES}} files
**Reviewer**: Claude (AI) + {{DEVELOPER}}

---

## Gate Checks (must pass to proceed)

- [ ] On feature branch (not main/develop)
- [ ] Changes detected in diff
- [ ] Project context loaded (CLAUDE.md/ADRs)
- [ ] Ticket context available (if applicable)

---

## Architecture & Design

| Check | Status | Notes |
|-------|--------|-------|
| #7 Big Picture — Fits overall architecture | ⏳ | |
| #14 Easy to Change — Code remains modifiable | ⏳ | |
| #17 No Side Effects — No unintended coupling | ⏳ | |
| #44 Decoupled — Minimal module coupling | ⏳ | |
| Open/Closed — Extensible without modification | ⏳ | |

---

## Code Quality

| Check | Status | Notes |
|-------|--------|-------|
| #5 No Broken Windows — No slop/debt tolerated | ⏳ | |
| #15 DRY — No duplication | ⏳ | |
| #16 Easy to Reuse — Right abstraction level | ⏳ | |
| Shameless Green — Simple > premature abstraction | ⏳ | |
| #62 No Coincidence — Code works intentionally | ⏳ | |

---

## Naming & Readability

| Check | Status | Notes |
|-------|--------|-------|
| #74 Good Names — Clear, domain-aligned | ⏳ | |
| #45 Tell Don't Ask — Behavior over data queries | ⏳ | |
| #46 No Long Chains — Law of Demeter | ⏳ | |
| Domain Language — Business terms used | ⏳ | |

---

## Complexity Metrics

| Metric | Threshold | Actual | Status |
|--------|-----------|--------|--------|
| Cyclomatic Complexity | ≤10 | — | ⏳ |
| Lines per Function | ≤50 | — | ⏳ |
| Parameters per Function | ≤4 | — | ⏳ |
| Nesting Depth | ≤3 | — | ⏳ |

---

## Testing

| Check | Status | Notes |
|-------|--------|-------|
| #67 Tests Exist — New code tested | ⏳ | |
| #69 Testable Design — Easy to test | ⏳ | |
| #93 State Coverage — States tested, not lines | ⏳ | |
| #94 Bug = Test — Fixed bugs have tests | ⏳ | |

---

## Slop Detection

| Check | Count | Status |
|-------|-------|--------|
| Useless comments (Get/Set/This function...) | — | ⏳ |
| Over-engineering (single-use abstractions) | — | ⏳ |
| Commit message slop (impl details, code) | — | ⏳ |
| Direct fetch in UI components | — | ⏳ |
| Service imports in UI | — | ⏳ |

---

## Security (if applicable)

| Check | Status | Notes |
|-------|--------|-------|
| Auth modules reviewed | ⏳ | |
| Input validation | ⏳ | |
| No secrets in code | ⏳ | |
| PII handling correct | ⏳ | |

---

## Ticket Alignment

| Check | Status | Notes |
|-------|--------|-------|
| Implements requirements | ⏳ | |
| No missing pieces | ⏳ | |
| No scope creep | ⏳ | |
| Matches acceptance criteria | ⏳ | |

---

## Final Validation

| Check | Status | Required |
|-------|--------|----------|
| `yarn lint` | ⏳ | ✓ |
| `yarn typecheck` | ⏳ | ✓ |
| `yarn test` | ⏳ | ✓ |
| `yarn build` | ⏳ | ✓ |

---

## Issues Found

### 🔴 Critical (blocks merge)

_None yet_

### 🟠 High Priority

_None yet_

### 🟡 Medium Priority

_None yet_

### 💡 Suggestions

_None yet_

---

## Decision Log

| Issue | Decision | Rationale |
|-------|----------|-----------|
| | | |

---

## Summary

- **Issues Found**: —
- **Issues Fixed**: —
- **Issues Skipped**: —
- **Final Status**: ⏳ In Progress

---

**Status Legend**: ✓ Pass | ✗ Fail | ⏳ Pending | ⊘ Skipped | N/A Not Applicable
