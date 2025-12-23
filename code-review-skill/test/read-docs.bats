#!/usr/bin/env bats

# Test read-docs.sh

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    SCRIPT="$BATS_TEST_DIRNAME/../scripts/read-docs.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "read-docs: handles missing docs" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No project documentation found"* ]]
}

@test "read-docs: reads CLAUDE.md" {
    echo "# Claude Config" > CLAUDE.md

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLAUDE.md"* ]]
    [[ "$output" == *"Claude Config"* ]]
}

@test "read-docs: reads AGENTS.md" {
    echo "# Agent Instructions" > AGENTS.md

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"AGENTS.md"* ]]
    [[ "$output" == *"Agent Instructions"* ]]
}

@test "read-docs: reads ARCHITECTURE.md" {
    echo "# Architecture" > ARCHITECTURE.md

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ARCHITECTURE.md"* ]]
    [[ "$output" == *"Architecture"* ]]
}

@test "read-docs: reads ADRs" {
    mkdir -p docs/adr
    echo "# ADR 001" > docs/adr/001-decision.md

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ADR"* ]]
}

@test "read-docs --json: outputs valid JSON" {
    echo "# Test" > CLAUDE.md

    run "$SCRIPT" --json
    [ "$status" -eq 0 ]
    echo "$output" | jq . > /dev/null
}

@test "read-docs --json: includes all fields" {
    echo "# Claude" > CLAUDE.md
    echo "# Agents" > AGENTS.md

    run "$SCRIPT" --json
    [ "$status" -eq 0 ]

    echo "$output" | jq -e '.claude_md' > /dev/null
    echo "$output" | jq -e '.agents_md' > /dev/null
    echo "$output" | jq -e '.architecture_md' > /dev/null
    echo "$output" | jq -e '.adrs' > /dev/null
}
