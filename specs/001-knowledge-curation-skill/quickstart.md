# Quickstart: Knowledge Curation Skill

## Prerequisites

1. **Helix Memory MCP server** configured and running
2. **Obsidian MCP server** configured with vault access
3. A `veille/` folder in your Obsidian vault (or similar)

## Installation

Copy the `knowledge-curation-skill/` folder to your skills directory.

## Usage

### Start a New Curation

```
/curate https://example.com/interesting-article
```

Or trigger naturally:
- "I want to curate this article: https://..."
- "Add this to my knowledge base: https://..."
- "Veille: https://..."

### Workflow Phases

**Phase 1: Reference Input**
- Skill validates the URL
- Checks for existing curation (offers update mode if found)
- Shows title and metadata for confirmation

**Phase 2: Parallel Analysis**
- Agent starts deep analysis (2 min timeout)
- You read the article and provide your takeaways
- Both complete before proceeding

**Phase 3: Discussion**
- See both perspectives side-by-side
- Accept, reject, or modify points
- Approve the consolidated summary

**Phase 4: Persistence**
- Review suggested tags and relationships
- Confirm writes to Helix and Obsidian
- Done!

### Resume an Interrupted Session

```bash
"$SKILL_DIR/scripts/curation.sh" status
```

Shows any in-progress curations. Resume by providing the same URL.

### Commands

| Command | Description |
|---------|-------------|
| `status` | Show all in-progress curations |
| `status <url>` | Show state for specific URL |
| `clean <url>` | Remove state for URL |
| `clean --all` | Remove all curation state |

## Example Session

```
User: /curate https://anthropic.com/research/building-effective-agents

Agent: Fetching resource metadata...

📄 **Building Effective Agents**
Source: anthropic.com
Author: Anthropic Research

This URL is new. Starting fresh curation.

[Gate 1: ✅ URL validated, metadata confirmed]

Starting Phase 2: Analysis
- 🤖 Agent analysis running in background...
- 📖 Please read the article and share your key takeaways.

What are your main insights from this article? (3-5 points)

User: 1. Agents work best with simple, composable patterns
       2. Workflows should be deterministic where possible
       3. Human oversight is critical for trust

Agent: ✅ Both analyses complete!

## Comparison

| Your Insights | Agent Insights |
|---------------|----------------|
| ✓ Simple patterns | ✓ Composable architecture |
| ✓ Deterministic workflows | ✓ Predictable behavior |
| ✓ Human oversight | ✓ Trust through transparency |
| | + Tool use optimization |

Do you want to add the agent's point about tool use? [Y/n]

User: y

Agent: 📝 Consolidated Summary:

**Main Idea**: Effective AI agents combine simple patterns, deterministic
workflows, and human oversight to build trust.

**Key Takeaways**:
1. Simple, composable patterns outperform complex architectures
2. Deterministic workflows enable predictability
3. Human oversight is essential for trust
4. Tool use should be optimized for the task

Approve this summary? [Y/n]

User: y

[Gate 3: ✅ Summary approved]

## Suggested Tags
- [x] agents
- [x] architecture
- [ ] anthropic (new tag)

## Suggested Links
- [x] relates_to: "Context Engineering Patterns"
- [ ] builds_on: "LLM Best Practices"

Confirm writes to Helix and Obsidian? [Y/n]

User: y

✅ Created Helix node: kn_abc123
✅ Created veille note: veille/2026-01-08-building-effective-agents.md

Curation complete!
```

## Troubleshooting

### "MCP server not available"
Ensure Helix and Obsidian MCP servers are running and configured in your Claude Code settings.

### "Agent analysis timed out"
The agent has 2 minutes. For very long articles, partial results will be used. Your insights can supplement any gaps.

### "Duplicate URL detected"
The skill found an existing node for this URL. Choose to update it with new insights or cancel.

## Configuration

The skill uses these defaults:
- Agent timeout: 2 minutes
- State directory: `.curation/`
- Veille folder: discovered via Obsidian MCP

No additional configuration required.
