#!/bin/bash
# test-runner.sh
# Discovers and runs all test files, aggregates results, and outputs reports.
# Project-abstract: works on any project with standard test file conventions.
#
# Usage:
#   ./test-runner.sh [options]
#   ./test-runner.sh -a            (run all tests)
#   ./test-runner.sh -p 1          (run Phase 1 tests only)
#
# Options:
#   -d, --dir <path>      Project directory (default: current)
#   -a, --all             Run all tests
#   -p, --phase <n>       Run tests for specific phase
#   -f, --filter <pat>    Filter test files by pattern
#   -t, --timeout <n>     Test timeout in seconds (default: 60)
#   -v, --verbose         Show test output
#   -q, --quiet           Only show summary
#   --junit <file>        Output JUnit XML report
#   --json <file>         Output JSON report
#   --parallel <n>        Run N tests in parallel
#   -I, --interactive     TUI mode for selecting tests
#   -h, --help            Show help
#
# Library usage:
#   source /path/to/scripts/test-runner.sh
#   test_runner_init "$PROJECT_DIR"
#   tests=$(test_runner_discover "$TEST_DIR" "$PATTERN")
#   test_runner_run_all "$tests"
#   test_runner_render_terminal

set -euo pipefail

# {{{ Configuration
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
LIBS_DIR="${SCRIPT_DIR}/libs"

# Project config
PROJECT_DIR="$(pwd)"
TEST_DIR="src/tests"
TEST_PATTERN="test_*.lua"
LUA_CMD="luajit"
TIMEOUT=60
VERBOSE=false
QUIET=false
RUN_ALL=false
TARGET_PHASE=""
FILTER_PATTERN=""
JUNIT_FILE=""
JSON_FILE=""
PARALLEL_COUNT=1
INTERACTIVE=false

# Results storage
declare -A TEST_RESULTS
declare -A TEST_DURATIONS
declare -A TEST_OUTPUTS
# }}}

# {{{ TUI Libraries
TUI_AVAILABLE=false
if [[ -f "${LIBS_DIR}/tui.sh" ]] && [[ -f "${LIBS_DIR}/menu.sh" ]]; then
    source "${LIBS_DIR}/tui.sh"
    source "${LIBS_DIR}/checkbox.sh"
    source "${LIBS_DIR}/multistate.sh"
    source "${LIBS_DIR}/input.sh"
    source "${LIBS_DIR}/menu.sh"
    TUI_AVAILABLE=true
fi
# }}}

# {{{ Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
# }}}

# {{{ show_help
show_help() {
    cat << 'EOF'
test-runner.sh - Unified test runner with multiple output formats

USAGE:
    ./test-runner.sh [options]

OPTIONS:
    -d, --dir <path>      Project directory (default: current)
    -a, --all             Run all tests
    -p, --phase <n>       Run tests for specific phase
    -f, --filter <pat>    Filter test files by pattern
    -t, --timeout <n>     Test timeout in seconds (default: 60)
    -v, --verbose         Show test output
    -q, --quiet           Only show summary
    --junit <file>        Output JUnit XML report
    --json <file>         Output JSON report
    --parallel <n>        Run N tests in parallel
    -I, --interactive     TUI mode for selecting tests
    -h, --help            Show help

EXAMPLES:
    ./test-runner.sh -a              # Run all tests
    ./test-runner.sh -a -v           # Verbose output
    ./test-runner.sh -p 1            # Phase 1 tests only
    ./test-runner.sh --junit ci.xml  # Generate JUnit report
    ./test-runner.sh -I              # Interactive mode

EOF
}
# }}}

# {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                PROJECT_DIR="$2"
                shift 2
                ;;
            -a|--all)
                RUN_ALL=true
                shift
                ;;
            -p|--phase)
                TARGET_PHASE="$2"
                shift 2
                ;;
            -f|--filter)
                FILTER_PATTERN="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --junit)
                JUNIT_FILE="$2"
                shift 2
                ;;
            --json)
                JSON_FILE="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL_COUNT="$2"
                shift 2
                ;;
            -I|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}
# }}}

# {{{ test_runner_init
test_runner_init() {
    PROJECT_DIR="${1:-$(pwd)}"
    TEST_DIR="${PROJECT_DIR}/${TEST_DIR}"

    # Detect lua command
    if command -v luajit &>/dev/null; then
        LUA_CMD="luajit"
    elif command -v lua5.4 &>/dev/null; then
        LUA_CMD="lua5.4"
    elif command -v lua &>/dev/null; then
        LUA_CMD="lua"
    fi
}
# }}}

# {{{ test_runner_discover
# Discover test files matching criteria
test_runner_discover() {
    local test_dir="${1:-$TEST_DIR}"
    local pattern="${2:-$TEST_PATTERN}"

    find "$test_dir" -maxdepth 1 -name "$pattern" -type f 2>/dev/null | sort | while read -r test_file; do
        # Apply phase filter
        if [[ -n "$TARGET_PHASE" ]]; then
            local basename=$(basename "$test_file")
            # Check for phase in filename (e.g., test_1xx.lua, phase1_test.lua)
            if ! [[ "$basename" =~ ${TARGET_PHASE} ]] && ! [[ "$basename" =~ phase${TARGET_PHASE} ]]; then
                continue
            fi
        fi

        # Apply custom filter
        if [[ -n "$FILTER_PATTERN" ]]; then
            if ! [[ "$test_file" =~ $FILTER_PATTERN ]]; then
                continue
            fi
        fi

        echo "$test_file"
    done
}
# }}}

# {{{ test_runner_run
# Run a single test file
# Returns: exit_code|duration|output
test_runner_run() {
    local test_file="$1"
    local timeout_val="${2:-$TIMEOUT}"

    local start_time=$(date +%s.%N)
    local output
    local exit_code

    # Run with timeout
    output=$(timeout "$timeout_val" $LUA_CMD "$test_file" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    # Check for timeout
    if [[ $exit_code -eq 124 ]]; then
        output="TIMEOUT after ${timeout_val}s"
    fi

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")

    echo "${exit_code}|${duration}|${output}"
}
# }}}

# {{{ test_runner_run_all
# Run all discovered tests
test_runner_run_all() {
    local tests="$1"
    local total=0
    local passed=0
    local failed=0

    while IFS= read -r test_file; do
        [[ -z "$test_file" ]] && continue
        ((total++))

        local test_name=$(basename "$test_file" .lua)

        if ! $QUIET; then
            echo -n "  Running $test_name... "
        fi

        local result=$(test_runner_run "$test_file")
        local exit_code=$(echo "$result" | cut -d'|' -f1)
        local duration=$(echo "$result" | cut -d'|' -f2)
        local output=$(echo "$result" | cut -d'|' -f3-)

        TEST_DURATIONS["$test_file"]="$duration"
        TEST_OUTPUTS["$test_file"]="$output"

        if [[ "$exit_code" -eq 0 ]]; then
            TEST_RESULTS["$test_file"]="pass"
            ((passed++))
            if ! $QUIET; then
                echo -e "${GREEN}PASS${NC} (${duration}s)"
            fi
        else
            TEST_RESULTS["$test_file"]="fail"
            ((failed++))
            if ! $QUIET; then
                echo -e "${RED}FAIL${NC} (${duration}s)"
            fi
        fi

        if $VERBOSE && [[ -n "$output" ]]; then
            echo "$output" | sed 's/^/    /'
        fi
    done <<< "$tests"

    echo ""
    return $failed
}
# }}}

# {{{ test_runner_aggregate
# Get aggregated statistics
test_runner_aggregate() {
    local passed=0
    local failed=0
    local total_duration=0

    for test in "${!TEST_RESULTS[@]}"; do
        if [[ "${TEST_RESULTS[$test]}" == "pass" ]]; then
            ((passed++))
        else
            ((failed++))
        fi
        total_duration=$(echo "$total_duration + ${TEST_DURATIONS[$test]:-0}" | bc 2>/dev/null || echo "$total_duration")
    done

    echo "${passed}|${failed}|${total_duration}"
}
# }}}

# {{{ test_runner_render_terminal
# Display terminal results
test_runner_render_terminal() {
    local stats=$(test_runner_aggregate)
    local passed=$(echo "$stats" | cut -d'|' -f1)
    local failed=$(echo "$stats" | cut -d'|' -f2)
    local duration=$(echo "$stats" | cut -d'|' -f3)
    local total=$((passed + failed))

    echo "═══════════════════════════════════════════════════════════"
    echo "                     TEST RESULTS                          "
    echo "═══════════════════════════════════════════════════════════"

    for test in "${!TEST_RESULTS[@]}"; do
        local status="${TEST_RESULTS[$test]}"
        local dur="${TEST_DURATIONS[$test]:-0}"
        local name=$(basename "$test" .lua)

        if [[ "$status" == "pass" ]]; then
            printf "  ${GREEN}✓${NC} %-45s %6.2fs\n" "$name" "$dur"
        else
            printf "  ${RED}✗${NC} %-45s %6.2fs\n" "$name" "$dur"
        fi
    done

    echo "───────────────────────────────────────────────────────────"
    echo -e "  ${GREEN}Passed: $passed${NC} | ${RED}Failed: $failed${NC} | Total: $total"
    echo "  Total time: ${duration}s"
    echo "═══════════════════════════════════════════════════════════"

    if [[ $failed -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All tests passed!${NC}"
    else
        echo -e "\n${RED}✗ Some tests failed!${NC}"
    fi
}
# }}}

# {{{ test_runner_render_junit
# Generate JUnit XML report
test_runner_render_junit() {
    local output_file="$1"
    local stats=$(test_runner_aggregate)
    local passed=$(echo "$stats" | cut -d'|' -f1)
    local failed=$(echo "$stats" | cut -d'|' -f2)
    local duration=$(echo "$stats" | cut -d'|' -f3)
    local total=$((passed + failed))

    cat > "$output_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites tests="$total" failures="$failed" errors="0" time="$duration">
  <testsuite name="$(basename "$PROJECT_DIR")" tests="$total" failures="$failed" time="$duration">
EOF

    for test in "${!TEST_RESULTS[@]}"; do
        local name=$(basename "$test" .lua)
        local status="${TEST_RESULTS[$test]}"
        local dur="${TEST_DURATIONS[$test]:-0}"

        echo "    <testcase name=\"$name\" time=\"$dur\">" >> "$output_file"
        if [[ "$status" == "fail" ]]; then
            local output="${TEST_OUTPUTS[$test]:-}"
            output=$(echo "$output" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            echo "      <failure message=\"Test failed\"><![CDATA[$output]]></failure>" >> "$output_file"
        fi
        echo "    </testcase>" >> "$output_file"
    done

    echo "  </testsuite>" >> "$output_file"
    echo "</testsuites>" >> "$output_file"

    echo -e "${GREEN}✓${NC} JUnit report written to: $output_file"
}
# }}}

# {{{ test_runner_render_json
# Generate JSON report
test_runner_render_json() {
    local output_file="$1"
    local stats=$(test_runner_aggregate)
    local passed=$(echo "$stats" | cut -d'|' -f1)
    local failed=$(echo "$stats" | cut -d'|' -f2)
    local duration=$(echo "$stats" | cut -d'|' -f3)

    cat > "$output_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "summary": {
    "passed": $passed,
    "failed": $failed,
    "total": $((passed + failed)),
    "duration": $duration
  },
  "tests": [
EOF

    local first=true
    for test in "${!TEST_RESULTS[@]}"; do
        local name=$(basename "$test" .lua)
        local status="${TEST_RESULTS[$test]}"
        local dur="${TEST_DURATIONS[$test]:-0}"

        if ! $first; then
            echo "," >> "$output_file"
        fi
        first=false

        cat >> "$output_file" << EOF
    {
      "name": "$name",
      "status": "$status",
      "duration": $dur
    }
EOF
    done

    echo "" >> "$output_file"
    echo "  ]" >> "$output_file"
    echo "}" >> "$output_file"

    echo -e "${GREEN}✓${NC} JSON report written to: $output_file"
}
# }}}

# {{{ run_interactive
run_interactive() {
    if ! $TUI_AVAILABLE; then
        echo "TUI libraries not available. Using simple menu."
        echo ""
        echo "Options:"
        echo "  a) Run all tests"
        echo "  v) Run all tests (verbose)"
        echo "  q) Quit"
        echo ""
        read -p "Choice: " choice

        case "$choice" in
            a) RUN_ALL=true ;;
            v) RUN_ALL=true; VERBOSE=true ;;
            q) exit 0 ;;
            *) echo "Invalid choice"; return 1 ;;
        esac
        return 0
    fi

    # Full TUI mode
    tui_init
    menu_init

    menu_set_title "Test Runner" "Select tests to run"

    # Discover tests
    test_runner_init "$PROJECT_DIR"
    local tests=$(test_runner_discover "${PROJECT_DIR}/${TEST_DIR}" "$TEST_PATTERN")

    menu_add_section "tests" "multi" "Tests"
    while IFS= read -r test_file; do
        [[ -z "$test_file" ]] && continue
        local name=$(basename "$test_file" .lua)
        menu_add_item "tests" "$name" "$name" "checkbox" "1" ""
    done <<< "$tests"

    menu_add_section "options" "multi" "Options"
    menu_add_item "options" "verbose" "Verbose Output" "checkbox" "0" "Show test output"

    if menu_run; then
        tui_cleanup

        VERBOSE=$(menu_item_is_selected "options" "verbose" && echo true || echo false)

        # Filter to selected tests
        local selected_tests=""
        while IFS= read -r test_file; do
            [[ -z "$test_file" ]] && continue
            local name=$(basename "$test_file" .lua)
            if menu_item_is_selected "tests" "$name"; then
                selected_tests="${selected_tests}${test_file}"$'\n'
            fi
        done <<< "$tests"

        echo ""
        test_runner_run_all "$selected_tests"
        test_runner_render_terminal
    else
        tui_cleanup
        echo "Cancelled."
    fi
}
# }}}

# {{{ main
main() {
    parse_args "$@"
    test_runner_init "$PROJECT_DIR"

    if $INTERACTIVE; then
        run_interactive
        return
    fi

    if ! $RUN_ALL && [[ -z "$TARGET_PHASE" ]] && [[ -z "$FILTER_PATTERN" ]]; then
        show_help
        exit 1
    fi

    local full_test_dir="${PROJECT_DIR}/${TEST_DIR}"

    if [[ ! -d "$full_test_dir" ]]; then
        echo "Error: Test directory not found: $full_test_dir"
        exit 1
    fi

    echo "═══════════════════════════════════════════════════════════"
    echo "                     RUNNING TESTS                         "
    echo "═══════════════════════════════════════════════════════════"
    echo "  Directory: $full_test_dir"
    echo "  Lua: $LUA_CMD"
    [[ -n "$TARGET_PHASE" ]] && echo "  Phase: $TARGET_PHASE"
    echo ""

    local tests=$(test_runner_discover "$full_test_dir" "$TEST_PATTERN")
    local test_count=$(echo "$tests" | grep -c . || echo 0)

    if [[ $test_count -eq 0 ]]; then
        echo "No tests found."
        exit 0
    fi

    echo "  Found $test_count test(s)"
    echo ""

    test_runner_run_all "$tests"
    test_runner_render_terminal

    # Generate reports
    [[ -n "$JUNIT_FILE" ]] && test_runner_render_junit "$JUNIT_FILE"
    [[ -n "$JSON_FILE" ]] && test_runner_render_json "$JSON_FILE"

    # Return failure if any tests failed
    local stats=$(test_runner_aggregate)
    local failed=$(echo "$stats" | cut -d'|' -f2)
    exit $failed
}
# }}}

# Only run main if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
