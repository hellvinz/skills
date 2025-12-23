#!/usr/bin/env bats

# Test merge-findings.sh

setup() {
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"

    git init -q
    git checkout -q -b test-branch

    SCRIPT="$BATS_TEST_DIRNAME/../scripts/merge-findings.sh"
    REVIEW="$BATS_TEST_DIRNAME/../scripts/review.sh"

    export _LOGIN_SHELL_SOURCED=1

    "$REVIEW" init > /dev/null
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "merge-findings: handles empty findings" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Merged 0 findings"* ]]
}

@test "merge-findings: merges agent findings only" {
    "$REVIEW" set agent_findings '[{"file": "a.ts", "description": "Agent issue"}]'

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Merged 1 findings"* ]]

    findings=$("$REVIEW" get findings)
    source=$(echo "$findings" | jq -r '.[0].source')
    [ "$source" = "agent" ]
}

@test "merge-findings: merges human findings only" {
    "$REVIEW" set human_findings '[{"file": "b.ts", "description": "Human issue", "source": "human"}]'

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Merged 1 findings"* ]]
}

@test "merge-findings: combines agent and human findings" {
    "$REVIEW" set agent_findings '[{"file": "a.ts", "description": "Agent"}]'
    "$REVIEW" set human_findings '[{"file": "b.ts", "description": "Human", "source": "human"}]'

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Merged 2 findings"* ]]

    count=$("$REVIEW" get findings | jq 'length')
    [ "$count" -eq 2 ]
}

@test "merge-findings: renumbers findings sequentially" {
    "$REVIEW" set agent_findings '[{"file": "a.ts"}, {"file": "b.ts"}]'
    "$REVIEW" set human_findings '[{"file": "c.ts", "source": "human"}]'

    "$SCRIPT"

    findings=$("$REVIEW" get findings)
    id1=$(echo "$findings" | jq -r '.[0].id')
    id2=$(echo "$findings" | jq -r '.[1].id')
    id3=$(echo "$findings" | jq -r '.[2].id')

    [ "$id1" = "1" ]
    [ "$id2" = "2" ]
    [ "$id3" = "3" ]
}

@test "merge-findings: sets status to pending" {
    "$REVIEW" set agent_findings '[{"file": "a.ts"}]'

    "$SCRIPT"

    status=$("$REVIEW" get findings | jq -r '.[0].status')
    [ "$status" = "pending" ]
}
