# Architecture

## Project Structure

```
skills/
├── scripts/
│   └── new-skill.sh              # Bootstrap script for creating new skills
├── template/                     # Template for new skills
│   ├── SKILL.md                  # Minimal entry point
│   ├── scripts/
│   │   └── workflow.sh           # State machine script
│   ├── phases/
│   │   └── 1-example/            # Example phase structure
│   └── templates/
│       └── state.json            # State template
└── <skill-name>/                 # Each skill is a directory
    ├── SKILL.md                  # Entry point (minimal!)
    ├── scripts/                  # Automation scripts
    ├── phases/                   # Phase instructions + gates
    ├── templates/                # State and output templates
    └── .state/                   # Runtime state (gitignored)
```

---

## Multi-Phase Skill Patterns

> **These patterns are MANDATORY for skills with multiple phases.**

### Pattern 1: Progressive Disclosure

**Problem**: Loading all instructions upfront pollutes context and lets LLM anticipate/skip steps.

**Solution**: Store instructions per phase in `phases/N-name/instructions.md`. The `workflow.sh next` command reveals ONLY the current phase.

```
phases/
├── 1-input/
│   ├── instructions.md    # Loaded only when phase=1
│   └── gate.sh
├── 2-analysis/
│   ├── instructions.md    # Loaded only when phase=2
│   └── gate.sh
└── 3-output/
    ├── instructions.md    # Loaded only when phase=3
    └── gate.sh
```

**SKILL.md must NOT list phase details** - only how to start (`./scripts/workflow.sh next`).

---

### Pattern 2: State Machine Script

**Problem**: LLM wastes tokens on file operations, phase tracking, validation logic.

**Solution**: `scripts/workflow.sh` handles all deterministic operations:

| Command | Purpose |
|---------|---------|
| `next` | Get current phase instructions (auto-advances if gate passes) |
| `save` | Merge JSON from stdin into state |
| `gate` | Check if current phase requirements are met |
| `status` | Show current state |
| `clean` | Reset to start fresh |

**Key behaviors**:
- `next` checks gate first; if passed, advances phase before returning instructions
- `save` deep-merges input with existing state, never overwrites entirely
- Phase number is managed by script, never exposed to LLM

---

### Pattern 3: Hidden State

**Problem**: Raw state JSON is noisy and distracts from current task.

**Solution**: State lives in `.state/state.json` (gitignored). LLM never reads it directly.

The `next` command extracts and presents **only relevant context** for each phase:

```bash
# In workflow.sh cmd_next():
case "$phase" in
  2) jq '{url, metadata}' "$STATE_FILE" ;;           # Phase 2 needs input from phase 1
  3) jq '{url, analysis_summary}' "$STATE_FILE" ;;   # Phase 3 needs summary from phase 2
esac
```

**State structure** is defined in `templates/state.json` but hidden during execution.

---

### Pattern 4: Contextual Handoff

**Problem**: Each phase needs context from previous phases, but not ALL previous data.

**Solution**: The `next` command outputs a `--- CONTEXT FROM PREVIOUS PHASES ---` section with curated data.

**Rules**:
- Phase 1: No context (starting point)
- Phase N: Only fields needed for phase N's instructions

This ensures continuity without loading full conversation history.

---

### Pattern 5: Gate Validation

**Problem**: Advancing with incomplete data causes cascading errors.

**Solution**: Each phase has `phases/N-name/gate.sh` that validates requirements.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE=$(cat "$1")
ERRORS=()

# Check required fields
check() { [[ -n "$(echo "$STATE" | jq -r "$1 // empty")" ]]; }

check '.required_field' || ERRORS+=("Required field missing")
check '.another_field'  || ERRORS+=("Another field missing")

if [[ ${#ERRORS[@]} -eq 0 ]]; then
    echo "Gate N PASSED"
    exit 0
else
    echo "Gate N FAILED"
    printf '  - %s\n' "${ERRORS[@]}"
    exit 1
fi
```

**Gate is checked automatically** by `next` before advancing. Failed gate = stay on current phase.

---

## Creating a New Multi-Phase Skill

### Step 1: Define Phases

List your phases with clear boundaries:
- What triggers transition to next phase?
- What data must exist before advancing?

### Step 2: Create Directory Structure

```bash
mkdir -p my-skill/{scripts,phases,templates,.state}
touch my-skill/.state/.gitkeep
echo "*.json" > my-skill/.state/.gitignore
```

### Step 3: Copy workflow.sh

Copy from `template/scripts/workflow.sh` and customize:
- `PHASE_DIRS` array with your phase names
- Context extraction in `cmd_next()` case statement

### Step 4: Write Phase Instructions

For each phase, create `phases/N-name/instructions.md`:

```markdown
# Phase N: Name

## Purpose

One sentence: what this phase accomplishes.

## Actions

### 1. First Action

Specific instructions with tool names, parameters, expected outputs.

### 2. Second Action

...

### N. Save State

\`\`\`bash
echo '{"field": "value"}' | ./scripts/workflow.sh save
\`\`\`

## Gate Criteria

What must be true before advancing:
1. Requirement 1
2. Requirement 2
```

### Step 5: Write Gate Scripts

For each phase, create `phases/N-name/gate.sh` that validates the gate criteria.

### Step 6: Create State Template

Define initial state structure in `templates/state.json`:

```json
{
  "phase": 1,
  "started_at": "",
  "last_updated": "",
  "field_from_phase_1": null,
  "field_from_phase_2": null
}
```

### Step 7: Write Minimal SKILL.md

Copy from `template/SKILL.md`. Only customize:
- Frontmatter (name, description, triggers, tools)
- Title and role description
- Script name if different from `workflow.sh`

**Do NOT add phase details to SKILL.md.**

---

## Design Principles

- **Scripts are deterministic**: Gather data, validate, manage state - never make subjective decisions
- **Phases are explicit**: Each phase has clear gate before next
- **State is hidden**: User sees curated context, not raw JSON
- **Progressive disclosure**: Load instructions when needed, not upfront
- **LLM does reasoning**: Creative work, analysis, user interaction - not file operations
