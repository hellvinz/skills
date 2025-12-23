#!/usr/bin/env bats

# Test review.sh state machine

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Create a minimal git repo
    git init -q
    git checkout -q -b test-branch

    SCRIPT="$BATS_TEST_DIRNAME/../scripts/review.sh"
    SKILL_DIR="$BATS_TEST_DIRNAME/.."

    # Skip login shell for tests
    export _LOGIN_SHELL_SOURCED=1
}

teardown() {
    rm -rf "$TEST_DIR"
}

# === Init tests ===

@test "status: shows no review when no state exists" {
    run "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"No review in progress"* ]]
}

@test "init: creates .review directory" {
    run "$SCRIPT" init
    [ "$status" -eq 0 ]
    [ -d ".review" ]
}

@test "init: creates state-{branch}.json" {
    run "$SCRIPT" init
    [ "$status" -eq 0 ]
    [ -f ".review/state-test-branch.json" ]
}

@test "init: sets initial phase to 1" {
    "$SCRIPT" init
    phase=$(jq -r '.phase' .review/state-test-branch.json)
    [ "$phase" -eq 1 ]
}

@test "init: sanitizes branch name with slashes" {
    git checkout -q -b feature/ABC-123
    run "$SCRIPT" init
    [ "$status" -eq 0 ]
    [ -f ".review/state-feature-ABC-123.json" ]
}

# === Set/Get tests ===

@test "set: stores JSON value" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test", "ticket": "ABC-123"}'

    value=$(jq -r '.context.ticket' .review/state-test-branch.json)
    [ "$value" = "ABC-123" ]
}

@test "set: rejects invalid JSON" {
    "$SCRIPT" init
    run "$SCRIPT" set context 'not valid json'
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid JSON"* ]]
}

@test "get: retrieves stored value" {
    "$SCRIPT" init
    "$SCRIPT" set mykey '{"foo": "bar"}'

    run "$SCRIPT" get mykey
    [ "$status" -eq 0 ]
    [[ "$output" == *"foo"* ]]
    [[ "$output" == *"bar"* ]]
}

@test "get: returns null for missing key" {
    "$SCRIPT" init
    run "$SCRIPT" get nonexistent
    [ "$status" -eq 0 ]
    [ "$output" = "null" ]
}

# === Check-gate tests ===

@test "check-gate: fails without init" {
    run "$SCRIPT" check-gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"No review in progress"* ]]
}

@test "check-gate 1: fails without context" {
    "$SCRIPT" init
    run "$SCRIPT" check-gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAILED"* ]]
}

@test "check-gate 1: passes with context" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'

    run "$SCRIPT" check-gate
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASSED"* ]]
}

@test "check-gate: records gate passed in state" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate

    passed=$(jq -r '.gates["1"].passed' .review/state-test-branch.json)
    [ "$passed" = "true" ]
}

# === Next tests ===

@test "next: fails if gate not passed" {
    "$SCRIPT" init
    run "$SCRIPT" next
    [ "$status" -eq 1 ]
    [[ "$output" == *"Gate not passed"* ]]
}

@test "next: advances phase after gate passed" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate

    run "$SCRIPT" next
    [ "$status" -eq 0 ]
    [[ "$output" == *"Phase 2"* ]]

    phase=$(jq -r '.phase' .review/state-test-branch.json)
    [ "$phase" -eq 2 ]
}

@test "next: advances through multiple phases" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next

    # Phase 2 needs files + agent_findings
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next

    phase=$(jq -r '.phase' .review/state-test-branch.json)
    [ "$phase" -eq 3 ]
}

# === Gate 2 (files + agent_findings) tests ===

@test "check-gate 2: fails without files" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next

    run "$SCRIPT" check-gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAILED"* ]]
}

@test "check-gate 2: fails without agent_findings" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next

    "$SCRIPT" set files '["src/test.ts"]'
    run "$SCRIPT" check-gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAILED"* ]]
    [[ "$output" == *"agent_findings"* ]]
}

@test "check-gate 2: passes with files and agent_findings" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next

    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    run "$SCRIPT" check-gate
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASSED"* ]]
}

# === Gate 3 (human_done + findings) ===

@test "check-gate 3: fails without human_done" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next

    run "$SCRIPT" check-gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAILED"* ]]
}

@test "check-gate 3: fails without findings merged" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next

    "$SCRIPT" set human_done true
    run "$SCRIPT" check-gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAILED"* ]]
    [[ "$output" == *"findings"* ]]
}

@test "check-gate 3: passes with human_done and findings" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next

    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[]'
    run "$SCRIPT" check-gate
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASSED"* ]]
}

# === Gate 4 (findings array - already set in phase 3) ===

@test "check-gate 4: passes with findings from phase 3" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next

    # Phase 4 gate checks findings exist (already set)
    run "$SCRIPT" check-gate
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASSED"* ]]
}

# === Gate 5 (no pending findings) ===

@test "check-gate 5: fails with pending findings" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[{"id": 1, "file": "src/test.ts", "line": 10, "status": "pending"}]'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" check-gate && "$SCRIPT" next

    run "$SCRIPT" check-gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAILED"* ]]
}

@test "check-gate 5: passes when all addressed" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[{"id": 1, "file": "src/test.ts", "line": 10, "status": "addressed"}]'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" check-gate && "$SCRIPT" next

    run "$SCRIPT" check-gate
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASSED"* ]]
}

# === Gate 6 (comments for findings) ===

@test "check-gate 6: passes with no findings" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" check-gate && "$SCRIPT" next

    run "$SCRIPT" check-gate
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASSED"* ]]
}

@test "check-gate 6: fails when addressed finding has no comment" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[{"id": 1, "file": "src/test.ts", "line": 10, "status": "addressed"}]'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" check-gate && "$SCRIPT" next

    run "$SCRIPT" check-gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAILED"* ]]
}

@test "check-gate 6: passes when skipped finding has no comment" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[{"id": 1, "file": "src/test.ts", "line": 10, "status": "skipped"}]'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" check-gate && "$SCRIPT" next

    run "$SCRIPT" check-gate
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASSED"* ]]
}

@test "check-gate 6: passes when addressed finding has comment" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[{"id": 1, "file": "src/test.ts", "line": 10, "status": "addressed"}]'

    # Add comment at same location
    "$BATS_TEST_DIRNAME/../scripts/add-comment.sh" "src/test.ts" 10 "Please fix this"

    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" check-gate && "$SCRIPT" next
    "$SCRIPT" check-gate && "$SCRIPT" next

    run "$SCRIPT" check-gate
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASSED"* ]]
}

# === Context command ===

@test "context: shows formatted context" {
    "$SCRIPT" init
    "$SCRIPT" set context '{"branch": "test", "ticket": {"id": "ABC-123"}}'

    run "$SCRIPT" context
    [ "$status" -eq 0 ]
    [[ "$output" == *"Phase 1"* ]]
}

# === Usage tests ===

@test "shows usage for unknown command" {
    run "$SCRIPT" unknown
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "default command is status" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No review in progress"* ]]
}

# === Clean tests ===

@test "clean: removes state and comments files" {
    "$SCRIPT" init
    [ -f ".review/state-test-branch.json" ]

    # Create a comments file
    echo '{"comments":[]}' > ".review/comments-test-branch.json"
    [ -f ".review/comments-test-branch.json" ]

    run "$SCRIPT" clean
    [ "$status" -eq 0 ]
    [ ! -f ".review/state-test-branch.json" ]
    [ ! -f ".review/comments-test-branch.json" ]
}
