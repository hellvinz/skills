#!/usr/bin/env bats

# Test add-comment.sh in isolation

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Create a minimal git repo for branch detection
    git init -q
    git checkout -q -b test-branch

    # Copy the script
    SCRIPT="$BATS_TEST_DIRNAME/../scripts/add-comment.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "add-comment: shows usage with no arguments" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "add-comment: shows usage with only path argument" {
    run "$SCRIPT" "src/file.ts"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "add-comment: shows usage with only path and line" {
    run "$SCRIPT" "src/file.ts" "42"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "add-comment: rejects non-numeric line" {
    run "$SCRIPT" "src/file.ts" "abc" "comment body"
    [ "$status" -eq 1 ]
    [[ "$output" == *"must be a number"* ]]
}

@test "add-comment: creates .review directory if missing" {
    run "$SCRIPT" "src/file.ts" "42" "test comment"
    [ "$status" -eq 0 ]
    [ -d ".review" ]
}

@test "add-comment: creates comments file with branch name" {
    run "$SCRIPT" "src/file.ts" "42" "test comment"
    [ "$status" -eq 0 ]
    [ -f ".review/comments-test-branch.json" ]
}

@test "add-comment: adds comment with correct structure" {
    run "$SCRIPT" "src/file.ts" "42" "test comment"
    [ "$status" -eq 0 ]

    # Verify JSON structure
    path=$(jq -r '.comments[0].path' .review/comments-test-branch.json)
    line=$(jq -r '.comments[0].line' .review/comments-test-branch.json)
    body=$(jq -r '.comments[0].body' .review/comments-test-branch.json)

    [ "$path" = "src/file.ts" ]
    [ "$line" = "42" ]
    [ "$body" = "test comment" ]
}

@test "add-comment: appends multiple comments" {
    "$SCRIPT" "src/file1.ts" "10" "first comment"
    "$SCRIPT" "src/file2.ts" "20" "second comment"
    run "$SCRIPT" "src/file3.ts" "30" "third comment"

    [ "$status" -eq 0 ]
    count=$(jq '.comments | length' .review/comments-test-branch.json)
    [ "$count" -eq 3 ]
}

@test "add-comment --list: shows empty list initially" {
    run "$SCRIPT" --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"(0)"* ]]
}

@test "add-comment --list: shows added comments" {
    "$SCRIPT" "src/file.ts" "42" "test comment"
    run "$SCRIPT" --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"src/file.ts:42"* ]]
    [[ "$output" == *"test comment"* ]]
}

@test "add-comment --clear: removes all comments" {
    "$SCRIPT" "src/file.ts" "42" "test comment"
    run "$SCRIPT" --clear
    [ "$status" -eq 0 ]

    count=$(jq '.comments | length' .review/comments-test-branch.json)
    [ "$count" -eq 0 ]
}

@test "add-comment --remove: removes comment by index" {
    "$SCRIPT" "src/file1.ts" "10" "first"
    "$SCRIPT" "src/file2.ts" "20" "second"
    "$SCRIPT" "src/file3.ts" "30" "third"

    run "$SCRIPT" --remove 2
    [ "$status" -eq 0 ]

    count=$(jq '.comments | length' .review/comments-test-branch.json)
    [ "$count" -eq 2 ]

    # Verify second was removed (now third is at index 1)
    path=$(jq -r '.comments[1].path' .review/comments-test-branch.json)
    [ "$path" = "src/file3.ts" ]
}

@test "add-comment --remove: rejects invalid index" {
    "$SCRIPT" "src/file.ts" "42" "test"
    run "$SCRIPT" --remove 5
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid index"* ]]
}

@test "add-comment --remove: rejects zero index" {
    "$SCRIPT" "src/file.ts" "42" "test"
    run "$SCRIPT" --remove 0
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid index"* ]]
}

@test "add-comment: handles special characters in body" {
    run "$SCRIPT" "src/file.ts" "42" "Comment with \"quotes\" and 'apostrophes'"
    [ "$status" -eq 0 ]

    body=$(jq -r '.comments[0].body' .review/comments-test-branch.json)
    [[ "$body" == *"quotes"* ]]
    [[ "$body" == *"apostrophes"* ]]
}

@test "add-comment: handles multiline body" {
    run "$SCRIPT" "src/file.ts" "42" $'Line 1\nLine 2\nLine 3'
    [ "$status" -eq 0 ]

    body=$(jq -r '.comments[0].body' .review/comments-test-branch.json)
    [[ "$body" == *"Line 1"* ]]
    [[ "$body" == *"Line 2"* ]]
}

@test "add-comment: sanitizes branch name with slashes" {
    git checkout -q -b feature/ABC-123
    run "$SCRIPT" "src/file.ts" "42" "test"
    [ "$status" -eq 0 ]
    [ -f ".review/comments-feature-ABC-123.json" ]
}
