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

@test "list-changes --hotspots: shows top files by volume" {
    run "$SCRIPT" --base main --hotspots
    [ "$status" -eq 0 ]
    [[ "$output" == *"HOTSPOTS"* ]]
    [[ "$output" == *"src/app.ts"* ]]
}

@test "list-changes --hotspots: sorts by total changes descending" {
    # Add more lines to app.ts so it clearly has more changes
    printf 'line1\nline2\nline3\nline4\nline5\n' >> src/app.ts
    git add . && git commit -q -m "More lines in app.ts"

    run "$SCRIPT" --base main --hotspots
    [ "$status" -eq 0 ]
    # app.ts should appear before test.tsx (more total changes)
    app_line=$(echo "$output" | grep -n "app.ts" | head -1 | cut -d: -f1)
    test_line=$(echo "$output" | grep -n "test.tsx" | head -1 | cut -d: -f1)
    [ "$app_line" -lt "$test_line" ]
}

@test "list-changes: strips origin/ prefix from --base" {
    run "$SCRIPT" --base origin/main
    [ "$status" -eq 0 ]
    [[ "$output" == *"origin/main"* ]]
    [[ "$output" != *"origin/origin/"* ]]
}
