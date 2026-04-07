#!/usr/bin/env bash
# load-project-config.sh - Read .review/config.md from the target project
#
# Output: file content on stdout if readable, empty otherwise.
# Exit:   always 0. The absence of a config file is never an error.
#
# Used by phase 1 to inject project-specific persistent directives
# (dev URL, DS reference paths, priority libs, MCP availability hints).

set -e

CONFIG_FILE=".review/config.md"

if [ -f "$CONFIG_FILE" ] && [ -r "$CONFIG_FILE" ]; then
    cat "$CONFIG_FILE"
fi

exit 0
