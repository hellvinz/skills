.PHONY: test lint check

check: lint test

lint:
	shellcheck scripts/*.sh

test:
	bats test/*.bats
