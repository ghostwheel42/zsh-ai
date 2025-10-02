#!/usr/bin/env zsh

# Test runner for zsh-ai
# Runs all test files and reports results

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_FILES=()

# Run test file and capture results
run_test_file() {
    local test_file="$1"
    echo -e "${YELLOW}Running ${test_file}...${NC}"

    # Run test, display output and count test results
    local exit_code=0 line passed failed
    while read -r line; do
        [[ ${line} =~ ^EXIT_CODE= ]] && exit_code="${line#*=}" && continue
        [[ ${line} == *✓* ]] && : $((passed++)) && line="${GREEN}✓${NC}${line:1}"
        [[ ${line} == *✗* ]] && : $((failed++)) && line="${RED}${line}${NC}"
        [[ ${line} =~ ^Running ]] && line="${YELLOW}${line}${NC}"
        print "  ${line}"
    done < <(zsh "${test_file}" 2>&1 || echo EXIT_CODE=$?)

    # Update totals
    TOTAL_TESTS=$((TOTAL_TESTS + passed + failed))
    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))

    # Track failed files
    if [[ ${exit_code} -ne 0 || ${failed} -gt 0 ]]; then
        FAILED_FILES+=("${test_file}")
    fi

    echo ""
}

# Main function
main() {
    local test_dir="${1:-tests}"

    if ! command -v jq &>/dev/null; then
        echo -e "${RED}Tests need jq to run!${NC}"
        exit 1
    fi

    echo -e "${BLUE}Running zsh-ai tests...${NC}"
    echo ""

    # Find all test files
    local test_files=(${test_dir}/**/*.test.zsh(N))

    if [[ ${#test_files} -eq 0 ]]; then
        echo -e "${YELLOW}No test files found in ${test_dir}${NC}"
        exit 1
    fi

    # Run each test file
    for test_file in ${test_files}; do
        run_test_file "${test_file}"
    done

    # Summary
    echo "================================"
    echo -e "${BLUE}Test Summary:${NC}"
    echo -e "  ${YELLOW}Total Tests: ${TOTAL_TESTS}${NC}"
    echo -e "  ${GREEN}Passed: ${TOTAL_PASSED}${NC}"
    echo -e "  ${RED}Failed: ${TOTAL_FAILED}${NC}"

    if [[ ${#FAILED_FILES} -gt 0 ]]; then
        echo -e "\n${RED}Failed test files:${NC}"
        for file in ${FAILED_FILES}; do
            echo "  - ${file}"
        done
    fi
    echo "================================"

    # Exit based on results
    if [[ ${TOTAL_FAILED} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run if executed directly
if [[ "${ZSH_EVAL_CONTEXT}" == "toplevel" ]]; then
    main "$@"
fi
