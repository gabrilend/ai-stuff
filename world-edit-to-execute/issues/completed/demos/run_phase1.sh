#!/bin/bash
# Phase 1 Demo - File Format Parsing Validation Tests
# Runs all Phase 1 test suites and displays results

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

# {{{ Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
# }}}

# {{{ print_banner
print_banner() {
    echo ""
    echo "========================================"
    echo "  Phase 1: File Format Parsing"
    echo "========================================"
    echo ""
    echo "Running validation tests for completed Phase 1 components:"
    echo "  - MPQ Archive System (102)"
    echo "  - W3I Map Info Parser (103)"
    echo "  - WTS Trigger Strings Parser (104)"
    echo ""
}
# }}}

# {{{ print_section
print_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}
# }}}

# {{{ run_test
run_test() {
    local name="$1"
    local script="$2"
    local passed=0

    print_section "$name"

    if [[ -f "$script" ]]; then
        # Try lua (prefer lua5.4 or lua5.3 for string.unpack)
        local lua_cmd=""
        if command -v lua5.4 &>/dev/null; then
            lua_cmd="lua5.4"
        elif command -v lua &>/dev/null; then
            lua_cmd="lua"
        else
            echo -e "${RED}ERROR: No lua interpreter found${NC}"
            return 1
        fi

        if $lua_cmd "$script"; then
            echo -e "${GREEN}[PASSED]${NC} $name"
            passed=1
        else
            echo -e "${RED}[FAILED]${NC} $name"
        fi
    else
        echo -e "${YELLOW}[SKIP]${NC} Test script not found: $script"
    fi

    return $((1 - passed))
}
# }}}

# {{{ print_summary
print_summary() {
    local passed="$1"
    local total="$2"

    echo ""
    echo "========================================"
    echo "  Test Summary"
    echo "========================================"
    echo ""

    if [[ "$passed" -eq "$total" ]]; then
        echo -e "${GREEN}All tests passed: $passed / $total${NC}"
    else
        echo -e "${YELLOW}Tests passed: $passed / $total${NC}"
        local failed=$((total - passed))
        echo -e "${RED}Tests failed: $failed${NC}"
    fi
    echo ""
}
# }}}

# {{{ show_map_stats
show_map_stats() {
    print_section "Test Map Statistics"

    local maps_dir="${DIR}/assets"
    local map_count=0

    if [[ -d "$maps_dir" ]]; then
        map_count=$(find "$maps_dir" -name "*.w3x" 2>/dev/null | wc -l)
        echo "Found $map_count .w3x map files in assets/"
        echo ""

        if [[ "$map_count" -gt 0 ]]; then
            echo "Available test maps:"
            find "$maps_dir" -name "*.w3x" -printf "  - %f\n" 2>/dev/null | head -10
            if [[ "$map_count" -gt 10 ]]; then
                echo "  ... and $((map_count - 10)) more"
            fi
        fi
    else
        echo -e "${YELLOW}Warning: assets/ directory not found${NC}"
    fi
}
# }}}

# {{{ main
main() {
    local total_tests=0
    local passed_tests=0

    print_banner
    show_map_stats

    # Run MPQ tests
    if run_test "MPQ Archive API (Issue 102)" "${DIR}/src/tests/test_mpq.lua"; then
        passed_tests=$((passed_tests + 1))
    fi
    total_tests=$((total_tests + 1))

    # Run W3I tests
    if run_test "W3I Map Info Parser (Issue 103)" "${DIR}/src/tests/test_w3i.lua"; then
        passed_tests=$((passed_tests + 1))
    fi
    total_tests=$((total_tests + 1))

    # Run WTS tests
    if run_test "WTS Trigger Strings Parser (Issue 104)" "${DIR}/src/tests/test_wts.lua"; then
        passed_tests=$((passed_tests + 1))
    fi
    total_tests=$((total_tests + 1))

    print_summary "$passed_tests" "$total_tests"

    echo "========================================"
    echo "  Phase 1 Demo Complete"
    echo "========================================"
    echo ""

    # Return exit code based on test results
    if [[ "$passed_tests" -eq "$total_tests" ]]; then
        return 0
    else
        return 1
    fi
}
# }}}

main "$@"
