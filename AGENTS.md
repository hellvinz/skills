# Skills Repository

Claude Code skills - workflow definitions and automation scripts that extend Claude's capabilities.

## Using a Skill

Skills are triggered by keywords in conversation. For example, the code-review skill activates on:
- "review", "code review", "check my code", "PR review"

The skill's `SKILL.md` file is automatically loaded and guides the workflow.

## Available Skills

### code-review-skill

Collaborative code review for TypeScript/JavaScript projects.

```bash
# Run from target project directory with SKILL_DIR set
"$SKILL_DIR/scripts/gather-context.sh"    # Get branch/PR/ticket context
"$SKILL_DIR/scripts/detect-slop.sh"       # Find code quality issues
"$SKILL_DIR/scripts/add-comment.sh" <path> <line> <body>
"$SKILL_DIR/scripts/post-comments.sh"     # Post to GitHub PR
```

## Creating a New Skill

```bash
./scripts/new-skill.sh my-skill-name "Description of what the skill does"
```

See `template/SKILL.md` for the structure and [Anthropic Skills Spec](https://github.com/anthropics/skills/tree/main/spec) for the official specification.

## Scripts

Any script in `scripts/` must:
1. Pass `shellcheck`
2. Have tests in `test/*.bats`

Run `make check` before any commit.

## Design Principles

- **Collaborative**: Signal, explain, propose—developer decides
- **Gated**: Cannot skip validation steps
- **Iterative**: Address one issue at a time
- **Deterministic scripts**: Scripts gather data, agents make decisions
