#!/usr/bin/env bats

# Test detect-slop.sh

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    # Create repo with origin
    git init -q
    git checkout -q -b main
    echo "initial" > file.txt
    git add file.txt
    git commit -q -m "Initial"

    ORIGIN_DIR="$(mktemp -d)"
    git clone -q --bare . "$ORIGIN_DIR"
    git remote add origin "$ORIGIN_DIR"
    git push -q -u origin main

    git checkout -q -b feature/test

    SCRIPT="$BATS_TEST_DIRNAME/../scripts/detect-slop.sh"
    export _LOGIN_SHELL_SOURCED=1
}

teardown() {
    rm -rf "$TEST_DIR" "$ORIGIN_DIR"
}

@test "detect-slop: requires --base argument" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--base"* ]]
}

@test "detect-slop: handles no changes" {
    run "$SCRIPT" --base main
    [ "$status" -eq 0 ]
    [[ "$output" == *"No changes found"* ]]
}

@test "detect-slop: detects Get/Set style comments" {
    mkdir -p src
    cat > src/test.ts << 'EOF'
// Get the user data
const user = getUser();
// Set the name
user.name = "test";
EOF
    git add .
    git commit -q -m "Add code"

    run "$SCRIPT" --base main
    [ "$status" -eq 0 ]
    [[ "$output" == *"Get/Set"* ]]
}

@test "detect-slop: detects 'This function' comments" {
    mkdir -p src
    cat > src/test.ts << 'EOF'
// This function handles user login
function login() {}
EOF
    git add .
    git commit -q -m "Add code"

    run "$SCRIPT" --base main
    [ "$status" -eq 0 ]
    [[ "$output" == *"This function"* ]]
}

@test "detect-slop: outputs summary" {
    mkdir -p src
    echo "const x = 1" > src/test.ts
    git add .
    git commit -q -m "Add code"

    run "$SCRIPT" --base main
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUMMARY"* ]]
}
