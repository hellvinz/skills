#!/usr/bin/env bats

# Test add-finding.sh

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    git init -q
    git checkout -q -b test-branch

    SCRIPT="$BATS_TEST_DIRNAME/../scripts/add-finding.sh"
    REVIEW="$BATS_TEST_DIRNAME/../scripts/review.sh"

    export _LOGIN_SHELL_SOURCED=1

    # Initialize review state
    "$REVIEW" init > /dev/null
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "add-finding: shows usage with no arguments" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "add-finding: rejects invalid JSON" {
    run "$SCRIPT" "not valid json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid JSON"* ]]
}

@test "add-finding: adds finding with id and source" {
    run "$SCRIPT" '{"file": "src/test.ts", "description": "Test issue"}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Added human finding #1"* ]]

    findings=$("$REVIEW" get human_findings)
    id=$(echo "$findings" | jq -r '.[0].id')
    source=$(echo "$findings" | jq -r '.[0].source')

    [ "$id" = "1" ]
    [ "$source" = "human" ]
}

@test "add-finding: increments id for each finding" {
    "$SCRIPT" '{"file": "a.ts", "description": "First"}'
    "$SCRIPT" '{"file": "b.ts", "description": "Second"}'
    run "$SCRIPT" '{"file": "c.ts", "description": "Third"}'

    [ "$status" -eq 0 ]
    [[ "$output" == *"#3"* ]]

    count=$("$REVIEW" get human_findings | jq 'length')
    [ "$count" -eq 3 ]
}

@test "add-finding: preserves original fields" {
    run "$SCRIPT" '{"file": "src/test.ts", "description": "Issue", "severity": "high", "line": 42}'
    [ "$status" -eq 0 ]

    finding=$("$REVIEW" get human_findings | jq '.[0]')
    file=$(echo "$finding" | jq -r '.file')
    severity=$(echo "$finding" | jq -r '.severity')
    line=$(echo "$finding" | jq -r '.line')

    [ "$file" = "src/test.ts" ]
    [ "$severity" = "high" ]
    [ "$line" = "42" ]
}
