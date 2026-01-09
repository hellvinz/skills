<!--
  SYNC IMPACT REPORT
  ==================
  Version change: 0.0.0 → 1.0.0 (Initial constitution)

  Modified principles: N/A (new constitution)

  Added sections:
  - 5 Core Principles (Agent Behavior focus)
  - Quality Gates section
  - Workflow Standards section
  - Governance section

  Removed sections: N/A

  Templates validated:
  - .specify/templates/plan-template.md ✅ Updated (Constitution Check table added)
  - .specify/templates/spec-template.md ✅ (Requirements structure aligned)
  - .specify/templates/tasks-template.md ✅ (Phase structure compatible)

  Follow-up TODOs: None
-->

# Skills Repository Constitution

## Core Principles

### I. Collaborative Agency

Agents MUST operate as collaborative partners, not autonomous actors.

- Signal intent before taking action
- Explain reasoning for recommendations
- Propose solutions; the developer decides
- Never skip user confirmation for destructive or irreversible operations
- Present options with trade-offs rather than making unilateral choices

**Rationale**: Human oversight ensures alignment with project goals and prevents
unintended consequences. Collaboration builds trust and enables learning.

### II. Gated Workflows

All multi-step workflows MUST enforce validation gates between phases.

- Each phase has explicit entry and exit criteria
- Gates block progression until requirements are met
- User confirmation required before advancing past gates
- No phase can be skipped, even when progress seems obvious
- Gate failures MUST be surfaced with actionable remediation steps

**Rationale**: Gates prevent cascading errors from early-phase mistakes.
Explicit checkpoints enable course correction and maintain quality standards.

### III. Deterministic Scripts

Scripts MUST be deterministic—they gather data or validate, never make subjective decisions.

- Scripts collect information and report facts
- Agents interpret facts and make recommendations
- Script output MUST be reproducible given the same inputs
- All validation logic resides in scripts, not in agent prompts
- Scripts MUST exit with clear success/failure codes

**Rationale**: Separating data gathering from decision-making ensures
auditability and allows human review of the reasoning process.

### IV. Progressive Disclosure

Context MUST be loaded just-in-time, not all at once.

- Load only the context needed for the current phase
- Reference documents are pulled when decisions require them
- Avoid front-loading large documents that may not be relevant
- Each phase explicitly declares its required context
- Agents MUST not assume context from previous sessions

**Rationale**: Focused context improves decision quality and reduces
cognitive load. Just-in-time loading keeps responses relevant.

### V. State Persistence

Workflow state MUST persist across session boundaries.

- State is stored per-branch to enable parallel work
- Checkpoints save progress at each phase completion
- Interruptions MUST be recoverable without data loss
- State format MUST be human-readable (JSON, Markdown)
- Agents MUST verify state consistency on session resume

**Rationale**: Development work is interrupted frequently. Persistent state
ensures continuity and prevents rework from session failures.

## Quality Gates

Standards that MUST be enforced at validation checkpoints:

- **Linting**: All code changes MUST pass configured linters before commit
- **Testing**: Tests MUST be executed; failures block progression
- **Documentation**: User-facing changes require documentation updates
- **Review**: Multi-file changes require explicit user review confirmation

## Workflow Standards

Requirements for skill and workflow definitions:

- **Phase Structure**: Every workflow defines discrete phases with clear objectives
- **Gate Definitions**: Each phase transition specifies required validations
- **Script Requirements**: All scripts pass `shellcheck` and have tests in `test/*.bats`
- **Template Usage**: Workflows use templates for consistent output formatting
- **Error Handling**: Failures produce actionable error messages with remediation guidance

## Governance

### Amendment Process

1. Propose change with rationale in writing
2. Document impact on existing workflows and templates
3. Update all affected artifacts before ratification
4. Version bump according to semantic versioning rules

### Versioning Policy

- **MAJOR**: Backward-incompatible principle changes or removals
- **MINOR**: New principles or materially expanded guidance
- **PATCH**: Clarifications, wording improvements, typo fixes

### Compliance

- All PRs MUST verify adherence to these principles
- Complexity beyond these standards MUST be justified in writing
- Periodic review ensures constitution remains aligned with project needs

**Version**: 1.0.0 | **Ratified**: 2025-12-23 | **Last Amended**: 2026-01-08
