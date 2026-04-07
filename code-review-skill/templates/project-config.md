# Code Review Config

# This file is read by the code-review skill at the start of every review on
# this project. Its content is injected as persistent directives so you don't
# need to retype project-specific context at every review.
#
# Format is markdown — there is no schema. Edit freely. The agent reads the
# raw text and uses it to decide which mandatory checks to run in phase 2.

## Live testing

# URL the agent should open with chrome-devtools-mcp to verify changes live.
# Include the command if a wrapper is needed.
dev_url: # e.g. yarn dev:online https://staging.example.com/path

## Design system reference paths

# Local paths the agent will grep to find the valid token (color, spacing,
# typography mixin) for any hardcoded styling value detected in the diff.
# Without this, hardcoded-value findings stay vague and unactionable.
ds_reference_paths:
  # - ~/Projects/your-monorepo/packages/styles

## Priority libraries

# Libraries whose API the agent should systematically verify via context7
# when their imports appear in the diff (XState, React, Storybook, etc.).
# Optional — if empty, the agent infers from the diff itself.
priority_libs:
  # - xstate
  # - @xstate/react

## Project conventions

# Free-form notes about local conventions the agent should respect.
# Examples: aria prop naming, doc placement, file naming patterns.
conventions:
  # - aria props use camelCase (ariaLabel) due to wrapper component
  # - SDD docs live under docs/sdd/
