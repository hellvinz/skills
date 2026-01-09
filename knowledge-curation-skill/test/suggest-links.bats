#!/usr/bin/env bats

# Test suggest-links.sh

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../scripts/suggest-links.sh"
}

# === Usage tests ===

@test "suggest-links: shows usage with --help" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "suggest-links: requires query argument" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Query text required"* ]]
}

# === Documentation output tests ===

@test "suggest-links: outputs MCP tool instructions" {
    run "$SCRIPT" "test query about AI agents"
    [ "$status" -eq 0 ]
    [[ "$output" == *"mcp__helix-memory__init"* ]]
    [[ "$output" == *"mcp__helix-memory__search_vector"* ]]
}

@test "suggest-links: includes query in instructions" {
    run "$SCRIPT" "context engineering patterns"
    [ "$status" -eq 0 ]
    [[ "$output" == *"context engineering patterns"* ]]
}

@test "suggest-links: documents relationship types in help" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"relates_to"* ]]
    [[ "$output" == *"builds_on"* ]]
    [[ "$output" == *"contradicts"* ]]
    [[ "$output" == *"supersedes"* ]]
}
