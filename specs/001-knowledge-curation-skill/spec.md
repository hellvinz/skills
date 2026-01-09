# Feature Specification: Knowledge Curation Skill

**Feature Branch**: `001-knowledge-curation-skill`
**Created**: 2026-01-08
**Status**: Draft
**Input**: User description: "creating a new skill to streamline an helix knowledge node and an obsidian veille item"

## Overview

A Claude Code skill that guides users through a structured, collaborative process for curating knowledge from web resources. The skill combines automated analysis with human insight to produce high-quality knowledge artifacts stored in both Helix (knowledge graph) and Obsidian (veille/watch notes).

## Clarifications

### Session 2026-01-08

- Q: Where should Obsidian veille notes be stored and how should they be named? → A: Query the Obsidian MCP server to discover the appropriate veille folder location dynamically.
- Q: How long should the agent analysis be allowed to run before timing out? → A: 2 minutes maximum.
- Q: How should the skill handle duplicate URLs (same resource already curated)? → A: Auto-update - merge new insights into the existing Helix node.
- Q: How should the skill handle when the human provides no input during analysis? → A: Block - require human input before proceeding to discussion phase.
- Q: What should happen if the agent analysis times out? → A: Use partial results - proceed with whatever the agent produced before timeout.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Complete Knowledge Curation Flow (Priority: P1)

As a knowledge worker, I want to capture insights from a web resource through a guided collaborative process so that I have well-structured, tagged knowledge stored in both my knowledge graph and note-taking system.

**Why this priority**: This is the core end-to-end flow that delivers the primary value of the skill. Without this, no knowledge curation happens.

**Independent Test**: Can be fully tested by providing a URL and completing all workflow phases, resulting in a populated Helix node and Obsidian note.

**Acceptance Scenarios**:

1. **Given** I invoke the skill with a URL, **When** the workflow completes all phases, **Then** a Helix knowledge node exists with title, main idea, content, tags, and source reference
2. **Given** I invoke the skill with a URL, **When** the workflow completes all phases, **Then** an Obsidian veille note exists with the consolidated takeaways and linked to related items
3. **Given** both agent and human have provided their analyses, **When** the discussion phase begins, **Then** I can see both perspectives side-by-side before consolidation

---

### User Story 2 - Parallel Analysis Phase (Priority: P2)

As a knowledge worker, I want the agent to analyze the resource while I read it simultaneously so that neither party waits for the other and we can compare independent perspectives.

**Why this priority**: Parallelism is key to efficiency and ensures unbiased independent analysis from both human and agent.

**Independent Test**: Can be tested by verifying the agent analysis runs in background while human input prompt is active, with both completing before discussion begins.

**Acceptance Scenarios**:

1. **Given** I have provided a URL, **When** the analysis phase starts, **Then** the agent begins deep analysis while simultaneously prompting me to read and provide my takeaways
2. **Given** the agent completes analysis before me, **When** I finish my input, **Then** I can immediately proceed to the discussion phase
3. **Given** I complete my input before the agent, **When** the agent finishes, **Then** I can immediately proceed to the discussion phase

---

### User Story 3 - Collaborative Discussion (Priority: P2)

As a knowledge worker, I want to discuss and refine the consolidated takeaways with the agent so that the final summary reflects both perspectives accurately.

**Why this priority**: The discussion phase is what differentiates this from simple extraction - it produces higher quality, validated insights.

**Independent Test**: Can be tested by providing differing agent and human analyses and verifying the discussion surfaces disagreements and produces a merged summary.

**Acceptance Scenarios**:

1. **Given** both analyses are complete, **When** the discussion phase begins, **Then** the agent presents both perspectives and highlights agreements and differences
2. **Given** the agent and I disagree on a key point, **When** we discuss it, **Then** I can either accept, reject, or modify the agent's interpretation
3. **Given** we have reached consensus, **When** I confirm the consolidated summary, **Then** the workflow proceeds to the writing phase

---

### User Story 4 - Knowledge Graph Integration (Priority: P3)

As a knowledge worker, I want the skill to automatically link new knowledge to related existing items so that my knowledge graph grows organically with meaningful connections.

**Why this priority**: Linking adds long-term value but is not essential for basic curation to work.

**Independent Test**: Can be tested by creating a node for a topic with existing related nodes and verifying relationship edges are created.

**Acceptance Scenarios**:

1. **Given** I am creating a knowledge node, **When** related nodes exist in Helix, **Then** the skill suggests relationships to link
2. **Given** suggested relationships are presented, **When** I confirm or modify them, **Then** the appropriate edges are created in the knowledge graph
3. **Given** relevant tags exist, **When** the node is created, **Then** existing tags are suggested before creating new ones

---

### Edge Cases

- What happens when the URL is inaccessible or returns an error?
- How does the system handle when the human provides no input? → Block: human input is required before proceeding to discussion phase.
- What happens if the agent analysis times out? → Use partial results: proceed with whatever analysis was produced before timeout.
- How does the system handle very long content that exceeds context limits?
- What happens when no related nodes exist for linking suggestions?
- How does the system handle duplicate URLs? → Auto-update: merge new insights into the existing Helix node and update the linked Obsidian note.

## Requirements *(mandatory)*

### Functional Requirements

**Phase 1: Reference Input**
- **FR-001**: Skill MUST accept a URL as the primary input to start the workflow
- **FR-002**: Skill MUST validate the URL is accessible before proceeding
- **FR-003**: Skill MUST extract and display the resource title and basic metadata for user confirmation
- **FR-003a**: Skill MUST check if URL already exists in Helix; if so, switch to update mode to merge new insights into the existing node

**Phase 2: Parallel Analysis**
- **FR-004**: Skill MUST trigger agent analysis using a deep-thinking approach that persists conclusions to workflow state, with a maximum timeout of 2 minutes; on timeout, use partial results
- **FR-005**: Skill MUST simultaneously prompt the user to read the resource and provide their key takeaways
- **FR-006**: Skill MUST track completion status of both agent and human analysis independently
- **FR-007**: Skill MUST only proceed to discussion phase when both analyses are complete; human input is mandatory and cannot be skipped

**Phase 3: Collaborative Discussion**
- **FR-008**: Skill MUST present both agent and human analyses side-by-side
- **FR-009**: Skill MUST highlight areas of agreement and disagreement between analyses
- **FR-010**: Skill MUST allow the user to accept, reject, or modify consolidated points
- **FR-011**: Skill MUST produce a final consolidated summary approved by the user

**Phase 4: Knowledge Persistence**
- **FR-012**: Skill MUST create a Helix knowledge node with: title, main idea, content, status, timestamps, and source reference
- **FR-013**: Skill MUST create an Obsidian veille note with the consolidated takeaways, querying the Obsidian MCP server to discover the appropriate folder location
- **FR-014**: Skill MUST suggest relevant tags based on content analysis
- **FR-015**: Skill MUST suggest relationships to existing knowledge nodes
- **FR-016**: Skill MUST allow user to confirm, modify, or reject suggested tags and relationships before persisting

**Workflow State & Gates**
- **FR-017**: Skill MUST persist workflow state between phases to support interruption recovery
- **FR-018**: Skill MUST enforce gates between phases (no skipping)
- **FR-019**: Skill MUST require explicit user confirmation before writing to external systems

### Key Entities

- **Knowledge Node**: The primary knowledge artifact containing title, main idea, full content, status (raw/exploring/actionable/archived), creation and update timestamps
- **Source Reference**: URL and title of the original resource, linked to the knowledge node
- **Veille Note**: The Obsidian markdown note capturing the consolidated insights
- **Tag**: Categorization labels that can be shared across multiple knowledge nodes
- **Relationship**: Typed edge connecting knowledge nodes (relates_to, builds_on, contradicts, supersedes)
- **Workflow State**: Persistent state tracking phase completion, agent analysis, human analysis, and discussion outcomes

### Assumptions

- The user has Helix memory MCP server configured and accessible
- The user has Obsidian MCP server configured with a veille folder
- Web resources are publicly accessible (no authentication required for initial scope)
- The deep-thinking agent is available as a subagent capability
- Content extraction from URLs is possible for standard web pages

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users complete the full curation workflow in under 15 minutes for a typical article
- **SC-002**: 90% of curated knowledge nodes have at least one relationship to existing nodes (after 10+ nodes exist)
- **SC-003**: Users accept the consolidated summary without major revisions in 80% of sessions
- **SC-004**: The parallel analysis phase reduces total workflow time by at least 30% compared to sequential processing
- **SC-005**: 100% of completed workflows result in both a Helix node and an Obsidian note being created
- **SC-006**: Users can successfully resume an interrupted workflow from the last completed phase
