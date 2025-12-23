#!/usr/bin/env bats

# Test get-reviews.sh

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Create repo with origin
    git init -q
    git checkout -q -b main
    echo "initial" > file.txt
    git add file.txt
    git commit -q -m "Initial commit"

    ORIGIN_DIR="$(mktemp -d)"
    git clone -q --bare . "$ORIGIN_DIR"
    git remote add origin "$ORIGIN_DIR"
    git push -q -u origin main

    git checkout -q -b feature/test
    echo "change" >> file.txt
    git add .
    git commit -q -m "Feature commit"

    SCRIPT="$BATS_TEST_DIRNAME/../scripts/get-reviews.sh"
    export _LOGIN_SHELL_SOURCED=1

    # Mock gh command
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/gh" << 'EOF'
#!/bin/bash
exit 1  # No PR by default
EOF
    chmod +x "$TEST_DIR/bin/gh"
    export PATH="$TEST_DIR/bin:$PATH"
}

teardown() {
    rm -rf "$TEST_DIR" "$ORIGIN_DIR"
}

@test "get-reviews: requires --base argument" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--base"* ]]
}

@test "get-reviews: shows commit messages" {
    run "$SCRIPT" --base main
    [ "$status" -eq 0 ]
    [[ "$output" == *"COMMIT MESSAGES"* ]]
    [[ "$output" == *"Feature commit"* ]]
}

@test "get-reviews: handles no PR" {
    run "$SCRIPT" --base main
    [ "$status" -eq 0 ]
    [[ "$output" == *"No PR found"* ]]
}

@test "get-reviews --json: outputs valid JSON" {
    run "$SCRIPT" --base main --json
    [ "$status" -eq 0 ]
    echo "$output" | jq . > /dev/null
}

@test "get-reviews --json: includes pr_exists field" {
    run "$SCRIPT" --base main --json
    [ "$status" -eq 0 ]

    pr_exists=$(echo "$output" | jq -r '.pr_exists')
    [ "$pr_exists" = "false" ]
}
