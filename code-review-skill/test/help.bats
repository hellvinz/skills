#!/usr/bin/env bats

# Every script must self-document via --help so agents can recover from
# usage errors without reading the script sources (see SKILL.md
# "Working with the scripts").

setup() {
    SCRIPTS_DIR="$BATS_TEST_DIRNAME/../scripts"
    export _LOGIN_SHELL_SOURCED=1
}

@test "help: every script prints its header doc block on --help" {
    for f in "$SCRIPTS_DIR"/*.sh; do
        run "$f" --help
        [ "$status" -eq 0 ]
        [[ "$output" == *"$(basename "$f")"* ]] || {
            echo "missing self-description in --help of $(basename "$f")"
            false
        }
    done
}

@test "help: -h is an alias for --help" {
    run "$SCRIPTS_DIR/review.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"review.sh"* ]]
}

@test "help: review.sh --help documents set quoting" {
    run "$SCRIPTS_DIR/review.sh" --help
    [[ "$output" == *"ONE JSON value"* ]]
    [[ "$output" == *"jq -Rs"* ]]
}

@test "help: list-changes.sh --help documents bare branch names" {
    run "$SCRIPTS_DIR/list-changes.sh" --help
    [[ "$output" == *"bare branch name"* ]]
}

@test "help: add-comment.sh --help documents the diff anchoring constraint" {
    run "$SCRIPTS_DIR/add-comment.sh" --help
    [[ "$output" == *"part of the PR diff"* ]]
}
