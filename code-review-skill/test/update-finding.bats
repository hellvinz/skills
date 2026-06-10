#!/usr/bin/env bats

# Test update-finding.sh

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    git init -q
    git checkout -q -b test-branch

    SCRIPT="$BATS_TEST_DIRNAME/../scripts/update-finding.sh"
    REVIEW="$BATS_TEST_DIRNAME/../scripts/review.sh"

    export _LOGIN_SHELL_SOURCED=1

    # Initialize review state
    "$REVIEW" next > /dev/null

    # Seed findings array with 3 items
    "$REVIEW" set findings '[
        {"id": 1, "file": "a.ts", "line": 10, "severity": "high", "status": "pending", "description": "First"},
        {"id": 2, "file": "b.ts", "line": 20, "severity": "medium", "status": "pending", "description": "Second"},
        {"id": 3, "file": "c.ts", "line": 30, "severity": "low", "status": "pending", "description": "Third"}
    ]'
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "update-finding: shows usage with no arguments" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "update-finding: --remove requires valid ID" {
    run "$SCRIPT" --remove
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "update-finding: --remove deletes finding and renumbers remaining" {
    run "$SCRIPT" --remove 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"Finding #2 removed"* ]]
    [[ "$output" == *"Remaining: 2"* ]]

    # Check renumbering
    findings=$("$REVIEW" get findings)
    count=$(echo "$findings" | jq 'length')
    [ "$count" -eq 2 ]

    id1=$(echo "$findings" | jq '.[0].id')
    id2=$(echo "$findings" | jq '.[1].id')
    desc1=$(echo "$findings" | jq -r '.[0].description')
    desc2=$(echo "$findings" | jq -r '.[1].description')

    [ "$id1" -eq 1 ]
    [ "$id2" -eq 2 ]
    [ "$desc1" = "First" ]
    [ "$desc2" = "Third" ]
}

@test "update-finding: --remove fails on non-existent ID" {
    run "$SCRIPT" --remove 99
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "update-finding: --set updates status field" {
    run "$SCRIPT" --set 1 status addressed
    [ "$status" -eq 0 ]
    [[ "$output" == *"Finding #1 status → addressed"* ]]

    val=$("$REVIEW" get findings | jq -r '.[0].status')
    [ "$val" = "addressed" ]
}

@test "update-finding: --set updates severity field" {
    run "$SCRIPT" --set 2 severity critical
    [ "$status" -eq 0 ]
    [[ "$output" == *"Finding #2 severity → critical"* ]]

    val=$("$REVIEW" get findings | jq -r '.[1].severity')
    [ "$val" = "critical" ]
}

@test "update-finding: --set rejects invalid status value" {
    run "$SCRIPT" --set 1 status invalid
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid status"* ]]
}

@test "update-finding: --set rejects invalid severity value" {
    run "$SCRIPT" --set 1 severity invalid
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid severity"* ]]
}

@test "update-finding: --set rejects unknown field" {
    run "$SCRIPT" --set 1 unknown value
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown field"* ]]
}

@test "update-finding: --set fails on non-existent ID" {
    run "$SCRIPT" --set 99 status addressed
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

# --- validate_id fix: works with non-sequential IDs ---

@test "update-finding: --set works with non-sequential IDs" {
    # Remove finding #2 to create gap: IDs become 1, 2 (renumbered from 1, 3)
    "$SCRIPT" --remove 2
    # Now set status on finding #2 (was originally #3)
    run "$SCRIPT" --set 2 status addressed
    [ "$status" -eq 0 ]
    [[ "$output" == *"Finding #2 status → addressed"* ]]
}

@test "update-finding: --remove works with non-sequential IDs" {
    # Manually set non-sequential IDs
    "$REVIEW" set findings '[
        {"id": 1, "file": "a.ts", "line": 10, "severity": "high", "status": "pending", "description": "First"},
        {"id": 3, "file": "c.ts", "line": 30, "severity": "low", "status": "pending", "description": "Third"}
    ]'
    run "$SCRIPT" --remove 3
    [ "$status" -eq 0 ]
    [[ "$output" == *"Finding #3 removed"* ]]
    [[ "$output" == *"Remaining: 1"* ]]
}

@test "update-finding: rejects ID not in findings even if within array bounds" {
    # Array has 3 items (indices 0-2), IDs are 1-3. ID 4 is within no bounds.
    # But let's test with a gap: set IDs to 1, 3, 5
    "$REVIEW" set findings '[
        {"id": 1, "file": "a.ts", "line": 10, "severity": "high", "status": "pending", "description": "First"},
        {"id": 3, "file": "c.ts", "line": 30, "severity": "low", "status": "pending", "description": "Third"},
        {"id": 5, "file": "e.ts", "line": 50, "severity": "medium", "status": "pending", "description": "Fifth"}
    ]'
    # ID 2 doesn't exist even though array has 3 elements
    run "$SCRIPT" --set 2 status addressed
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

# --- description field ---

@test "update-finding: --set updates description" {
    run "$SCRIPT" --set 1 description "Updated description"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Finding #1 description"* ]]

    val=$("$REVIEW" get findings | jq -r '.[0].description')
    [ "$val" = "Updated description" ]
}

@test "update-finding: --set rejects empty description" {
    run "$SCRIPT" --set 1 description ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"Description cannot be empty"* ]]
}

# --- merge command ---

@test "update-finding: --merge combines descriptions and takes higher severity" {
    # Finding 1: high, "First" / Finding 3: low, "Third"
    run "$SCRIPT" --merge 3 1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Merged finding #3 into #1"* ]]
    [[ "$output" == *"severity: high"* ]]

    findings=$("$REVIEW" get findings)
    desc=$(echo "$findings" | jq -r '.[0].description')
    [ "$desc" = "First | Third" ]
}

@test "update-finding: --merge renumbers remaining" {
    run "$SCRIPT" --merge 1 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"Remaining: 2"* ]]

    findings=$("$REVIEW" get findings)
    id1=$(echo "$findings" | jq '.[0].id')
    id2=$(echo "$findings" | jq '.[1].id')
    [ "$id1" -eq 1 ]
    [ "$id2" -eq 2 ]
}

@test "update-finding: --merge escalates severity from source" {
    # Source (finding 2) is medium, target (finding 3) is low → should become medium
    run "$SCRIPT" --merge 2 3
    [ "$status" -eq 0 ]
    [[ "$output" == *"severity: medium"* ]]

    findings=$("$REVIEW" get findings)
    sev=$(echo "$findings" | jq -r '.[1].severity')
    [ "$sev" = "medium" ]
}

@test "update-finding: --merge fails on same ID" {
    run "$SCRIPT" --merge 1 1
    [ "$status" -eq 1 ]
    [[ "$output" == *"Cannot merge a finding into itself"* ]]
}

@test "update-finding: --merge requires two arguments" {
    run "$SCRIPT" --merge 1
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "update-finding: --set line updates the line as a number" {
    run "$SCRIPT" --set 2 line 645
    [ "$status" -eq 0 ]
    [[ "$output" == *"Finding #2 line → 645"* ]]

    line=$("$REVIEW" get findings | jq '.[] | select(.id == 2) | .line')
    [ "$line" = "645" ]
    type=$("$REVIEW" get findings | jq -r '.[] | select(.id == 2) | .line | type')
    [ "$type" = "number" ]
}

@test "update-finding: --set line rejects non-integer values" {
    run "$SCRIPT" --set 2 line abc
    [ "$status" -eq 1 ]
    [[ "$output" == *"Line must be a positive integer"* ]]
}
