#!/usr/bin/env bash
# update-finding.sh - Atomic operations on merged findings array
# Used in Phase 5: ITERATE
#
# Usage:
#   update-finding.sh --remove <id>
#   update-finding.sh --set <id> <field> <value>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

VALID_STATUSES="pending addressed skipped"
VALID_SEVERITIES="critical high medium low"

usage() {
    echo "Usage:" >&2
    echo "  update-finding.sh --remove <id>" >&2
    echo "  update-finding.sh --set <id> <field> <value>" >&2
    echo "" >&2
    echo "Fields: status (pending|addressed|skipped), severity (critical|high|medium|low)" >&2
    exit 1
}

get_findings() {
    local current
    current=$("$SCRIPT_DIR/review.sh" get findings)
    if [[ "$current" == "null" ]]; then
        current="[]"
    fi
    echo "$current"
}

validate_id() {
    local id="$1"
    local findings="$2"
    local count
    count=$(echo "$findings" | jq 'length')

    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        echo "Error: ID must be a positive integer" >&2
        exit 1
    fi

    if [[ "$id" -lt 1 ]] || [[ "$id" -gt "$count" ]]; then
        echo "Error: Finding #$id not found (have $count findings)" >&2
        exit 1
    fi
}

cmd_remove() {
    local id="$1"
    local findings
    findings=$(get_findings)

    validate_id "$id" "$findings"

    # Remove finding and renumber
    local updated
    updated=$(echo "$findings" | jq --argjson id "$id" '
        del(.[] | select(.id == $id))
        | to_entries | map(.value + {id: (.key + 1)})
    ')

    "$SCRIPT_DIR/review.sh" set findings "$updated"

    local remaining
    remaining=$(echo "$updated" | jq 'length')
    echo "Finding #$id removed. Remaining: $remaining"
}

cmd_set() {
    local id="$1"
    local field="$2"
    local value="$3"
    local findings
    findings=$(get_findings)

    validate_id "$id" "$findings"

    # Validate field and value
    case "$field" in
        status)
            if ! echo "$VALID_STATUSES" | grep -qw "$value"; then
                echo "Error: Invalid status '$value'. Valid: $VALID_STATUSES" >&2
                exit 1
            fi
            ;;
        severity)
            if ! echo "$VALID_SEVERITIES" | grep -qw "$value"; then
                echo "Error: Invalid severity '$value'. Valid: $VALID_SEVERITIES" >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: Unknown field '$field'. Valid fields: status, severity" >&2
            exit 1
            ;;
    esac

    # Update field
    local updated
    updated=$(echo "$findings" | jq \
        --argjson id "$id" \
        --arg field "$field" \
        --arg value "$value" '
        map(if .id == $id then . + {($field): $value} else . end)
    ')

    "$SCRIPT_DIR/review.sh" set findings "$updated"

    echo "Finding #$id $field → $value"
}

# Parse arguments
if [[ $# -lt 2 ]]; then
    usage
fi

case "$1" in
    --remove)
        [[ $# -ne 2 ]] && usage
        cmd_remove "$2"
        ;;
    --set)
        [[ $# -ne 4 ]] && usage
        cmd_set "$2" "$3" "$4"
        ;;
    *)
        usage
        ;;
esac
