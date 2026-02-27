#!/usr/bin/env bash
# update-finding.sh - Atomic operations on merged findings array
# Used in Phase 5: ITERATE
#
# Usage:
#   update-finding.sh --remove <id>
#   update-finding.sh --set <id> <field> <value>
#   update-finding.sh --merge <source_id> <target_id>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

VALID_STATUSES="pending addressed skipped"
VALID_SEVERITIES="critical high medium low"
# shellcheck disable=SC2034  # used in severity_rank()
SEVERITY_ORDER=(critical high medium low)

usage() {
    echo "Usage:" >&2
    echo "  update-finding.sh --remove <id>" >&2
    echo "  update-finding.sh --set <id> <field> <value>" >&2
    echo "  update-finding.sh --merge <source_id> <target_id>" >&2
    echo "" >&2
    echo "Fields: status (pending|addressed|skipped), severity (critical|high|medium|low), description" >&2
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

    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        echo "Error: ID must be a positive integer" >&2
        exit 1
    fi

    local exists
    exists=$(echo "$findings" | jq --argjson id "$id" '[.[] | select(.id == $id)] | length')
    if [[ "$exists" -eq 0 ]]; then
        echo "Error: Finding #$id not found" >&2
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
        description)
            if [[ -z "$value" ]]; then
                echo "Error: Description cannot be empty" >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: Unknown field '$field'. Valid fields: status, severity, description" >&2
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

severity_rank() {
    local sev="$1"
    local i
    for i in "${!SEVERITY_ORDER[@]}"; do
        if [[ "${SEVERITY_ORDER[$i]}" == "$sev" ]]; then
            echo "$i"
            return
        fi
    done
    echo "999"
}

higher_severity() {
    local a="$1"
    local b="$2"
    local rank_a rank_b
    rank_a=$(severity_rank "$a")
    rank_b=$(severity_rank "$b")
    if [[ "$rank_a" -le "$rank_b" ]]; then
        echo "$a"
    else
        echo "$b"
    fi
}

cmd_merge() {
    local source_id="$1"
    local target_id="$2"
    local findings
    findings=$(get_findings)

    validate_id "$source_id" "$findings"
    validate_id "$target_id" "$findings"

    if [[ "$source_id" -eq "$target_id" ]]; then
        echo "Error: Cannot merge a finding into itself" >&2
        exit 1
    fi

    # Extract source and target
    local source_desc source_sev target_desc target_sev
    source_desc=$(echo "$findings" | jq -r --argjson id "$source_id" '.[] | select(.id == $id) | .description')
    source_sev=$(echo "$findings" | jq -r --argjson id "$source_id" '.[] | select(.id == $id) | .severity')
    target_desc=$(echo "$findings" | jq -r --argjson id "$target_id" '.[] | select(.id == $id) | .description')
    target_sev=$(echo "$findings" | jq -r --argjson id "$target_id" '.[] | select(.id == $id) | .severity')

    # Merge: combine descriptions, take higher severity
    local merged_desc merged_sev
    merged_desc="${target_desc} | ${source_desc}"
    merged_sev=$(higher_severity "$target_sev" "$source_sev")

    # Update target, remove source, renumber
    local updated
    updated=$(echo "$findings" | jq \
        --argjson src "$source_id" \
        --argjson tgt "$target_id" \
        --arg desc "$merged_desc" \
        --arg sev "$merged_sev" '
        map(if .id == $tgt then . + {description: $desc, severity: $sev} else . end)
        | del(.[] | select(.id == $src))
        | to_entries | map(.value + {id: (.key + 1)})
    ')

    "$SCRIPT_DIR/review.sh" set findings "$updated"

    local remaining
    remaining=$(echo "$updated" | jq 'length')
    echo "Merged finding #$source_id into #$target_id (severity: $merged_sev). Remaining: $remaining"
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
    --merge)
        [[ $# -ne 3 ]] && usage
        cmd_merge "$2" "$3"
        ;;
    *)
        usage
        ;;
esac
