#!/usr/bin/env bats

# Test load-project-config.sh
# Critical: must always exit 0, even when the file is missing/empty/unreadable.

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    SCRIPT="$BATS_TEST_DIRNAME/../scripts/load-project-config.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "load-project-config: no .review directory -> exit 0, empty stdout" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "load-project-config: .review/ exists but no config.md -> exit 0, empty stdout" {
    mkdir -p .review
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "load-project-config: empty config.md -> exit 0, empty stdout" {
    mkdir -p .review
    : > .review/config.md
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "load-project-config: populated config.md -> exit 0, content on stdout" {
    mkdir -p .review
    cat > .review/config.md <<'EOF'
# Code Review Config

dev_url: yarn dev:online https://example.test/
ds_reference_paths:
  - ~/Projects/some-ds/packages/styles
EOF

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"dev_url"* ]]
    [[ "$output" == *"ds_reference_paths"* ]]
}

@test "load-project-config: unreadable config.md -> exit 0, empty stdout" {
    mkdir -p .review
    echo "secret" > .review/config.md
    chmod 000 .review/config.md

    run "$SCRIPT"

    chmod 644 .review/config.md
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
