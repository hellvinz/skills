.PHONY: test lint check

check: lint test

lint:
	shellcheck -x --source-path=SCRIPTDIR scripts/*.sh scripts/lib/*.sh code-review-skill/scripts/*.sh code-review-skill/phases/*/*.sh knowledge-curation-skill/scripts/*.sh knowledge-curation-skill/phases/*/*.sh

test:
	bats test/*.bats code-review-skill/test/*.bats knowledge-curation-skill/test/*.bats
