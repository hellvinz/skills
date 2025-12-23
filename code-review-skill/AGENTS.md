# Code Review Skill

Collaborative code review workflow with gated phases and progressive disclosure.

## Build & Test

```bash
make check          # lint + tests (required before any commit)
shellcheck <file>   # lint single file
bats test/<file>    # run single test
```

## Development Principles

- **Lint and test every iteration** - Do not wait for commit time
- **Script repeated skill operations** - If the skill needs to do something multiple times, create a script
- **Scripts collect, agents decide** - Scripts are deterministic, decisions are not
- **Every phase needs a gate** - If a phase has no gate, merge it with another or refine it until you find one

## Development Rules

**Every script change requires:**
1. Pass `shellcheck`
2. Have corresponding tests in `test/*.bats`
3. Pass `make check`

## Workflow Commands

The skill uses `review.sh` as a state machine:

- `init` - Start review, outputs phase 1 instructions
- `check-gate` - Validate current phase requirements
- `next` - Advance to next phase (requires gate passed + user confirmation)
- `context` - Show current phase state

## Phase Structure

Each phase in `phases/N-name/` contains:
- `instructions.md` - Loaded when phase becomes active
- `gate.sh` - Blocks advancement until requirements met
- `format.sh` - Formats state for display
