#!/usr/bin/env bats

# Test check-duplicate.sh

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../scripts/check-duplicate.sh"
}

# === Usage tests ===

@test "check-duplicate: shows usage with --help" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "check-duplicate: requires URL argument" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"URL is required"* ]]
}

@test "check-duplicate: rejects unknown options" {
    run "$SCRIPT" --unknown
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

# === Documentation output tests ===

@test "check-duplicate: outputs MCP tool instructions" {
    run "$SCRIPT" "https://example.com/article"
    [ "$status" -eq 0 ]
    [[ "$output" == *"mcp__helix-memory__init"* ]]
    [[ "$output" == *"mcp__helix-memory__search_keyword"* ]]
}

@test "check-duplicate: includes URL in instructions" {
    run "$SCRIPT" "https://test.org/my-page"
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://test.org/my-page"* ]]
}

@test "check-duplicate: explains create vs update modes" {
    run "$SCRIPT" "https://example.com/article"
    [ "$status" -eq 0 ]
    [[ "$output" == *"mode=\"create\""* ]]
    [[ "$output" == *"mode=\"update\""* ]]
}
