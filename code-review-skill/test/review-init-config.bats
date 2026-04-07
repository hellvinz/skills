#!/usr/bin/env bats

# Test review.sh init-config command

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    git init -q
    git checkout -q -b test-branch

    SCRIPT="$BATS_TEST_DIRNAME/../scripts/review.sh"

    # Skip login shell relaunch
    export _LOGIN_SHELL_SOURCED=1
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "init-config: creates .review/config.md from template" {
    run "$SCRIPT" init-config
    [ "$status" -eq 0 ]
    [ -f ".review/config.md" ]
    [[ "$output" == *"Created"* ]]
}

@test "init-config: created file contains template markers" {
    "$SCRIPT" init-config
    run cat .review/config.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"dev_url"* ]]
    [[ "$output" == *"ds_reference_paths"* ]]
    [[ "$output" == *"priority_libs"* ]]
}

@test "init-config: refuses to overwrite existing config" {
    mkdir -p .review
    echo "existing content" > .review/config.md

    run "$SCRIPT" init-config
    [ "$status" -eq 1 ]
    [[ "$output" == *"already exists"* ]]

    # Original content untouched
    run cat .review/config.md
    [[ "$output" == "existing content" ]]
}

@test "init-config: creates .review directory if missing" {
    [ ! -d ".review" ]
    run "$SCRIPT" init-config
    [ "$status" -eq 0 ]
    [ -d ".review" ]
}

@test "usage: lists init-config command" {
    run "$SCRIPT" help-unknown
    [[ "$output" == *"init-config"* ]]
}
