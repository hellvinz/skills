#!/usr/bin/env bats

# Test fetch-url.sh

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../scripts/fetch-url.sh"
}

# === Usage tests ===

@test "fetch-url: shows usage with --help" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "fetch-url: requires URL argument" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"URL is required"* ]]
}

@test "fetch-url: rejects unknown options" {
    run "$SCRIPT" --unknown
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

# === URL validation tests ===

@test "fetch-url: rejects URL without protocol" {
    run "$SCRIPT" "example.com/page"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid URL format"* ]]
}

@test "fetch-url: rejects URL with ftp protocol" {
    run "$SCRIPT" "ftp://example.com/file"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid URL format"* ]]
}

@test "fetch-url --json: returns error JSON for invalid URL" {
    run "$SCRIPT" --json "not-a-url"
    [ "$status" -eq 1 ]
    [[ "$output" == *"accessible"* ]]
    [[ "$output" == *"false"* ]]
}

# === HTTP tests (require network) ===
# These tests are skipped if SKIP_NETWORK_TESTS is set

@test "fetch-url: validates accessible URL" {
    if [[ -n "${SKIP_NETWORK_TESTS:-}" ]]; then
        skip "Network tests disabled"
    fi

    run "$SCRIPT" "https://example.com"
    [ "$status" -eq 0 ]
    [[ "$output" == *"accessible"* ]]
}

@test "fetch-url --json: returns JSON for accessible URL" {
    if [[ -n "${SKIP_NETWORK_TESTS:-}" ]]; then
        skip "Network tests disabled"
    fi

    run "$SCRIPT" --json "https://example.com"
    [ "$status" -eq 0 ]

    # Validate JSON structure
    echo "$output" | jq -e '.accessible' > /dev/null
    echo "$output" | jq -e '.status_code' > /dev/null
    echo "$output" | jq -e '.domain' > /dev/null
}

@test "fetch-url: extracts domain correctly" {
    if [[ -n "${SKIP_NETWORK_TESTS:-}" ]]; then
        skip "Network tests disabled"
    fi

    run "$SCRIPT" --json "https://example.com/path/to/page"
    [ "$status" -eq 0 ]

    domain=$(echo "$output" | jq -r '.domain')
    [ "$domain" = "example.com" ]
}

@test "fetch-url: handles non-existent domain" {
    if [[ -n "${SKIP_NETWORK_TESTS:-}" ]]; then
        skip "Network tests disabled"
    fi

    run "$SCRIPT" "https://this-domain-does-not-exist-12345.com"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not accessible"* ]]
}
