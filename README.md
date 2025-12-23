# Skills Repository

Collection of custom [Agent Skills](https://github.com/anthropics/skills) for Claude Code.

## What are Skills?

Skills are folders of instructions, scripts, and resources that Claude loads dynamically to perform better at specific tasks. Each skill contains a `SKILL.md` file that defines triggers, available tools, and workflow instructions.

See the official [Anthropic Skills Repository](https://github.com/anthropics/skills) for the specification and examples.

## Available Skills

| Skill | Description |
|-------|-------------|
| [code-review](./code-review-skill/) | Collaborative code review with validation gates and principle-based analysis |

## Creating a New Skill

Bootstrap a new skill with the included script:

```bash
./scripts/new-skill.sh my-skill-name "Description of what the skill does"
```

This creates the standard structure:

```
my-skill-name/
├── SKILL.md              # Skill definition (required)
├── scripts/              # Automation scripts
├── principles/           # Reference documents
└── templates/            # Workflow templates
```

## Skill Structure

### SKILL.md (Required)

The only required file. Contains YAML frontmatter and markdown instructions:

```markdown
---
name: skill-name
description: |
  Clear description of what this skill does.
  When Claude should use it and what triggers it.
tools: Read, Grep, Glob, Bash
---

# Skill Name

Instructions for Claude to follow...
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier in hyphen-case, matching folder name |
| `description` | Yes | What the skill does and when to use it |
| `tools` | No | Pre-approved tools list |
| `license` | No | License for the skill |
| `metadata` | No | Custom key-value pairs |

### Optional Directories

- **`scripts/`** - Bash scripts for automation (context gathering, validation, detection)
- **`principles/`** - Reference documents for decision-making
- **`templates/`** - Templates for tracking progress or generating output

## Installation

### Claude Code

```bash
# Add this repository as a skill source
# Skills are loaded automatically when triggers match
```

### Manual

Copy skill folders to your project or reference them in your Claude configuration.

## Design Patterns

See `veille/agent-effectiveness-patterns.md` in Obsidian for effectiveness patterns:
- Gates (blocking validation)
- Checklists (tracked validation)
- Progressive disclosure (just-in-time context)
- Scripts for deterministic work
- Phases with checkpoints

## Resources

- [What are skills?](https://support.anthropic.com/en/articles/12512176-what-are-skills)
- [Creating custom skills](https://support.anthropic.com/en/articles/12512198-creating-custom-skills)
- [Official Skills Repository](https://github.com/anthropics/skills)
- [Agent Skills Specification](https://github.com/anthropics/skills/tree/main/spec)
- [Effective Context Engineering (Anthropic)](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
