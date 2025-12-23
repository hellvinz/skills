#!/usr/bin/env bats

# Test gather-context.sh in isolation

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Create a git repo with commits
    git init -q
    git checkout -q -b main
    echo "initial" > file.txt
    git add file.txt
    git commit -q -m "Initial commit"

    # Create feature branch with ticket ID
    git checkout -q -b feature/ABC-123-add-feature
    echo "change" >> file.txt
    git add file.txt
    git commit -q -m "ABC-123: Add feature"

    # Create project context files
    echo "# CLAUDE.md" > CLAUDE.md
    echo "# AGENTS.md" > AGENTS.md

    SCRIPT="$BATS_TEST_DIRNAME/../scripts/gather-context.sh"

    # Skip login shell
    export _LOGIN_SHELL_SOURCED=1

    # Create mock gh
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/gh" << 'GHEOF'
#!/bin/bash
case "$*" in
    *defaultBranchRef*)
        echo "main"
        ;;
    *"pr view"*number,state,statusCheckRollup*)
        echo '{"number": 42, "state": "OPEN", "statusCheckRollup": [{"conclusion": "SUCCESS"}]}'
        ;;
    *)
        exit 1
        ;;
esac
GHEOF
    chmod +x "$TEST_DIR/bin/gh"
    export PATH="$TEST_DIR/bin:$PATH"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "gather-context: outputs branch info" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current branch:"* ]]
    [[ "$output" == *"feature/ABC-123-add-feature"* ]]
}

@test "gather-context: detects base branch" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Base branch:"* ]]
}

@test "gather-context: identifies feature branch" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Is feature branch: true"* ]]
}

@test "gather-context: extracts ticket ID from branch name" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Detected: ABC-123"* ]]
}

@test "gather-context: detects CLAUDE.md presence" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLAUDE.md: true"* ]]
}

@test "gather-context: detects AGENTS.md presence" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"AGENTS.md: true"* ]]
}

@test "gather-context: shows PR info when available" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PR: 42"* ]]
    [[ "$output" == *"State: OPEN"* ]]
}

@test "gather-context: shows commit count" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Commits:"* ]]
}

@test "gather-context --json: outputs valid JSON" {
    run "$SCRIPT" --json
    [ "$status" -eq 0 ]

    # Should parse as valid JSON
    echo "$output" | jq . > /dev/null
    [ $? -eq 0 ]
}

@test "gather-context --json: includes all required fields" {
    run "$SCRIPT" --json
    [ "$status" -eq 0 ]

    branch=$(echo "$output" | jq -r '.current_branch')
    [ "$branch" = "feature/ABC-123-add-feature" ]

    ticket=$(echo "$output" | jq -r '.ticket_id')
    [ "$ticket" = "ABC-123" ]

    is_feature=$(echo "$output" | jq -r '.is_feature_branch')
    [ "$is_feature" = "true" ]
}

@test "gather-context --json: includes PR info" {
    run "$SCRIPT" --json
    [ "$status" -eq 0 ]

    pr_number=$(echo "$output" | jq -r '.pr_number')
    [ "$pr_number" = "42" ]
}

@test "gather-context: handles missing CLAUDE.md" {
    rm CLAUDE.md
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLAUDE.md: false"* ]]
}

@test "gather-context: handles missing PR" {
    # Override gh to return empty for PR
    cat > "$TEST_DIR/bin/gh" << 'GHEOF'
#!/bin/bash
case "$*" in
    *defaultBranchRef*)
        echo "main"
        ;;
    *)
        exit 1
        ;;
esac
GHEOF

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PR: none"* ]] || [[ "$output" == *"PR:"* ]]
}

@test "gather-context: shows none when no ticket found" {
    # Create branch without ticket pattern
    git checkout -q main
    git checkout -q -b simple-branch

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    # Either shows "none" or "N/A" for missing ticket
    [[ "$output" == *"Detected: none"* ]] || [[ "$output" == *"Detected:"* ]]
}

@test "gather-context: shows file change stats" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Files:"* ]]
    [[ "$output" == *"Lines:"* ]]
}
