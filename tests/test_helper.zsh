#!/usr/bin/env zsh
# Test helper utilities for zsh-ai tests

# Source the plugin files
export ZSH_AI_TEST_MODE=1
PLUGIN_DIR="${0:A:h:h}"

# Mock functions storage
typeset -gA MOCKED_COMMANDS
typeset -gA MOCK_OUTPUTS
typeset -gA MOCK_EXIT_CODES
typeset -gA CALL_COUNTS

# Initialize mock for a command
mock_command() {
    local cmd="$1"
    local output="${2:-}"
    local exit_code="${3:-0}"

    MOCKED_COMMANDS[${cmd}]=1
    MOCK_OUTPUTS[${cmd}]="${output}"
    MOCK_EXIT_CODES[${cmd}]="${exit_code}"
    CALL_COUNTS[${cmd}]=0

    # Create function to override command
    eval "
    ${cmd}() {
        CALL_COUNTS[${cmd}]=\$((CALL_COUNTS[${cmd}] + 1))
        if [[ -n \"\${MOCK_OUTPUTS[${cmd}]}\" ]]; then
            echo \"\${MOCK_OUTPUTS[${cmd}]}\"
        fi
        return \${MOCK_EXIT_CODES[${cmd}]}
    }
    "
}

# Restore mocked command
unmock_command() {
    local cmd="$1"
    unset "MOCKED_COMMANDS[${cmd}]"
    unset "MOCK_OUTPUTS[${cmd}]"
    unset "MOCK_EXIT_CODES[${cmd}]"
    unset "CALL_COUNTS[${cmd}]"
    unfunction "${cmd}" 2>/dev/null
}

# Reset all mocks
reset_mocks() {
    for cmd in ${(k)MOCKED_COMMANDS}; do
        unmock_command "${cmd}"
    done
}

# Assert command was called
assert_called() {
    local cmd="$1"
    local expected_times="${2:-1}"
    local actual_times="${CALL_COUNTS[${cmd}]:-0}"
    if [[ ${actual_times} -ne ${expected_times} ]]; then
        echo "✗ Expected ${cmd} to be called ${expected_times} times, but was called ${actual_times} times"
        return 1
    fi
}

# Mock curl for API requests
mock_curl_response() {
    local response="$1"
    local exit_code="${2:-0}"

    # Store response and exit code in global variables
    MOCK_CURL_RESPONSE="${response}"
    MOCK_CURL_EXIT_CODE="${exit_code}"

    # Create a global curl function
    function curl() {
        [[ "${MOCK_CURL_EXIT_CODE}" -eq 0 ]] || return "${MOCK_CURL_EXIT_CODE}"
        echo "${MOCK_CURL_RESPONSE}"
        return 0
    }
}

# Mock jq command
mock_jq() {
    local available="${1:-true}"
    if [[ "${available}" == "true" ]]; then
        # Use and require real jq to test code with
        unfunction command 2>/dev/null
    else
        # Pretend jq is not installed
        command() {
            if [[ "$1" == "-v" ]] && [[ "$2" == "jq" ]]; then
                return 1
            fi
            builtin command "$@"
        }
    fi
}

# Setup test environment
setup_test_env() {
    # Set test environment variables
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY=""
    export ZSH_AI_MODEL="llama3.2"
    export ZSH_AI_GUARD=""
    # Reset mocks
    reset_mocks
}

# Teardown test environment
teardown_test_env() {
    reset_mocks
    # Unfunction any mocked commands
    unfunction command 2>/dev/null
    unfunction jq 2>/dev/null
    unfunction curl 2>/dev/null
    unset ZSH_AI_PROVIDER
    unset ANTHROPIC_API_KEY
    unset ZSH_AI_MODEL
    unset ZSH_AI_GUARD
    unset ZSH_AI_TEST_MODE
}

# Assert string contains
assert_contains() {
    local haystack="$1"
    local needle="$2"
    if [[ ! "${haystack}" == *"${needle}"* ]]; then
        printf "✗ Expected '%s' to contain '%s'\n" "${haystack//$'\n'/\\n}" "${needle}"
        return 1
    fi
}

# Assert string equals
assert_equals() {
    local actual="$1"
    local expected="$2"
    if [[ "${actual}" != "${expected}" ]]; then
        printf "✗ Expected '%s' but got '%s'\n" "${expected}" "${actual//$'\n'/\\n}"
        return 1
    fi
}

# Assert string equals
assert_not_equals() {
    local actual="$1"
    local expected="$2"
    if [[ "${actual}" == "${expected}" ]]; then
        printf "✗ Expected '%s' to be not equal '%s'\n" "${actual//$'\n'/\\n}" "${expected}"
        return 1
    fi
}

# Assert string does not contain
assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    if [[ "${haystack}" == *"${needle}"* ]]; then
        printf "✗ Expected '%s' to not contain '%s'\n" "${haystack//$'\n'/\\n}" "${needle}"
        return 1
    fi
}

# Assert greater than
assert_greater_than() {
    local actual="$1"
    local expected="$2"
    if [[ "${actual}" -le "${expected}" ]]; then
        printf "✗ Expected '%s' to be greater than '%s'\n" "${actual//$'\n'/\\n}" "${expected}"
        return 1
    fi
}

# Capture function output
capture_output() {
    local func="$1"
    shift
    local output
    output=$("${func}" "$@" 2>&1)
    print -r "${output}"
}

# Create temporary test directory
create_test_dir() {
    mktemp -d
}

# Cleanup temporary test directory
cleanup_test_dir() {
    local test_dir="$1"
    [[ -d "${test_dir}" ]] && rm -rf "${test_dir}"
}
