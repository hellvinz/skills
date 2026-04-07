# Review Principles Reference

These principles are cited as references when reporting findings.

---

## Tool delegation

Several finding categories are **not covered by textual rules** but by specialised tools invoked as mandatory steps in phase 2. Do not duplicate these checks manually — use the tool.

| Category | Tool | When to invoke |
|----------|------|----------------|
| **A11y** (aria, labels, headings, contrast, focus, target size) | skill `chrome-devtools-mcp:a11y-debugging` | Diff touches JSX/HTML/template **and** `dev_url` is known |
| **React perf & hooks** (memo, useCallback, useSelector, useMemo, re-renders) | skill `react-best-practices` (Vercel) | Diff contains `.tsx`/`.jsx` |
| **Library API drift** (XState, React, Storybook, etc.) | MCP `context7` (resolve-library-id → query-docs) | Diff contains external library imports |
| **Live behaviour** (console errors, network, interactive states, responsive) | MCP `chrome-devtools-mcp` | `dev_url` is known |
| **Hardcoded styling → DS tokens** | `Grep` over `project_config.ds_reference_paths` | Diff contains style values **and** reference paths are configured |

The textual principles below cover what these tools do not.

---

## Architecture & Design

| ID | Principle | Key question |
|----|-----------|--------------|
| #7 | **Remember the Big Picture** | Does the change fit the overall architecture? |
| #14 | **Good Design Is Easier to Change** | Does the code stay easy to modify? |
| #17 | **Eliminate Effects Between Unrelated Things** | Any unintended side effects? |
| #44 | **Decoupled Code Is Easier to Change** | Is coupling kept to a minimum? |
| OCP | **Open/Closed Principle** | Does the code allow extension without modification? |

---

## Code Quality & Abstraction

| ID | Principle | Key question |
|----|-----------|--------------|
| #5 | **Don't Live with Broken Windows** | Slop, dead code, tolerated tech debt? |
| #15 | **DRY—Don't Repeat Yourself** | Any duplication? |
| #16 | **Make It Easy to Reuse** | Useful abstraction vs over-engineering? |
| SG | **Shameless Green** | A simple working solution beats premature abstraction |
| RPA | **Resist Premature Abstraction** | Does the abstraction emerge from the code or is it forced? |
| #62 | **Don't Program by Coincidence** | Does the code work by accident? |
| SM | **Sandi Metz Questions** | Hard to write? Hard to understand? Hard to change? |

---

## Naming & Readability

| ID | Principle | Key question |
|----|-----------|--------------|
| #74 | **Name Well; Rename When Needed** | Clear and consistent naming? |
| DOM | **Name by Concept, Not Implementation** | Do names reflect the business domain? |
| #45 | **Tell, Don't Ask** | Does the code ask for data to decide instead of delegating? |
| #46 | **Don't Chain Method Calls** | Excessive call chains (Law of Demeter)? |

---

## Complexity & Performance

| ID | Principle | Thresholds |
|----|-----------|------------|
| #63 | **Estimate Algorithm Order** | Is the algorithmic complexity acceptable? |
| ABC | **ABC Metric** | Assignments, Branches, Conditions balanced? |
| CC | **Cyclomatic Complexity** | ≤10 OK, 11-20 warn, >20 red |
| LOC | **Lines per Function** | ≤50 OK, 51-100 warn, >100 red |
| PARAMS | **Parameters per Function** | ≤4 OK, 5-6 warn, >6 red |
| NEST | **Nesting Depth** | ≤3 OK, 4 warn, >4 red |

---

## Testing

| ID | Principle | Key question |
|----|-----------|--------------|
| #67 | **A Test Is the First User** | Does the new code have tests? |
| #69 | **Design to Test** | Is the code testable? |
| #93 | **Test State Coverage** | Do tests cover states, not just lines? |
| #94 | **Find Bugs Once** | Does a fixed bug have a regression test? |
| TVN | **Test Value & Naming** | Does the test name describe the **expected user behaviour** (not "renders correctly", not "returns true if conditions met")? Does the test verify observable behaviour rather than asserting JSX structure, internal state, or each code branch in isolation? Does it match the style of neighbouring tests in the same file? **Especially relevant when tests are implemented with an agent**: agents tend to mirror the implementation (one test per branch, assertions on internals) and rarely describe what the user actually experiences. |

---

## Refactoring

| ID | Principle | Key question |
|----|-----------|--------------|
| #65 | **Refactor Early, Refactor Often** | Is it time to refactor? |
| FLOCK | **Flocking Rules** | (1) similar things, (2) smallest difference, (3) smallest change |
| SMELL | **Code Smells = Deferred Decisions** | A smell is not always something to fix immediately |
| EVOLVE | **Code Evolves (Fowler)** | Does this change make a past decision obsolete? |

---

## Documentation

| ID | Principle | Key question |
|----|-----------|--------------|
| #13 | **Build Documentation In** | Do comments capture the business "why"? |
| CLARITY | **Explicit Clarity (Cunningham/Fowler)** | Does the code make understanding explicit? |

---

## Robustness

| ID | Principle | Key question |
|----|-----------|--------------|
| #37 | **Design with Contracts** | Are inputs and outputs validated? |
| #38 | **Crash Early** | Are errors handled early and explicitly? |
| #42 | **Take Small Steps—Always** | Is the change too large in one go? |
| #47 | **Avoid Global Data** | Unjustified global state? |
| #57 | **Shared State Is Incorrect State** | Concurrency risks? |

---

## Internationalisation

| ID | Principle | Key question |
|----|-----------|--------------|
| I18N | **No Hardcoded UI Strings** | If the project has a translation function (`t()`, `i18n.t()`, `useTranslation`, etc.), every new user-visible string must go through it. New English literals introduced in JSX/templates are a finding. |

---

## Security

| ID | Principle | Key question |
|----|-----------|--------------|
| SEC | **Targeted Security (Fowler)** | Sensitive module touched (auth, payment, PII)? |

---

## Slop Patterns

### Useless comments (delete)

```
// Get the user          → SLOP
// Set the value         → SLOP
// Return the result     → SLOP
// This function does X  → SLOP
// Loop through items    → SLOP
```

### Acceptable comments (keep)

```
// GDPR: anonymise after 3 years of inactivity   → Business rule
// reduce() here for perf-critical 10k items     → Non-obvious choice
// See ticket ABC-123 for context                → External reference
// HACK: workaround for lib bug v2.3.1           → Known workaround
```

### Over-engineering (red flags)

- Helper/util used only once
- Interface with a single implementation and no justification
- Factory/Builder for simple objects
- "Just in case" abstraction

### Slop commit messages

❌ "Updated UserService to handle validation by changing the validateUser method to check email format"
✓ "Add email format validation to user registration"

❌ Commit message containing the diff
✓ Message describing the intent, not the implementation

---

## React/Next.js Performance

For React files (.tsx/.jsx) **modified in the diff**, apply the `react-best-practices` skill (57 Vercel rules).

---

## References

- [The Pragmatic Programmer Tips](https://pragprog.com/tips/)
- [99 Bottles of OOP - Sandi Metz](https://sandimetz.com/99bottles)
- [Pull Requests - Martin Fowler](https://martinfowler.com/bliki/PullRequest.html)
- [Refinement Code Review - Martin Fowler](https://martinfowler.com/bliki/RefinementCodeReview.html)
- [Vercel React Best Practices](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices)
