---
name: {{SKILL_NAME}}
description: |
  {{DESCRIPTION}}

  Triggered by: "{{TRIGGERS}}"
tools: Read, Grep, Glob, Bash, AskUserQuestion
---

# {{SKILL_TITLE}}

{{ROLE_DESCRIPTION}}

## Getting Started

When triggered, run:

```bash
./scripts/workflow.sh next
```

This returns the instructions for the current phase. Follow them exactly.

## Workflow Loop

1. Run `next` to get current phase instructions
2. Execute the instructions
3. Save data via `save` (pipe JSON to stdin)
4. Run `next` again to advance
5. Repeat until complete

## Commands

```bash
./scripts/workflow.sh next                           # Get current phase instructions
echo '{"key": "value"}' | ./scripts/workflow.sh save # Save state
./scripts/workflow.sh status                         # Check status
./scripts/workflow.sh clean                          # Reset
```
