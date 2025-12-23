# Architecture

## Project Structure

```
skills/
├── scripts/
│   └── new-skill.sh              # Bootstrap script for creating new skills
├── template/
│   └── SKILL.md                  # Template for new skills
└── <skill-name>/                 # Each skill is a directory
    ├── SKILL.md                  # Main specification (triggers, phases, gates)
    ├── scripts/                  # Automation scripts
    ├── principles/               # Decision-making reference docs
    └── templates/                # Workflow tracking templates
```

## Skill Architecture

Skills follow a **gated phase workflow**:

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│ Phase 1 │───▶│ Phase 2 │───▶│ Phase 3 │───▶│ Phase N │
└─────────┘    └─────────┘    └─────────┘    └─────────┘
     │              │              │              │
     ▼              ▼              ▼              ▼
  GATE A         GATE B         GATE C         GATE N
```

1. **Phases** define discrete workflow steps with clear objectives
2. **Gates** enforce requirements before proceeding (validation, user confirmation)
3. **Scripts** automate deterministic operations (data gathering, validation)
4. **Principles** provide reference for subjective decisions
5. **Templates** track progress through the workflow

## SKILL.md Frontmatter

```yaml
---
name: skill-name
description: |
  What this skill does.
  Triggered by: "keyword1", "keyword2", ...
tools: Read, Grep, Glob, Bash, ...
---
```

## Design Decisions

- **Scripts are deterministic**: They gather data or validate, never make subjective decisions
- **Phases are explicit**: Each phase has a clear gate before the next
- **State is per-branch**: Allows parallel reviews on different branches
- **Comments persist to JSON**: Survives session interruptions
