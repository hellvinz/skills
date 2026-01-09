# Tasks: Knowledge Curation Skill

**Input**: Design documents from `/specs/001-knowledge-curation-skill/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/mcp-tools.md ✓

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Paths relative to `knowledge-curation-skill/`

---

## Phase 1: Setup (Skill Directory Structure)

**Purpose**: Complete the skill folder structure per plan.md

- [x] T001 [P] Create `phases/1-input/.gitkeep`, `phases/2-analysis/.gitkeep`, `phases/3-discussion/.gitkeep`, `phases/4-persist/.gitkeep`
- [x] T002 [P] Create `.curation/.gitkeep` for state directory
- [x] T003 Update `SKILL.md` with triggers: `/curate`, natural language patterns ("curate this", "add to knowledge base", "veille:")

---

## Phase 2: Foundational (State Machine & Shared Scripts)

**Purpose**: Core infrastructure that all workflow phases depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create `scripts/curation.sh` - main state machine that routes to current phase and checks gates
- [x] T005 [P] Create `templates/analysis-state.json` - initial state structure template per data-model.md
- [x] T006 [P] Implement URL slug generation function in `scripts/curation.sh` (domain + path → hyphenated slug)
- [x] T007 Implement state persistence functions: `save_state()`, `load_state()`, `get_state_file()` in `scripts/curation.sh`

**Checkpoint**: Foundation ready - phase implementations can now begin

---

## Phase 3: User Story 1 - Complete Knowledge Curation Flow (Priority: P1) 🎯 MVP

**Goal**: End-to-end workflow from URL input to Helix node + Obsidian note creation

**Independent Test**: Provide a URL, complete all phases, verify Helix node and Obsidian note exist

### Phase 1-Input Implementation

- [x] T008 [US1] Create `phases/1-input/instructions.md` - guidance for URL validation and metadata display
- [x] T009 [US1] Create `scripts/fetch-url.sh` - validate URL accessibility, extract title/description/author via WebFetch
- [x] T010 [US1] Create `scripts/check-duplicate.sh` - query Helix for existing Source with same URL (mcp__helix-memory__search_keyword)
- [x] T011 [US1] Create `phases/1-input/gate.sh` - verify: URL valid, metadata fetched, mode (create/update) determined

### Phase 3-Discussion Implementation

- [x] T012 [US1] Create `phases/3-discussion/instructions.md` - guidance for presenting both analyses, facilitating discussion
- [x] T013 [US1] Create `phases/3-discussion/gate.sh` - verify: consolidated_summary exists and approved_at is set

### Phase 4-Persist Implementation

- [x] T014 [US1] Create `phases/4-persist/instructions.md` - guidance for Helix/Obsidian writes with user confirmation
- [x] T015 [US1] Create `scripts/suggest-links.sh` - find related nodes via semantic search (mcp__helix-memory__search_vector)
- [x] T016 [US1] Create `templates/veille-note.md` - Obsidian note template with frontmatter (title, source, created, tags, helix_node_id)
- [x] T017 [US1] Create `phases/4-persist/gate.sh` - verify: Helix node created, Obsidian note created, both write confirmations received

**Checkpoint**: US1 complete - full workflow works end-to-end with manual analysis input

---

## Phase 4: User Story 2 - Parallel Analysis Phase (Priority: P2)

**Goal**: Agent analyzes in background while human reads simultaneously

**Independent Test**: Start analysis phase, verify agent task runs in background while human prompt is active

### Phase 2-Analysis Implementation

- [x] T018 [US2] Create `phases/2-analysis/instructions.md` - guidance for launching background task and prompting human
- [x] T019 [US2] Implement background agent task launch in workflow: Task(run_in_background=true, timeout=120000ms)
- [x] T020 [US2] Implement agent result collection: TaskOutput to retrieve analysis, handle timeout with partial results
- [x] T021 [US2] Create `phases/2-analysis/gate.sh` - verify: agent_analysis.status not in (pending, running) AND human_analysis.status == complete

**Checkpoint**: US2 complete - parallel analysis works, both perspectives captured independently

---

## Phase 5: User Story 3 - Collaborative Discussion (Priority: P2)

**Goal**: Side-by-side comparison of analyses with user-controlled consolidation

**Independent Test**: Provide differing agent/human analyses, verify differences highlighted and merge works

### Discussion Enhancement

- [x] T022 [US3] Enhance `phases/3-discussion/instructions.md` - add comparison logic to identify agreements vs differences
- [x] T023 [US3] Add interactive consolidation guidance: accept/reject/modify individual points
- [x] T024 [US3] Document ConsolidatedSummary structure usage: agreements[], human_additions[], agent_additions[]

**Checkpoint**: US3 complete - discussion phase produces high-quality merged summaries

---

## Phase 6: User Story 4 - Knowledge Graph Integration (Priority: P3)

**Goal**: Auto-suggest tags and relationships to existing nodes

**Independent Test**: Create node with existing related nodes, verify relationship suggestions appear

### Relationship & Tag Suggestions

- [x] T025 [US4] Enhance `scripts/suggest-links.sh` - use vector search on main_idea to find related nodes (k=5, min_score=0.7)
- [x] T026 [US4] Add relationship type suggestions: relates_to, builds_on, contradicts, supersedes with confidence scores
- [x] T027 [US4] Add tag suggestion logic: query existing tags (list_all_tags), match against content, suggest reuse before new
- [x] T028 [US4] Update `phases/4-persist/instructions.md` - display suggested relationships and tags for user confirmation

**Checkpoint**: US4 complete - knowledge graph grows with meaningful connections

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements affecting multiple user stories

- [x] T029 [P] Add status command to `scripts/curation.sh` - show in-progress curations
- [x] T030 [P] Add clean command to `scripts/curation.sh` - remove state for URL or all
- [x] T031 Run quickstart.md validation - complete full workflow per documented example
- [x] T032 Update SKILL.md with final tool requirements and workflow description

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational - MVP delivery
- **US2 (Phase 4)**: Depends on Foundational + US1 Phase 2 integration
- **US3 (Phase 5)**: Depends on US1 Phase 3 implementation
- **US4 (Phase 6)**: Depends on US1 Phase 4 implementation
- **Polish (Phase 7)**: Depends on all user stories

### Task Dependencies Within Phases

```
T001, T002 (parallel) → T003
           ↓
T004 → T005, T006 (parallel) → T007
           ↓
T008 → T009, T010 (parallel) → T011
           ↓
T012 → T013
           ↓
T014 → T015, T016 (parallel) → T017
           ↓
T018 → T019 → T020 → T021
           ↓
T022 → T023 → T024
           ↓
T025 → T026, T027 (parallel) → T028
           ↓
T029, T030 (parallel) → T031 → T032
```

### Parallel Opportunities

- T001 + T002 (different directories in setup)
- T005 + T006 (template + utility function)
- T009 + T010 (independent scripts)
- T015 + T016 (script + template)
- T026 + T027 (relationship types + tag logic)
- T029 + T030 (CLI commands)

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1 (workflow phases 1, 3, 4 - skip parallel analysis for MVP)
4. **STOP and VALIDATE**: Test full curation with manual analysis input
5. Deploy skill for early use

### Incremental Delivery

1. Setup + Foundational → Skill structure ready
2. Add US1 → Test full workflow → **MVP deployed**
3. Add US2 → Test parallel analysis → Enhanced efficiency
4. Add US3 → Test discussion quality → Better consolidation
5. Add US4 → Test graph integration → Connected knowledge

---

## Notes

- State files: `.curation/state-{url-slug}.json`
- MCP tools per phase documented in `contracts/mcp-tools.md`
- Agent timeout: 2 minutes (120000ms)
- Human input: mandatory (blocks workflow)
- Gate scripts exit 0 = pass, exit 1 = fail
