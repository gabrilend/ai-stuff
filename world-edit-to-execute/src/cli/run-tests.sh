#!/bin/bash
# Unified Test Runner for world-edit-to-execute
# Discovers and runs all test_*.lua files, aggregates results, and reports statistics.
# Supports filtering, verbose/quiet modes, and stops-on-first-failure option.

# {{{ Configuration
DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
TESTS_DIR=""
LUAJIT="luajit"

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
fi
# }}}

# {{{ Usage
# -- usage
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [PATTERN]

Runs all test_*.lua files in src/tests/ and reports results.

Options:
  -v, --verbose    Show all test output (default: show only failures)
  -q, --quiet      Show only summary (no per-file output)
  -x, --stop       Stop on first failure
  -l, --list       List tests without running
  -t, --timing     Show timing for each test
  -d, --dir DIR    Project directory (default: $DIR)
  -h, --help       Show this help

Arguments:
  PATTERN          Only run tests matching this pattern (e.g., "ecs", "parser")

Examples:
  $(basename "$0")              # Run all tests
  $(basename "$0") ecs          # Run tests matching "ecs"
  $(basename "$0") -v parser    # Verbose output for parser tests
  $(basename "$0") -x           # Stop on first failure
  $(basename "$0") -l           # List all tests
  $(basename "$0") -t           # Show timing for each test

Exit codes:
  0   All tests passed
  1   One or more tests failed
  2   No tests found
EOF
    exit 0
}
# }}}

# {{{ Parse arguments
# -- parse_args
parse_args() {
    VERBOSE=0
    QUIET=0
    STOP_ON_FAIL=0
    LIST_ONLY=0
    SHOW_TIMING=0
    PATTERN=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            -x|--stop)
                STOP_ON_FAIL=1
                shift
                ;;
            -l|--list)
                LIST_ONLY=1
                shift
                ;;
            -t|--timing)
                SHOW_TIMING=1
                shift
                ;;
            -d|--dir)
                shift
                DIR="$1"
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
            *)
                # Non-option argument is the pattern
                PATTERN="$1"
                shift
                ;;
        esac
    done

    # Set TESTS_DIR after parsing
    TESTS_DIR="${DIR}/src/tests"
}
# }}}

# {{{ Discover tests
# -- discover_tests
discover_tests() {
    local pattern="$1"
    local tests=()

    # Find all test_*.lua files
    while IFS= read -r -d '' file; do
        local basename
        basename=$(basename "$file")

        # Skip non-test files
        [[ "$basename" != test_*.lua ]] && continue

        # Apply pattern filter if specified
        if [[ -n "$pattern" ]]; then
            # Match pattern anywhere in filename (case insensitive)
            if [[ ! "${basename,,}" == *"${pattern,,}"* ]]; then
                continue
            fi
        fi

        tests+=("$file")
    done < <(find "$TESTS_DIR" -maxdepth 1 -name "test_*.lua" -type f -print0 | sort -z)

    printf '%s\n' "${tests[@]}"
}
# }}}

# {{{ Run single test
# -- run_test
run_test() {
    local test_file="$1"
    local basename
    basename=$(basename "$test_file")

    # Capture output and timing
    local start_time end_time duration
    local output exit_code

    start_time=$(date +%s.%N)
    output=$(cd "$DIR" && "$LUAJIT" "$test_file" 2>&1)
    exit_code=$?
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")

    # Parse test summary from output
    # Supports multiple formats:
    #   Format 1a: "Tests: N passed, M failed" or "Tests: N passed, M failed, T total"
    #   Format 1b: "Tests: N passed / M total"
    #   Format 2a: "Tests passed: N/M"
    #   Format 2b: "Passed: N / M"
    #   Format 3:  "N tests passed" or similar
    local passed=0 failed=0 total=0
    local summary_line
    local parsed=0

    # Try format 1a: "Tests: N passed, M failed"
    if [[ $parsed -eq 0 ]]; then
        summary_line=$(echo "$output" | grep -iE "Tests:.*passed.*failed" | tail -1)
        if [[ -n "$summary_line" ]]; then
            passed=$(echo "$summary_line" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo 0)
            failed=$(echo "$summary_line" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || echo 0)
            parsed=1
        fi
    fi

    # Try format 1b: "Tests: N passed / M total"
    if [[ $parsed -eq 0 ]]; then
        summary_line=$(echo "$output" | grep -iE "Tests:.*[0-9]+ passed.*[0-9]+ total" | tail -1)
        if [[ -n "$summary_line" ]]; then
            local nums
            nums=$(echo "$summary_line" | grep -oE '[0-9]+' | tr '\n' ' ')
            passed=$(echo "$nums" | awk '{print $1}')
            total=$(echo "$nums" | awk '{print $2}')
            failed=$((total - passed))
            parsed=1
        fi
    fi

    # Try format 2a: "Tests passed: N/M"
    if [[ $parsed -eq 0 ]]; then
        summary_line=$(echo "$output" | grep -iE "Tests passed:.*[0-9]+.*[0-9]+" | tail -1)
        if [[ -n "$summary_line" ]]; then
            local nums
            nums=$(echo "$summary_line" | grep -oE '[0-9]+' | tr '\n' ' ')
            passed=$(echo "$nums" | awk '{print $1}')
            total=$(echo "$nums" | awk '{print $2}')
            failed=$((total - passed))
            parsed=1
        fi
    fi

    # Try format 2b: "Passed: N / M" (with explicit separator between two numbers)
    if [[ $parsed -eq 0 ]]; then
        summary_line=$(echo "$output" | grep -iE "^Passed:.*[0-9]+.*/.*[0-9]+" | tail -1)
        if [[ -n "$summary_line" ]]; then
            local nums
            nums=$(echo "$summary_line" | grep -oE '[0-9]+' | tr '\n' ' ')
            passed=$(echo "$nums" | awk '{print $1}')
            total=$(echo "$nums" | awk '{print $2}')
            if [[ -n "$total" && "$total" -gt 0 ]]; then
                failed=$((total - passed))
            fi
            parsed=1
        fi
    fi

    # Try format 3: "N tests passed" or similar
    if [[ $parsed -eq 0 ]]; then
        summary_line=$(echo "$output" | grep -iE "[0-9]+ tests? passed" | tail -1)
        if [[ -n "$summary_line" ]]; then
            passed=$(echo "$summary_line" | grep -oE '[0-9]+' | head -1 || echo 0)
            # Check for failed count
            local fail_line
            fail_line=$(echo "$output" | grep -iE "[0-9]+ (tests? )?failed" | tail -1)
            if [[ -n "$fail_line" ]]; then
                failed=$(echo "$fail_line" | grep -oE '[0-9]+' | head -1 || echo 0)
            fi
            parsed=1
        fi
    fi

    # Try format 4: Multiline "Passed: N" / "Failed: M"
    if [[ $parsed -eq 0 ]]; then
        local pass_line fail_line_sep
        pass_line=$(echo "$output" | grep -iE "^Passed: *[0-9]+$" | tail -1)
        if [[ -n "$pass_line" ]]; then
            passed=$(echo "$pass_line" | grep -oE '[0-9]+' || echo 0)
            fail_line_sep=$(echo "$output" | grep -iE "^Failed: *[0-9]+$" | tail -1)
            if [[ -n "$fail_line_sep" ]]; then
                failed=$(echo "$fail_line_sep" | grep -oE '[0-9]+' || echo 0)
            fi
            parsed=1
        fi
    fi

    # Return results via global variables (bash limitation)
    TEST_PASSED=$passed
    TEST_FAILED=$failed
    TEST_EXIT_CODE=$exit_code
    TEST_OUTPUT="$output"
    TEST_DURATION="$duration"
    TEST_SUMMARY="$summary_line"
}
# }}}

# {{{ Format duration
# -- format_duration
format_duration() {
    local duration="$1"
    # Format to 2 decimal places
    printf "%.2fs" "$duration"
}
# }}}

# {{{ Print test result
# -- print_result
print_result() {
    local basename="$1"
    local passed="$2"
    local failed="$3"
    local exit_code="$4"
    local duration="$5"
    local output="$6"

    local status_icon status_color timing_str=""

    if [[ "$SHOW_TIMING" -eq 1 ]]; then
        timing_str=" ($(format_duration "$duration"))"
    fi

    if [[ $exit_code -eq 0 && $failed -eq 0 ]]; then
        status_icon="PASS"
        status_color="$GREEN"
    else
        status_icon="FAIL"
        status_color="$RED"
    fi

    if [[ $QUIET -eq 0 ]]; then
        printf "${status_color}[${status_icon}]${RESET} %-45s %s${timing_str}\n" \
            "$basename" "(${passed} passed, ${failed} failed)"

        # Show failure details
        if [[ $exit_code -ne 0 || $failed -gt 0 ]]; then
            # Extract failure lines
            echo "$output" | grep -E "(FAIL|Error|error:|assertion failed)" | while read -r line; do
                printf "  ${RED}%-s${RESET}\n" "$line"
            done
        fi

        # Verbose mode: show all output
        if [[ $VERBOSE -eq 1 ]]; then
            echo "$output" | sed 's/^/  /'
            echo ""
        fi
    fi
}
# }}}

# {{{ Main
# -- main
main() {
    parse_args "$@"

    # Verify tests directory exists
    if [[ ! -d "$TESTS_DIR" ]]; then
        echo "Error: Tests directory not found: $TESTS_DIR" >&2
        exit 2
    fi

    # Discover tests
    local tests
    mapfile -t tests < <(discover_tests "$PATTERN")

    if [[ ${#tests[@]} -eq 0 ]]; then
        echo "No tests found matching pattern: ${PATTERN:-*}" >&2
        exit 2
    fi

    # List only mode
    if [[ $LIST_ONLY -eq 1 ]]; then
        echo "Found ${#tests[@]} test file(s):"
        for test in "${tests[@]}"; do
            echo "  $(basename "$test")"
        done
        exit 0
    fi

    # Print header
    if [[ $QUIET -eq 0 ]]; then
        echo ""
        printf "${BOLD}=== Running ${#tests[@]} test file(s) ===${RESET}\n"
        echo ""
    fi

    # Run tests
    local total_passed=0
    local total_failed=0
    local files_passed=0
    local files_failed=0
    local failed_files=()
    local start_time end_time total_duration

    start_time=$(date +%s.%N)

    for test_file in "${tests[@]}"; do
        local basename
        basename=$(basename "$test_file")

        run_test "$test_file"

        total_passed=$((total_passed + TEST_PASSED))
        total_failed=$((total_failed + TEST_FAILED))

        if [[ $TEST_EXIT_CODE -eq 0 && $TEST_FAILED -eq 0 ]]; then
            files_passed=$((files_passed + 1))
        else
            files_failed=$((files_failed + 1))
            failed_files+=("$basename")
        fi

        print_result "$basename" "$TEST_PASSED" "$TEST_FAILED" "$TEST_EXIT_CODE" "$TEST_DURATION" "$TEST_OUTPUT"

        # Stop on first failure if requested
        if [[ $STOP_ON_FAIL -eq 1 && ($TEST_EXIT_CODE -ne 0 || $TEST_FAILED -gt 0) ]]; then
            echo ""
            printf "${RED}Stopping due to test failure (-x flag)${RESET}\n"
            break
        fi
    done

    end_time=$(date +%s.%N)
    total_duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")

    # Print summary
    echo ""
    printf "${BOLD}════════════════════════════════════════════════${RESET}\n"

    if [[ $files_failed -eq 0 ]]; then
        printf "${GREEN}SUMMARY: ${files_passed}/${#tests[@]} test files passed${RESET}\n"
    else
        printf "${RED}SUMMARY: ${files_passed}/${#tests[@]} test files passed${RESET}\n"
    fi

    printf "         ${total_passed} assertions passed, ${total_failed} failed\n"

    if [[ $SHOW_TIMING -eq 1 ]]; then
        printf "         Total time: $(format_duration "$total_duration")\n"
    fi

    if [[ ${#failed_files[@]} -gt 0 ]]; then
        echo ""
        printf "${RED}FAILED TESTS:${RESET}\n"
        for f in "${failed_files[@]}"; do
            printf "  ${RED}- ${f}${RESET}\n"
        done
    fi

    printf "${BOLD}════════════════════════════════════════════════${RESET}\n"

    # Exit with appropriate code
    if [[ $files_failed -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}
# }}}

main "$@"
