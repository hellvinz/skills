#!/usr/bin/env bats

# Test curation.sh state machine

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../scripts/curation.sh"
    SKILL_DIR="$BATS_TEST_DIRNAME/.."
    STATE_DIR="$SKILL_DIR/.curation"

    # Clean any existing state
    rm -f "$STATE_DIR"/state-*.json 2>/dev/null || true

    TEST_URL="https://example.com/test-article"
}

teardown() {
    # Clean up test state
    rm -f "$STATE_DIR"/state-*.json 2>/dev/null || true
}

# === Usage tests ===

@test "curation: shows usage with no arguments" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "curation: shows usage with --help" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "curation: rejects unknown command" {
    run "$SCRIPT" unknown
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown command"* ]]
}

# === Slug tests ===

@test "slug: generates slug from URL" {
    run "$SCRIPT" slug -u "https://example.com/my-article"
    [ "$status" -eq 0 ]
    [ "$output" = "example-com-my-article" ]
}

@test "slug: removes protocol" {
    run "$SCRIPT" slug -u "https://test.org/page"
    [ "$status" -eq 0 ]
    [[ "$output" != *"https"* ]]
}

@test "slug: collapses multiple hyphens" {
    run "$SCRIPT" slug -u "https://example.com/a--b///c"
    [ "$status" -eq 0 ]
    [[ "$output" != *"--"* ]]
}

@test "slug: truncates to 50 chars" {
    run "$SCRIPT" slug -u "https://example.com/very-long-article-title-that-exceeds-fifty-characters-limit"
    [ "$status" -eq 0 ]
    [ ${#output} -le 50 ]
}

@test "slug: requires URL" {
    run "$SCRIPT" slug
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires -u URL"* ]]
}

# === State file tests ===

@test "state: returns state file path" {
    run "$SCRIPT" state -u "$TEST_URL"
    [ "$status" -eq 0 ]
    [[ "$output" == *".curation/state-"* ]]
    [[ "$output" == *".json"* ]]
}

@test "state: requires URL" {
    run "$SCRIPT" state
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires -u URL"* ]]
}

# === Phase tests ===

@test "phase: returns 0 for new URL" {
    run "$SCRIPT" phase -u "$TEST_URL"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "phase: requires URL" {
    run "$SCRIPT" phase
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires -u URL"* ]]
}

# === Status tests ===

@test "status: shows no curations when empty" {
    run "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"No curations in progress"* ]]
}

@test "status: fails for non-existent URL" {
    run "$SCRIPT" status -u "$TEST_URL"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No curation in progress"* ]]
}

@test "status --json: returns empty array when no curations" {
    run "$SCRIPT" status --json
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}

# === Save tests ===

@test "save: requires URL" {
    run "$SCRIPT" save
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires -u URL"* ]]
}

@test "save: requires JSON on stdin" {
    run "$SCRIPT" save -u "$TEST_URL" <<< ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"No JSON data"* ]]
}

@test "save: rejects invalid JSON" {
    run "$SCRIPT" save -u "$TEST_URL" <<< "not valid json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid JSON"* ]]
}

@test "save: creates state file" {
    echo '{"test": "value"}' | "$SCRIPT" save -u "$TEST_URL"

    state_file=$("$SCRIPT" state -u "$TEST_URL")
    [ -f "$state_file" ]
}

@test "save: sets url and url_slug" {
    echo '{"mode": "create"}' | "$SCRIPT" save -u "$TEST_URL"

    state_file=$("$SCRIPT" state -u "$TEST_URL")
    url=$(jq -r '.url' "$state_file")
    slug=$(jq -r '.url_slug' "$state_file")

    [ "$url" = "$TEST_URL" ]
    [ -n "$slug" ]
}

@test "save: deep merges with existing state" {
    echo '{"field1": "value1"}' | "$SCRIPT" save -u "$TEST_URL"
    echo '{"field2": "value2"}' | "$SCRIPT" save -u "$TEST_URL"

    state_file=$("$SCRIPT" state -u "$TEST_URL")
    field1=$(jq -r '.field1' "$state_file")
    field2=$(jq -r '.field2' "$state_file")

    [ "$field1" = "value1" ]
    [ "$field2" = "value2" ]
}

@test "save: updates last_updated timestamp" {
    echo '{"test": "1"}' | "$SCRIPT" save -u "$TEST_URL"

    state_file=$("$SCRIPT" state -u "$TEST_URL")
    last_updated=$(jq -r '.last_updated' "$state_file")

    [ -n "$last_updated" ]
    [ "$last_updated" != "null" ]
}

# === Next tests ===

@test "next: requires URL" {
    run "$SCRIPT" next
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires -u URL"* ]]
}

@test "next: starts at phase 1 for new URL" {
    run "$SCRIPT" next -u "$TEST_URL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PHASE 1"* ]]
}

@test "next: shows URL in header" {
    run "$SCRIPT" next -u "$TEST_URL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$TEST_URL"* ]]
}

@test "next: shows instructions section" {
    run "$SCRIPT" next -u "$TEST_URL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"INSTRUCTIONS"* ]]
}

# === Gate tests ===

@test "gate: requires URL" {
    run "$SCRIPT" gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires -u URL"* ]]
}

@test "gate: fails without state" {
    run "$SCRIPT" gate -u "$TEST_URL"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No state found"* ]]
}

@test "gate 1: fails without required fields" {
    echo '{"phase": 1}' | "$SCRIPT" save -u "$TEST_URL"

    run "$SCRIPT" gate -u "$TEST_URL"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAILED"* ]]
}

@test "gate 1: passes with all required fields" {
    cat <<EOF | "$SCRIPT" save -u "$TEST_URL"
{
    "phase": 1,
    "mode": "create",
    "resource_metadata": {
        "title": "Test Article",
        "domain": "example.com",
        "kagi_takeaways": ["takeaway 1"]
    }
}
EOF

    run "$SCRIPT" gate -u "$TEST_URL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASSED"* ]]
}

# === Phase advancement tests ===

@test "next: auto-advances when gate passes" {
    # Set up state that passes gate 1
    cat <<EOF | "$SCRIPT" save -u "$TEST_URL"
{
    "phase": 1,
    "mode": "create",
    "resource_metadata": {
        "title": "Test Article",
        "domain": "example.com",
        "kagi_takeaways": ["takeaway 1"]
    }
}
EOF

    run "$SCRIPT" next -u "$TEST_URL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Gate 1 passed"* ]]
    [[ "$output" == *"PHASE 2"* ]]
}

@test "next: shows context from previous phases" {
    # Set up state at phase 2
    cat <<EOF | "$SCRIPT" save -u "$TEST_URL"
{
    "phase": 2,
    "mode": "create",
    "resource_metadata": {
        "title": "Test Article",
        "domain": "example.com",
        "kagi_takeaways": ["takeaway 1"]
    }
}
EOF

    run "$SCRIPT" next -u "$TEST_URL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CONTEXT FROM PREVIOUS PHASES"* ]]
}

# === Clean tests ===

@test "clean: requires URL or --all" {
    run "$SCRIPT" clean
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires -u URL or --all"* ]]
}

@test "clean: removes state for URL" {
    echo '{"test": "value"}' | "$SCRIPT" save -u "$TEST_URL"

    state_file=$("$SCRIPT" state -u "$TEST_URL")
    [ -f "$state_file" ]

    run "$SCRIPT" clean -u "$TEST_URL"
    [ "$status" -eq 0 ]
    [ ! -f "$state_file" ]
}

@test "clean: fails for non-existent URL" {
    run "$SCRIPT" clean -u "https://nonexistent.com/page"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No state found"* ]]
}

@test "clean --all: removes all state files" {
    echo '{"test": "1"}' | "$SCRIPT" save -u "https://example.com/page1"
    echo '{"test": "2"}' | "$SCRIPT" save -u "https://example.com/page2"

    run "$SCRIPT" clean --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed 2 state file"* ]]

    # Verify files removed
    count=$(ls "$STATE_DIR"/state-*.json 2>/dev/null | wc -l || echo 0)
    [ "$count" -eq 0 ]
}

# === Workflow complete test ===

@test "next: shows complete message at phase 5" {
    echo '{"phase": 5}' | "$SCRIPT" save -u "$TEST_URL"

    run "$SCRIPT" next -u "$TEST_URL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WORKFLOW COMPLETE"* ]]
}
