#!/usr/bin/env bats

setup() {
    TEST_DIR="$(mktemp -d)"
    export TEST_SKILLS_ROOT="$TEST_DIR"

    # Copy script and template to test directory
    mkdir -p "$TEST_DIR/scripts" "$TEST_DIR/template"
    cp "$BATS_TEST_DIRNAME/../scripts/new-skill.sh" "$TEST_DIR/scripts/"

    # Create minimal template
    cat > "$TEST_DIR/template/SKILL.md" << 'EOF'
---
name: {{SKILL_NAME}}
description: {{DESCRIPTION}}
---
# {{SKILL_TITLE}}
EOF

    # Patch script to use TEST_SKILLS_ROOT
    sed -i.bak 's|SKILLS_ROOT="$(dirname "$SCRIPT_DIR")"|SKILLS_ROOT="${TEST_SKILLS_ROOT:-$(dirname "$SCRIPT_DIR")}"|' \
        "$TEST_DIR/scripts/new-skill.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "shows usage when no arguments" {
    run "$TEST_DIR/scripts/new-skill.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "shows usage when only one argument" {
    run "$TEST_DIR/scripts/new-skill.sh" "my-skill"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "rejects uppercase in skill name" {
    run "$TEST_DIR/scripts/new-skill.sh" "MySkill" "A test skill"
    [ "$status" -eq 1 ]
    [[ "$output" == *"hyphen-case"* ]]
}

@test "rejects spaces in skill name" {
    run "$TEST_DIR/scripts/new-skill.sh" "my skill" "A test skill"
    [ "$status" -eq 1 ]
    [[ "$output" == *"hyphen-case"* ]]
}

@test "rejects skill name starting with number" {
    run "$TEST_DIR/scripts/new-skill.sh" "1skill" "A test skill"
    [ "$status" -eq 1 ]
    [[ "$output" == *"hyphen-case"* ]]
}

@test "accepts valid hyphen-case name" {
    run "$TEST_DIR/scripts/new-skill.sh" "my-test-skill" "A test skill"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Done!"* ]]
}

@test "creates skill directory with -skill suffix" {
    run "$TEST_DIR/scripts/new-skill.sh" "data-analysis" "Analyze data"
    [ "$status" -eq 0 ]
    [ -d "$TEST_DIR/data-analysis-skill" ]
}

@test "creates required subdirectories" {
    run "$TEST_DIR/scripts/new-skill.sh" "test-skill" "A test"
    [ "$status" -eq 0 ]
    [ -d "$TEST_DIR/test-skill-skill/scripts" ]
    [ -d "$TEST_DIR/test-skill-skill/principles" ]
    [ -d "$TEST_DIR/test-skill-skill/templates" ]
}

@test "creates SKILL.md from template" {
    run "$TEST_DIR/scripts/new-skill.sh" "test-skill" "A test"
    [ "$status" -eq 0 ]
    [ -f "$TEST_DIR/test-skill-skill/SKILL.md" ]
    grep -q "name: test-skill" "$TEST_DIR/test-skill-skill/SKILL.md"
}

@test "rejects duplicate skill name" {
    "$TEST_DIR/scripts/new-skill.sh" "dupe-skill" "First"
    run "$TEST_DIR/scripts/new-skill.sh" "dupe-skill" "Second"
    [ "$status" -eq 1 ]
    [[ "$output" == *"already exists"* ]]
}
