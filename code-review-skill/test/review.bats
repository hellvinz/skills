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

# === Status tests ===

@test "status: shows no review when no state exists" {
    run "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"No review in progress"* ]] || [[ "$output" == *"No workflow in progress"* ]]
}

# === Next (auto-init) tests ===

@test "next: creates .review directory" {
    run "$SCRIPT" next
    [ "$status" -eq 0 ]
    [ -d ".review" ]
}

@test "next: creates state-{branch}.json" {
    run "$SCRIPT" next
    [ "$status" -eq 0 ]
    [ -f ".review/state-test-branch.json" ]
}

@test "next: sets initial phase to 1" {
    "$SCRIPT" next > /dev/null
    phase=$(jq -r '.phase' .review/state-test-branch.json)
    [ "$phase" -eq 1 ]
}

@test "next: sanitizes branch name with slashes" {
    git checkout -q -b feature/ABC-123
    run "$SCRIPT" next
    [ "$status" -eq 0 ]
    [ -f ".review/state-feature-ABC-123.json" ]
}

@test "next: shows phase 1 instructions on first run" {
    run "$SCRIPT" next
    [ "$status" -eq 0 ]
    [[ "$output" == *"PHASE 1"* ]]
}

# === Set/Get tests ===

@test "set: stores JSON value" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test", "ticket": "ABC-123"}'

    value=$(jq -r '.context.ticket' .review/state-test-branch.json)
    [ "$value" = "ABC-123" ]
}

@test "set: rejects invalid JSON" {
    "$SCRIPT" next > /dev/null
    run "$SCRIPT" set context 'not valid json'
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid JSON"* ]]
}

@test "get: retrieves stored value" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set mykey '{"foo": "bar"}'

    run "$SCRIPT" get mykey
    [ "$status" -eq 0 ]
    [[ "$output" == *"foo"* ]]
    [[ "$output" == *"bar"* ]]
}

@test "get: returns null for missing key" {
    "$SCRIPT" next > /dev/null
    run "$SCRIPT" get nonexistent
    [ "$status" -eq 0 ]
    [ "$output" = "null" ]
}

# === Gate tests ===

@test "gate: fails without state" {
    run "$SCRIPT" gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"No workflow in progress"* ]] || [[ "$output" == *"No review in progress"* ]]
}

@test "gate 1: fails without context" {
    "$SCRIPT" next > /dev/null
    run "$SCRIPT" gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Need:"* ]] || [[ "$output" == *"context"* ]]
}

@test "gate 1: passes with context" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'

    run "$SCRIPT" gate
    [ "$status" -eq 0 ]
}

# === Next with gate auto-advance tests ===

@test "next: stays on phase 1 if gate not passed" {
    "$SCRIPT" next > /dev/null
    # No context set, gate should fail

    run "$SCRIPT" next
    [ "$status" -eq 0 ]
    [[ "$output" == *"PHASE 1"* ]]

    phase=$(jq -r '.phase' .review/state-test-branch.json)
    [ "$phase" -eq 1 ]
}

@test "next: advances to phase 2 when gate 1 passes" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'

    run "$SCRIPT" next
    [ "$status" -eq 0 ]
    [[ "$output" == *"Gate 1 passed"* ]]
    [[ "$output" == *"PHASE 2"* ]]

    phase=$(jq -r '.phase' .review/state-test-branch.json)
    [ "$phase" -eq 2 ]
}

@test "next: records gate passed in state" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null

    passed=$(jq -r '.gates["1"].passed' .review/state-test-branch.json)
    [ "$passed" = "true" ]
}

@test "next: advances through multiple phases" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2

    # Phase 2 needs files + agent_findings
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3

    phase=$(jq -r '.phase' .review/state-test-branch.json)
    [ "$phase" -eq 3 ]
}

# === Gate 2 (files + agent_findings) tests ===

@test "gate 2: fails without files" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2

    run "$SCRIPT" gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Need:"* ]] || [[ "$output" == *"files"* ]]
}

@test "gate 2: fails without agent_findings" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2

    "$SCRIPT" set files '["src/test.ts"]'
    run "$SCRIPT" gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"agent_findings"* ]]
}

@test "gate 2: passes with files and agent_findings" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2

    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    run "$SCRIPT" gate
    [ "$status" -eq 0 ]
}

@test "gate 2: requires lib_check_done when source files present" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2

    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    run "$SCRIPT" gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"lib_check_done"* ]]
}

@test "gate 2: skips lib_check_done when only docs change" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2

    "$SCRIPT" set files '["README.md"]'
    "$SCRIPT" set agent_findings '[]'
    run "$SCRIPT" gate
    [ "$status" -eq 0 ]
}

# === Gate 3 (human_done + findings) ===

@test "gate 3: fails without human_done" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3

    run "$SCRIPT" gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Need:"* ]] || [[ "$output" == *"human_done"* ]]
}

@test "gate 3: fails without findings merged" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3

    "$SCRIPT" set human_done true
    run "$SCRIPT" gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"findings"* ]]
}

@test "gate 3: passes with human_done and findings" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3

    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[]'
    run "$SCRIPT" gate
    [ "$status" -eq 0 ]
}

# === Gate 4 (findings array - already set in phase 3) ===

@test "gate 4: passes with findings from phase 3" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[]'
    "$SCRIPT" next > /dev/null  # → phase 4

    # Phase 4 gate checks findings exist (already set)
    run "$SCRIPT" gate
    [ "$status" -eq 0 ]
}

# === Gate 5 (no pending findings) ===

@test "gate 5: fails with pending findings" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[{"id": 1, "file": "src/test.ts", "line": 10, "status": "pending"}]'
    "$SCRIPT" next > /dev/null  # → phase 4
    "$SCRIPT" next > /dev/null  # → phase 5

    run "$SCRIPT" gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"pending"* ]]
}

@test "gate 5: passes when all commented" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[{"id": 1, "file": "src/test.ts", "line": 10, "status": "commented"}]'
    "$SCRIPT" next > /dev/null  # → phase 4
    "$SCRIPT" next > /dev/null  # → phase 5

    run "$SCRIPT" gate
    [ "$status" -eq 0 ]
}

# === Gate 6 (comments for findings) ===

@test "gate 6: passes with no findings" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[]'
    "$SCRIPT" next > /dev/null  # → phase 4
    "$SCRIPT" next > /dev/null  # → phase 5
    "$SCRIPT" next > /dev/null  # → phase 6

    run "$SCRIPT" gate
    [ "$status" -eq 0 ]
}

@test "gate 6: fails when commented finding has no comment" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[{"id": 1, "file": "src/test.ts", "line": 10, "status": "commented"}]'
    "$SCRIPT" next > /dev/null  # → phase 4
    "$SCRIPT" next > /dev/null  # → phase 5
    "$SCRIPT" next > /dev/null  # → phase 6

    run "$SCRIPT" gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"comment"* ]]
}

@test "gate 6: passes when skipped finding has no comment" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[{"id": 1, "file": "src/test.ts", "line": 10, "status": "skipped"}]'
    "$SCRIPT" next > /dev/null  # → phase 4
    "$SCRIPT" next > /dev/null  # → phase 5
    "$SCRIPT" next > /dev/null  # → phase 6

    run "$SCRIPT" gate
    [ "$status" -eq 0 ]
}

@test "gate 6: passes when addressed finding has no comment" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[{"id": 1, "file": "src/test.ts", "line": 10, "status": "addressed"}]'
    "$SCRIPT" next > /dev/null  # → phase 4
    "$SCRIPT" next > /dev/null  # → phase 5
    "$SCRIPT" next > /dev/null  # → phase 6

    run "$SCRIPT" gate
    [ "$status" -eq 0 ]
}

@test "gate 6: passes when commented finding has comment" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[{"id": 1, "file": "src/test.ts", "line": 10, "status": "commented"}]'

    # Add comment at same location
    "$BATS_TEST_DIRNAME/../scripts/add-comment.sh" "src/test.ts" 10 "Please fix this"

    "$SCRIPT" next > /dev/null  # → phase 4
    "$SCRIPT" next > /dev/null  # → phase 5
    "$SCRIPT" next > /dev/null  # → phase 6

    run "$SCRIPT" gate
    [ "$status" -eq 0 ]
}

# === Context command ===

@test "context: shows formatted context" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test", "ticket": {"id": "ABC-123"}}'

    run "$SCRIPT" context
    [ "$status" -eq 0 ]
    [[ "$output" == *"Phase 1"* ]] || [[ "$output" == *"PHASE 1"* ]] || [[ "$output" == *"context"* ]]
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
    [[ "$output" == *"No review in progress"* ]] || [[ "$output" == *"No workflow in progress"* ]]
}

# === Clean tests ===

@test "clean: removes state and comments files" {
    "$SCRIPT" next > /dev/null
    [ -f ".review/state-test-branch.json" ]

    # Create a comments file
    echo '{"comments":[]}' > ".review/comments-test-branch.json"
    [ -f ".review/comments-test-branch.json" ]

    run "$SCRIPT" clean
    [ "$status" -eq 0 ]
    [ ! -f ".review/state-test-branch.json" ]
    [ ! -f ".review/comments-test-branch.json" ]
}

# === Restart tests ===

@test "restart: fails without state" {
    run "$SCRIPT" restart
    [ "$status" -eq 1 ]
    [[ "$output" == *"No review to restart"* ]]
}

@test "restart: fails if not at last phase" {
    "$SCRIPT" next > /dev/null
    run "$SCRIPT" restart
    [ "$status" -eq 1 ]
    [[ "$output" == *"only available at phase"* ]]
}

@test "restart: resets phase to 1 and bumps round" {
    # Advance to phase 6
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[{"id": 1, "file": "src/test.ts", "line": 10, "status": "commented"}]'
    "$SCRIPT" next > /dev/null  # → phase 4
    "$SCRIPT" next > /dev/null  # → phase 5
    "$SCRIPT" next > /dev/null  # → phase 6

    run "$SCRIPT" restart
    [ "$status" -eq 0 ]
    [[ "$output" == *"round 2"* ]]

    phase=$(jq -r '.phase' .review/state-test-branch.json)
    round=$(jq -r '.round' .review/state-test-branch.json)
    [ "$phase" -eq 1 ]
    [ "$round" -eq 2 ]
}

@test "restart: resets commented findings to pending" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[
        {"id": 1, "file": "a.ts", "line": 10, "status": "commented"},
        {"id": 2, "file": "b.ts", "line": 20, "status": "skipped"}
    ]'
    "$SCRIPT" next > /dev/null  # → phase 4
    "$SCRIPT" next > /dev/null  # → phase 5
    "$SCRIPT" next > /dev/null  # → phase 6

    "$SCRIPT" restart

    s1=$(jq -r '.findings[0].status' .review/state-test-branch.json)
    s2=$(jq -r '.findings[1].status' .review/state-test-branch.json)
    [ "$s1" = "pending" ]
    [ "$s2" = "skipped" ]
}

@test "restart: clears phase-specific fields" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[]'
    "$SCRIPT" next > /dev/null  # → phase 4
    "$SCRIPT" next > /dev/null  # → phase 5
    "$SCRIPT" next > /dev/null  # → phase 6

    "$SCRIPT" restart

    files=$(jq -r '.files // "null"' .review/state-test-branch.json)
    agent=$(jq -r '.agent_findings // "null"' .review/state-test-branch.json)
    human=$(jq -r '.human_findings // "null"' .review/state-test-branch.json)
    human_done=$(jq -r '.human_done // "null"' .review/state-test-branch.json)
    [ "$files" = "null" ]
    [ "$agent" = "null" ]
    [ "$human" = "null" ]
    [ "$human_done" = "null" ]
}

@test "restart: removes comments file" {
    "$SCRIPT" next > /dev/null
    "$SCRIPT" set context '{"branch": "test"}'
    "$SCRIPT" next > /dev/null  # → phase 2
    "$SCRIPT" set files '["src/test.ts"]'
    "$SCRIPT" set agent_findings '[]'
    "$SCRIPT" set lib_check_done true
    "$SCRIPT" next > /dev/null  # → phase 3
    "$SCRIPT" set human_done true
    "$SCRIPT" set findings '[]'
    "$SCRIPT" next > /dev/null  # → phase 4
    "$SCRIPT" next > /dev/null  # → phase 5
    "$SCRIPT" next > /dev/null  # → phase 6

    echo '{"comments":[]}' > ".review/comments-test-branch.json"
    "$SCRIPT" restart

    [ ! -f ".review/comments-test-branch.json" ]
}

# === Escape-safety and exit-status tests ===

@test "set: preserves backslash escapes in JSON strings when body runs under zsh" {
    command -v zsh > /dev/null || skip "zsh not available"
    "$SCRIPT" next > /dev/null

    run env _LOGIN_SHELL_SOURCED=1 zsh "$SCRIPT" set test_key '"line1\nline2 with spaces"'
    [ "$status" -eq 0 ]

    run env _LOGIN_SHELL_SOURCED=1 zsh "$SCRIPT" get test_key
    [[ "$output" == *"line2 with spaces"* ]]
}

@test "set: roundtrips JSON string with escapes under bash" {
    "$SCRIPT" next > /dev/null
    run "$SCRIPT" set test_key '"a\nb\tc"'
    [ "$status" -eq 0 ]
    raw=$(jq -c '.test_key' .review/state-test-branch.json)
    [ "$raw" = '"a\nb\tc"' ]
}

@test "login shell relaunch propagates the script exit status, not sed's" {
    # No state file: set must fail — before the PIPESTATUS fix this exited 0
    run env -u _LOGIN_SHELL_SOURCED SHELL=/bin/bash "$SCRIPT" set k '"v"'
    [ "$status" -ne 0 ]
}
