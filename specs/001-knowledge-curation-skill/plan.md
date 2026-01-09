# Implementation Plan: Knowledge Curation Skill

**Branch**: `001-knowledge-curation-skill` | **Date**: 2026-01-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-knowledge-curation-skill/spec.md`

## Summary

A Claude Code skill that implements a 4-phase collaborative workflow for curating knowledge from web resources. The skill combines agent deep-thinking analysis with human insights through parallel processing, culminating in synchronized storage to both Helix (knowledge graph) and Obsidian (veille notes).

**Key Technical Approach**:
- Gated phase workflow with JSON state persistence (per-branch)
- Background agent task for parallel analysis with 2-minute timeout
- MCP integration for Helix and Obsidian write operations
- Progressive disclosure of phase-specific instructions

## Technical Context

**Language/Version**: Bash (scripts), Markdown (skill definition, templates)
**Primary Dependencies**: Claude Code skill framework, Helix MCP server, Obsidian MCP server
**Storage**: JSON state files (`.curation/state-{url-slug}.json`), MCP servers for final persistence
**Testing**: BATS for bash scripts, manual workflow testing
**Target Platform**: Claude Code CLI (macOS/Linux)
**Project Type**: Single project (skill directory structure)
**Performance Goals**: Complete workflow in <15 minutes, agent analysis <2 minutes
**Constraints**: Human input mandatory, 2-minute agent timeout, user confirmation before writes
**Scale/Scope**: Single-user knowledge curation sessions

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Status |
|-----------|-------------|--------|
| I. Collaborative Agency | User confirmation gates defined for key decisions | ✅ FR-019 requires confirmation before writes; discussion phase lets user accept/reject |
| II. Gated Workflows | Phase transitions have explicit validation criteria | ✅ FR-018 enforces gates; 4 phases with explicit entry/exit criteria |
| III. Deterministic Scripts | Data gathering separated from decision logic | ✅ Scripts fetch URL metadata, check duplicates; agent makes recommendations |
| IV. Progressive Disclosure | Context loaded just-in-time per phase | ✅ Each phase loads only its instructions; state carries minimal forward context |
| V. State Persistence | Workflow state persists across sessions | ✅ FR-017 requires state persistence; JSON format per-branch |

## Project Structure

### Documentation (this feature)

```text
specs/001-knowledge-curation-skill/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (MCP tool schemas)
└── checklists/          # Validation checklists
    └── requirements.md
```

### Source Code (repository root)

```text
knowledge-curation-skill/
├── SKILL.md                          # Skill definition (triggers, tools, workflow)
├── scripts/
│   ├── curation.sh                   # Main workflow state machine
│   ├── fetch-url.sh                  # URL validation and metadata extraction
│   ├── check-duplicate.sh            # Query Helix for existing URL
│   └── suggest-links.sh              # Find related nodes for linking
├── phases/
│   ├── 1-input/
│   │   ├── instructions.md           # Phase 1 guidance
│   │   └── gate.sh                   # URL validated, metadata confirmed
│   ├── 2-analysis/
│   │   ├── instructions.md           # Phase 2 guidance (parallel analysis)
│   │   └── gate.sh                   # Both agent and human analyses complete
│   ├── 3-discussion/
│   │   ├── instructions.md           # Phase 3 guidance (consolidation)
│   │   └── gate.sh                   # Summary approved by user
│   └── 4-persist/
│       ├── instructions.md           # Phase 4 guidance (write to systems)
│       └── gate.sh                   # Both Helix and Obsidian writes confirmed
├── templates/
│   ├── veille-note.md                # Obsidian note template
│   └── analysis-state.json           # State structure template
└── test/
    └── curation.bats                 # Script tests
```

**Structure Decision**: Single skill directory following existing `code-review-skill` patterns. Scripts handle deterministic operations (URL fetch, duplicate check), phases contain instructions and gates.

## Complexity Tracking

> No constitution violations. Design follows established patterns.

---

## Phase 0: Research

*See [research.md](./research.md) for full findings.*
