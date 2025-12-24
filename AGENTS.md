# Skills Repository

Claude Code skills - workflow definitions and automation scripts.

## Build & Test

```bash
make check   # lint + tests (required)
```

**Every code change must be linted and tested immediately**, not just before commit.

## Scripts

All scripts must:
1. Pass `shellcheck`
2. Have tests in `test/*.bats`

## Creating a New Skill

```bash
./scripts/new-skill.sh my-skill-name "Description"
```

See `template/SKILL.md` for structure, [Anthropic Skills Spec](https://github.com/anthropics/skills/tree/main/spec) for official spec.

## Design Principles

- **Collaborative** - Signal, explain, propose—developer decides
- **Gated** - Cannot skip validation steps
- **Iterative** - Address one issue at a time
- **Deterministic scripts** - Scripts gather data, agents make decisions

## Skill-Specific Instructions

Each skill may have its own `AGENTS.md` with specific guidelines.
