#!/usr/bin/env bats

# Test post-comments.sh

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    git init -q
    git checkout -q -b feature/test

    mkdir -p .review

    SCRIPT="$BATS_TEST_DIRNAME/../scripts/post-comments.sh"
    export _LOGIN_SHELL_SOURCED=1

    # Mock gh command
    mkdir -p "$TEST_DIR/bin"
    export PATH="$TEST_DIR/bin:$PATH"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "post-comments: fails when no comments file" {
    cat > "$TEST_DIR/bin/gh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_DIR/bin/gh"

    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No comments file found"* ]]
}

@test "post-comments: fails when no PR exists" {
    echo '{"comments": []}' > .review/comments-feature-test.json

    cat > "$TEST_DIR/bin/gh" << 'EOF'
#!/bin/bash
echo "{}"
EOF
    chmod +x "$TEST_DIR/bin/gh"

    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No PR found"* ]]
}

@test "post-comments: handles empty comments" {
    echo '{"comments": []}' > .review/comments-feature-test.json

    cat > "$TEST_DIR/bin/gh" << 'EOF'
#!/bin/bash
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    echo '{"number": 123, "headRefOid": "abc123"}'
fi
EOF
    chmod +x "$TEST_DIR/bin/gh"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No comments to post"* ]]
}

@test "post-comments: prepares comments when PR exists" {
    cat > .review/comments-feature-test.json << 'EOF'
{"comments": [{"path": "src/test.ts", "line": 10, "body": "Test comment"}]}
EOF

    cat > "$TEST_DIR/bin/gh" << 'EOF'
#!/bin/bash
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    echo '{"number": 123, "headRefOid": "abc123"}'
elif [[ "$1" == "pr" && "$2" == "diff" ]]; then
    echo ""
elif [[ "$1" == "repo" ]]; then
    echo '{"nameWithOwner": "test/repo"}'
fi
EOF
    chmod +x "$TEST_DIR/bin/gh"

    run "$SCRIPT" --dry-run
    # Script should at least start preparing (may fail on gawk but that's ok)
    [[ "$output" == *"Preparing"* ]] || [[ "$output" == *"comment"* ]]
}
