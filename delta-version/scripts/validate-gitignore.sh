#!/usr/bin/env bash
# validate-gitignore.sh - Comprehensive gitignore validation and testing
#
# Validates the unified .gitignore file to ensure:
# - Syntax is correct (valid gitignore patterns)
# - Critical source files are NOT ignored
# - Build artifacts and IDE files ARE ignored
# - Patterns work correctly with actual project structures
#
# Usage: ./validate-gitignore.sh [OPTIONS] [gitignore-file]

set -euo pipefail

# -- {{{ Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default gitignore location
GITIGNORE_FILE="${DIR}/.gitignore"
TEST_DIR=""
VERBOSE=false
INTERACTIVE=false
DRY_RUN=false
REPORT_FILE=""
QUICK_MODE=false

# Test results
SYNTAX_PASSED=false
CRITICAL_PASSED=false
FUNCTIONAL_PASSED=false
PROJECT_PASSED=false

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0
# }}}

# -- {{{ Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
# }}}

# -- {{{ log
log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[INFO] $*" >&2
    fi
}
# }}}

# -- {{{ error
error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}
# }}}

# -- {{{ warn
warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
    ((WARNINGS++))
}
# }}}

# -- {{{ pass
pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
}
# }}}

# -- {{{ fail
fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
}
# }}}

# -- {{{ section
section() {
    echo ""
    echo -e "${BLUE}=== $* ===${NC}"
    echo ""
}
# }}}

# =============================================================================
# Critical Files Protection
# =============================================================================

# Files/patterns that should NEVER be ignored
PROTECTED_PATTERNS=(
    # Source code
    "*.c"
    "*.h"
    "*.lua"
    "*.rs"
    "*.go"
    "*.py"
    "*.js"
    "*.ts"
    "*.sh"

    # Documentation
    "*.md"
    "README*"
    "LICENSE*"
    "CHANGELOG*"

    # Build configuration
    "Makefile"
    "CMakeLists.txt"
    "Cargo.toml"
    "package.json"
    "go.mod"

    # Important directories (check they're not blanket ignored)
    "src/"
    "docs/"
    "include/"
    "lib/"
    "tests/"
)

# Patterns that SHOULD be ignored (for functional testing)
SHOULD_IGNORE_PATTERNS=(
    # Build artifacts
    "*.o"
    "*.exe"
    "*.dll"
    "*.so"
    "build/"
    "target/"

    # IDE files
    ".vscode/"
    ".idea/"
    "*.swp"

    # Dependencies
    "node_modules/"
    "__pycache__/"

    # Security
    "*.key"
    "*.pem"
    ".env"
)

# -- {{{ validate_gitignore_syntax
validate_gitignore_syntax() {
    local gitignore_file="$1"

    section "Syntax Validation"

    if [[ ! -f "$gitignore_file" ]]; then
        fail "Gitignore file not found: $gitignore_file"
        return 1
    fi

    local line_num=0
    local syntax_errors=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))

        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Check for invalid characters
        if [[ "$line" =~ [[:cntrl:]] ]]; then
            fail "Line $line_num: Contains control characters: $line"
            ((syntax_errors++))
            continue
        fi

        # Check for patterns starting with space (usually a mistake)
        if [[ "$line" =~ ^[[:space:]] ]] && [[ ! "$line" =~ ^\\ ]]; then
            warn "Line $line_num: Pattern starts with whitespace (might be unintentional): '$line'"
        fi

        # Check for double slashes (invalid)
        if [[ "$line" =~ // ]]; then
            warn "Line $line_num: Contains double slashes: $line"
        fi

        # Check for trailing spaces (might affect matching)
        if [[ "$line" =~ [[:space:]]$ ]] && [[ ! "$line" =~ \\[[:space:]]$ ]]; then
            warn "Line $line_num: Trailing whitespace: '$line'"
        fi

        log "Line $line_num OK: $line"
    done < "$gitignore_file"

    # Count total patterns
    local pattern_count
    pattern_count=$(grep -v '^#' "$gitignore_file" | grep -v '^$' | wc -l)

    if [[ $syntax_errors -eq 0 ]]; then
        pass "Syntax validation passed ($pattern_count patterns)"
        SYNTAX_PASSED=true
        return 0
    else
        fail "Syntax validation found $syntax_errors errors"
        return 1
    fi
}
# }}}

# -- {{{ check_critical_files
check_critical_files() {
    local gitignore_file="$1"

    section "Critical File Protection"

    # Create a temporary git repo to test ignore behavior
    TEST_DIR=$(mktemp -d)
    trap "rm -rf $TEST_DIR" EXIT

    cd "$TEST_DIR"
    git init -q
    cp "$gitignore_file" .gitignore

    local critical_failures=0

    echo "Testing that critical file types are NOT ignored:"
    echo ""

    for pattern in "${PROTECTED_PATTERNS[@]}"; do
        # Create test file matching the pattern
        local test_file

        case "$pattern" in
            "*."*)
                # Extension pattern - create file with that extension
                local ext="${pattern#*.}"
                test_file="test_file.$ext"
                ;;
            */)
                # Directory pattern - create directory with file inside
                local dir_name="${pattern%/}"
                mkdir -p "$dir_name"
                test_file="$dir_name/test_file.txt"
                ;;
            *)
                # Literal filename
                test_file="$pattern"
                ;;
        esac

        # Create the test file
        mkdir -p "$(dirname "$test_file")" 2>/dev/null || true
        echo "test content" > "$test_file"

        # Check if git would ignore it
        if git check-ignore -q "$test_file" 2>/dev/null; then
            fail "CRITICAL: '$pattern' would be ignored! ($test_file)"
            ((critical_failures++))
        else
            pass "Protected: $pattern"
        fi

        rm -f "$test_file"
        rmdir "$(dirname "$test_file")" 2>/dev/null || true
    done

    cd - > /dev/null

    if [[ $critical_failures -eq 0 ]]; then
        CRITICAL_PASSED=true
        echo ""
        echo -e "${GREEN}All critical files are protected${NC}"
        return 0
    else
        echo ""
        error "$critical_failures critical file types would be ignored!"
        return 1
    fi
}
# }}}

# -- {{{ test_pattern_functionality
test_pattern_functionality() {
    local gitignore_file="$1"

    section "Functional Testing"

    # Use existing test dir or create new one
    if [[ -z "$TEST_DIR" ]] || [[ ! -d "$TEST_DIR" ]]; then
        TEST_DIR=$(mktemp -d)
        trap "rm -rf $TEST_DIR" EXIT
    fi

    cd "$TEST_DIR"

    # Reinitialize if needed
    if [[ ! -d ".git" ]]; then
        git init -q
    fi

    cp "$gitignore_file" .gitignore

    local functional_failures=0

    echo "Testing that build artifacts and IDE files ARE ignored:"
    echo ""

    for pattern in "${SHOULD_IGNORE_PATTERNS[@]}"; do
        local test_file

        case "$pattern" in
            "*."*)
                local ext="${pattern#*.}"
                test_file="artifact.$ext"
                ;;
            */)
                local dir_name="${pattern%/}"
                mkdir -p "$dir_name"
                test_file="$dir_name/file.txt"
                ;;
            "."*)
                # Hidden file/dir pattern
                if [[ "$pattern" == */ ]]; then
                    mkdir -p "${pattern%/}"
                    test_file="${pattern%/}/file.txt"
                else
                    test_file="$pattern"
                fi
                ;;
            *)
                test_file="$pattern"
                ;;
        esac

        # Create test file
        mkdir -p "$(dirname "$test_file")" 2>/dev/null || true
        echo "test" > "$test_file"

        # Check if git DOES ignore it
        if git check-ignore -q "$test_file" 2>/dev/null; then
            pass "Ignored: $pattern"
        else
            fail "NOT ignored (should be): $pattern ($test_file)"
            ((functional_failures++))
        fi

        rm -rf "$test_file"
        # Clean up directories
        local dir
        dir=$(dirname "$test_file")
        while [[ "$dir" != "." ]] && [[ -d "$dir" ]]; do
            rmdir "$dir" 2>/dev/null || break
            dir=$(dirname "$dir")
        done
    done

    cd - > /dev/null

    if [[ $functional_failures -eq 0 ]]; then
        FUNCTIONAL_PASSED=true
        echo ""
        echo -e "${GREEN}All expected patterns are working${NC}"
        return 0
    else
        echo ""
        warn "$functional_failures patterns not working as expected"
        return 1
    fi
}
# }}}

# -- {{{ test_project_compatibility
test_project_compatibility() {
    local gitignore_file="$1"

    section "Project Compatibility"

    local projects_script="${DIR}/delta-version/scripts/list-projects.sh"

    if [[ ! -x "$projects_script" ]]; then
        warn "Project listing script not found, skipping project compatibility tests"
        PROJECT_PASSED=true
        return 0
    fi

    echo "Testing gitignore against actual projects..."
    echo ""

    local project_failures=0
    local projects_tested=0

    # Get list of projects
    local -a projects
    mapfile -t projects < <("$projects_script" --paths 2>/dev/null | head -10)

    for project_dir in "${projects[@]}"; do
        [[ ! -d "$project_dir" ]] && continue

        local project_name
        project_name=$(basename "$project_dir")

        ((projects_tested++))

        # Check if any source files in src/ would be ignored
        local src_dir="${project_dir}/src"
        if [[ -d "$src_dir" ]]; then
            local ignored_sources
            ignored_sources=$(find "$src_dir" -type f \( -name "*.lua" -o -name "*.c" -o -name "*.rs" -o -name "*.py" \) 2>/dev/null | while read -r f; do
                # Use the repo's gitignore to check
                cd "$DIR"
                if git check-ignore -q "$f" 2>/dev/null; then
                    echo "$f"
                fi
            done)

            if [[ -n "$ignored_sources" ]]; then
                fail "$project_name: Source files would be ignored!"
                echo "$ignored_sources" | head -3 | sed 's/^/        /'
                ((project_failures++))
            else
                pass "$project_name: Source files protected"
            fi
        else
            log "$project_name: No src/ directory"
            pass "$project_name: No src/ to check"
        fi
    done

    if [[ $projects_tested -eq 0 ]]; then
        warn "No projects tested"
        PROJECT_PASSED=true
        return 0
    fi

    if [[ $project_failures -eq 0 ]]; then
        PROJECT_PASSED=true
        echo ""
        echo -e "${GREEN}All $projects_tested projects compatible${NC}"
        return 0
    else
        echo ""
        error "$project_failures projects have compatibility issues"
        return 1
    fi
}
# }}}

# -- {{{ assess_performance
assess_performance() {
    local gitignore_file="$1"

    section "Performance Assessment"

    cd "$DIR"

    echo "Measuring git status performance..."
    echo ""

    # Count patterns
    local pattern_count
    pattern_count=$(grep -v '^#' "$gitignore_file" | grep -v '^$' | wc -l)
    echo "Pattern count: $pattern_count"

    # Measure git status time
    local start_time end_time duration
    start_time=$(date +%s%N)
    git status --porcelain > /dev/null 2>&1
    end_time=$(date +%s%N)

    duration=$(( (end_time - start_time) / 1000000 ))
    echo "git status time: ${duration}ms"

    if [[ $duration -lt 1000 ]]; then
        pass "Performance acceptable (< 1 second)"
    elif [[ $duration -lt 5000 ]]; then
        warn "Performance moderate (${duration}ms)"
    else
        fail "Performance slow (${duration}ms)"
    fi

    # Count tracked files for context
    local file_count
    file_count=$(git ls-files 2>/dev/null | wc -l)
    echo "Tracked files: $file_count"

    cd - > /dev/null
}
# }}}

# -- {{{ generate_validation_report
generate_validation_report() {
    local gitignore_file="$1"
    local output_file="${2:-${DIR}/delta-version/assets/gitignore-validation-report.txt}"

    mkdir -p "$(dirname "$output_file")"

    cat > "$output_file" <<EOF
================================================================================
GITIGNORE VALIDATION REPORT
================================================================================

File:        $gitignore_file
Test Date:   $(date)
Generator:   validate-gitignore.sh

================================================================================
SUMMARY
================================================================================

Syntax Validation:      $(if $SYNTAX_PASSED; then echo "PASSED"; else echo "FAILED"; fi)
Critical File Safety:   $(if $CRITICAL_PASSED; then echo "PASSED"; else echo "FAILED"; fi)
Functional Testing:     $(if $FUNCTIONAL_PASSED; then echo "PASSED"; else echo "FAILED"; fi)
Project Compatibility:  $(if $PROJECT_PASSED; then echo "PASSED"; else echo "FAILED"; fi)

Total Tests:   $TOTAL_TESTS
Passed:        $PASSED_TESTS
Failed:        $FAILED_TESTS
Warnings:      $WARNINGS

================================================================================
PATTERN STATISTICS
================================================================================

$(grep -v '^#' "$gitignore_file" | grep -v '^$' | wc -l) total patterns

By category:
  Security:     $(grep -c '\.key\|\.pem\|\.env\|secret' "$gitignore_file" 2>/dev/null || echo "0")
  Build:        $(grep -c '\.o$\|\.exe\|build\|target' "$gitignore_file" 2>/dev/null || echo "0")
  IDE:          $(grep -c 'vscode\|idea\|sublime\|\.swp' "$gitignore_file" 2>/dev/null || echo "0")
  Dependencies: $(grep -c 'node_modules\|vendor\|__pycache__' "$gitignore_file" 2>/dev/null || echo "0")

================================================================================
PROTECTED FILE TYPES
================================================================================

The following file types are confirmed PROTECTED (not ignored):
$(printf '  %s\n' "${PROTECTED_PATTERNS[@]}")

================================================================================
IGNORED PATTERNS (verified working)
================================================================================

The following patterns are confirmed WORKING (files are ignored):
$(printf '  %s\n' "${SHOULD_IGNORE_PATTERNS[@]}")

================================================================================
END OF REPORT
================================================================================
EOF

    echo ""
    echo "Report saved to: $output_file"
}
# }}}

# -- {{{ run_full_test_suite
run_full_test_suite() {
    local gitignore_file="$1"

    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║           GITIGNORE VALIDATION TEST SUITE                          ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Testing: $gitignore_file"
    echo ""

    # Run all tests
    validate_gitignore_syntax "$gitignore_file" || true
    check_critical_files "$gitignore_file" || true
    test_pattern_functionality "$gitignore_file" || true

    if [[ "$QUICK_MODE" != true ]]; then
        test_project_compatibility "$gitignore_file" || true
        assess_performance "$gitignore_file" || true
    fi

    # Summary
    section "Test Summary"

    echo "Results:"
    echo "  Total tests:  $TOTAL_TESTS"
    echo "  Passed:       $PASSED_TESTS"
    echo "  Failed:       $FAILED_TESTS"
    echo "  Warnings:     $WARNINGS"
    echo ""

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}✓ All validation tests passed!${NC}"

        # Generate report if requested
        if [[ -n "$REPORT_FILE" ]]; then
            generate_validation_report "$gitignore_file" "$REPORT_FILE"
        fi

        return 0
    else
        echo -e "${RED}✗ $FAILED_TESTS test(s) failed${NC}"
        return 1
    fi
}
# }}}

# -- {{{ interactive_validation
interactive_validation() {
    local gitignore_file="$1"

    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║           INTERACTIVE GITIGNORE VALIDATION                         ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "File: $gitignore_file"
    echo ""
    echo "Select validation option:"
    echo ""
    echo "  1) Run syntax validation only"
    echo "  2) Check critical file protection"
    echo "  3) Run functional tests"
    echo "  4) Test project compatibility"
    echo "  5) Assess performance"
    echo "  6) Run FULL test suite"
    echo "  7) Generate detailed report"
    echo "  q) Quit"
    echo ""

    while true; do
        read -rp "Select option [1-7, q]: " choice

        case "$choice" in
            1)
                validate_gitignore_syntax "$gitignore_file"
                ;;
            2)
                check_critical_files "$gitignore_file"
                ;;
            3)
                test_pattern_functionality "$gitignore_file"
                ;;
            4)
                test_project_compatibility "$gitignore_file"
                ;;
            5)
                assess_performance "$gitignore_file"
                ;;
            6)
                run_full_test_suite "$gitignore_file"
                ;;
            7)
                REPORT_FILE="${DIR}/delta-version/assets/gitignore-validation-report.txt"
                run_full_test_suite "$gitignore_file"
                generate_validation_report "$gitignore_file" "$REPORT_FILE"
                ;;
            q|Q)
                echo "Exiting..."
                return 0
                ;;
            *)
                echo "Invalid option. Please select 1-7 or q."
                ;;
        esac

        echo ""
        echo "Press Enter to continue..."
        read -r
        echo ""
    done
}
# }}}

# -- {{{ show_help
show_help() {
    cat <<'EOF'
Usage: validate-gitignore.sh [OPTIONS] [gitignore-file]

Comprehensive validation and testing for .gitignore files.

Options:
    -f, --file FILE      Gitignore file to validate (default: $DIR/.gitignore)
    -I, --interactive    Interactive mode with menu
    -q, --quick          Quick mode (skip project compatibility and performance)
    -r, --report FILE    Generate detailed report to FILE
    -v, --verbose        Verbose output
    -n, --dry-run        Show what would be tested without running
    -h, --help           Show this help message

Test Categories:
    Syntax Validation    - Check for invalid patterns and formatting issues
    Critical Files       - Ensure source code and docs are NOT ignored
    Functional Tests     - Verify build artifacts and IDE files ARE ignored
    Project Compat       - Test against actual project file structures
    Performance          - Measure impact on git operations

Examples:
    # Run full test suite on default gitignore
    validate-gitignore.sh

    # Quick validation (skip slow tests)
    validate-gitignore.sh --quick

    # Validate specific file with report
    validate-gitignore.sh --report report.txt /path/to/.gitignore

    # Interactive mode
    validate-gitignore.sh -I

EOF
}
# }}}

# -- {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                GITIGNORE_FILE="$2"
                shift 2
                ;;
            -I|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -q|--quick)
                QUICK_MODE=true
                shift
                ;;
            -r|--report)
                REPORT_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                GITIGNORE_FILE="$1"
                shift
                ;;
        esac
    done
}
# }}}

# -- {{{ main
main() {
    parse_args "$@"

    # Validate gitignore file exists
    if [[ ! -f "$GITIGNORE_FILE" ]]; then
        error "Gitignore file not found: $GITIGNORE_FILE"
        exit 1
    fi

    # Convert to absolute path
    GITIGNORE_FILE=$(realpath "$GITIGNORE_FILE")

    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY RUN - Would validate: $GITIGNORE_FILE"
        echo ""
        echo "Tests that would run:"
        echo "  - Syntax validation"
        echo "  - Critical file protection check"
        echo "  - Functional pattern testing"
        if [[ "$QUICK_MODE" != true ]]; then
            echo "  - Project compatibility testing"
            echo "  - Performance assessment"
        fi
        exit 0
    fi

    if [[ "$INTERACTIVE" == true ]]; then
        interactive_validation "$GITIGNORE_FILE"
    else
        run_full_test_suite "$GITIGNORE_FILE"
    fi
}
# }}}

main "$@"
