#!/usr/bin/env bats

# Test list-changes.sh

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Create repo with origin
    git init -q
    git checkout -q -b main
    echo "initial" > file.txt
    git add file.txt
    git commit -q -m "Initial"

    # Create a bare "origin" and push
    ORIGIN_DIR="$(mktemp -d)"
    git clone -q --bare . "$ORIGIN_DIR"
    git remote add origin "$ORIGIN_DIR"
    git push -q -u origin main

    # Create feature branch with changes
    git checkout -q -b feature/test
    mkdir -p src
    echo "export const x = 1" > src/app.ts
    echo "test" > src/test.tsx
    git add .
    git commit -q -m "Add files"

    SCRIPT="$BATS_TEST_DIRNAME/../scripts/list-changes.sh"
    export _LOGIN_SHELL_SOURCED=1
}

teardown() {
    rm -rf "$TEST_DIR" "$ORIGIN_DIR"
}

@test "list-changes: requires --base argument" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--base"* ]]
}

@test "list-changes: lists changed files" {
    run "$SCRIPT" --base main
    [ "$status" -eq 0 ]
    [[ "$output" == *"src/app.ts"* ]]
    [[ "$output" == *"src/test.tsx"* ]]
}

@test "list-changes: shows file status" {
    run "$SCRIPT" --base main
    [ "$status" -eq 0 ]
    [[ "$output" == *"[NEW]"* ]] || [[ "$output" == *"[MOD]"* ]]
}

@test "list-changes --json: outputs valid JSON" {
    run "$SCRIPT" --base main --json
    [ "$status" -eq 0 ]
    echo "$output" | jq . > /dev/null
}

@test "list-changes --json: includes base branch" {
    run "$SCRIPT" --base main --json
    [ "$status" -eq 0 ]
    base=$(echo "$output" | jq -r '.base_branch')
    [ "$base" = "main" ]
}

@test "list-changes --filter: filters by extension" {
    run "$SCRIPT" --base main --filter ts
    [ "$status" -eq 0 ]
    [[ "$output" == *"app.ts"* ]]
    [[ "$output" != *"test.tsx"* ]]
}

@test "list-changes --filter: supports multiple extensions" {
    run "$SCRIPT" --base main --filter ts,tsx
    [ "$status" -eq 0 ]
    [[ "$output" == *"app.ts"* ]]
    [[ "$output" == *"test.tsx"* ]]
}
