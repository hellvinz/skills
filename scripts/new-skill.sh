#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a new skill with the standard structure
# Usage: ./scripts/new-skill.sh <skill-name> "<description>"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$SKILLS_ROOT/template"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <skill-name> \"<description>\""
    echo ""
    echo "Arguments:"
    echo "  skill-name    Name in hyphen-case (e.g., code-review, data-analysis)"
    echo "  description   What the skill does and when to use it"
    echo ""
    echo "Example:"
    echo "  $0 data-analysis \"Analyse datasets and generate insights\""
    exit 1
}

# Validate arguments
if [[ $# -lt 2 ]]; then
    usage
fi

SKILL_NAME="$1"
DESCRIPTION="$2"

# Validate skill name format (hyphen-case, lowercase)
if [[ ! "$SKILL_NAME" =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]]; then
    printf "%bError:%b Skill name must be hyphen-case (e.g., my-skill-name)\n" "$RED" "$NC"
    exit 1
fi

SKILL_DIR="$SKILLS_ROOT/$SKILL_NAME-skill"

# Check if skill already exists
if [[ -d "$SKILL_DIR" ]]; then
    printf "%bError:%b Skill '%s' already exists at %s\n" "$RED" "$NC" "$SKILL_NAME" "$SKILL_DIR"
    exit 1
fi

printf "%bCreating skill:%b %s\n" "$BLUE" "$NC" "$SKILL_NAME"
printf "%bLocation:%b %s\n\n" "$BLUE" "$NC" "$SKILL_DIR"

# Create directory structure
mkdir -p "$SKILL_DIR"/{scripts,principles,templates}

# Generate title from name
SKILL_TITLE=$(echo "$SKILL_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

# Copy and customize template
if [[ -f "$TEMPLATE_DIR/SKILL.md" ]]; then
    sed -e "s/{{SKILL_NAME}}/$SKILL_NAME/g" \
        -e "s/{{SKILL_TITLE}}/$SKILL_TITLE Skill/g" \
        -e "s/{{DESCRIPTION}}/$DESCRIPTION/g" \
        -e "s/{{TRIGGERS}}/$SKILL_NAME, ${SKILL_TITLE,,}/g" \
        -e "s/{{ROLE_DESCRIPTION}}/Tu es un assistant spécialisé pour $SKILL_TITLE./g" \
        "$TEMPLATE_DIR/SKILL.md" > "$SKILL_DIR/SKILL.md"
else
    # Fallback if template doesn't exist
    cat > "$SKILL_DIR/SKILL.md" << EOF
---
name: $SKILL_NAME
description: |
  $DESCRIPTION
tools: Read, Grep, Glob, Bash
---

# $SKILL_TITLE Skill

Tu es un assistant spécialisé pour $SKILL_TITLE.

## Workflow

TODO: Définir le workflow

## Principes

TODO: Définir les principes
EOF
fi

# Create placeholder files
cat > "$SKILL_DIR/principles/.gitkeep" << EOF
# Principles

Reference documents for decision-making go here.
EOF

cat > "$SKILL_DIR/templates/.gitkeep" << EOF
# Templates

Workflow tracking templates go here.
EOF

cat > "$SKILL_DIR/scripts/.gitkeep" << EOF
# Scripts

Automation scripts go here.
EOF

# Create a basic validation script
cat > "$SKILL_DIR/scripts/validate.sh" << 'EOF'
#!/bin/bash
set -e

# Validation script for the skill
# Add your validation commands here

echo "=== VALIDATION ==="

# Example validations (customize as needed)
# yarn lint && echo "✓ LINT OK" || echo "✗ LINT FAILED"
# yarn test && echo "✓ TESTS OK" || echo "✗ TESTS FAILED"

echo "Validation complete."
EOF

chmod +x "$SKILL_DIR/scripts/validate.sh"

printf "%b✓%b Created skill structure:\n\n" "$GREEN" "$NC"
find "$SKILL_DIR" -type f | sed "s|$SKILLS_ROOT/||" | sort | while read -r file; do
    echo "  $file"
done
printf "\n%bNext steps:%b\n" "$YELLOW" "$NC"
echo "  1. Edit $SKILL_DIR/SKILL.md to define your workflow"
echo "  2. Add reference documents to $SKILL_DIR/principles/"
echo "  3. Add templates to $SKILL_DIR/templates/"
echo "  4. Add automation scripts to $SKILL_DIR/scripts/"
printf "\n%bDone!%b\n" "$GREEN" "$NC"
