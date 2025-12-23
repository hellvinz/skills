.PHONY: test lint check

check: lint test

lint:
	shellcheck scripts/*.sh code-review-skill/scripts/*.sh code-review-skill/phases/*/*.sh

test:
	bats test/*.bats code-review-skill/test/*.bats
