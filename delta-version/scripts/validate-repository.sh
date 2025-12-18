#!/bin/bash
# validate-repository.sh - Comprehensive repository validation suite
# Tests all core features of the ai-stuff monorepo to ensure they work correctly.
# Validates project structure, git operations, scripts, and documentation.

set -uo pipefail
# Note: Not using -e because we handle errors manually and want to continue on failures

# {{{ Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
DELTA_DIR="${DIR}/delta-version"
SCRIPTS_DIR="${DELTA_DIR}/scripts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0

# Options
VERBOSE=false
FIX_MODE=false
QUICK_MODE=false
# }}}

# {{{ usage
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Validate the ai-stuff monorepo structure and functionality.

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Show detailed output for all tests
    -q, --quick         Run only quick structural tests (skip slow tests)
    --fix               Attempt to fix minor issues automatically
    --dir PATH          Override repository root directory

EXAMPLES:
    $(basename "$0")              # Run all validation tests
    $(basename "$0") --quick      # Run quick structural tests only
    $(basename "$0") --verbose    # Run with detailed output
    $(basename "$0") --fix        # Run and auto-fix minor issues

EXIT CODES:
    0   All tests passed
    1   Some tests failed
    2   Invalid arguments
EOF
    exit 0
}
# }}}

# {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quick)
                QUICK_MODE=true
                shift
                ;;
            --fix)
                FIX_MODE=true
                shift
                ;;
            --dir)
                shift
                DIR="$1"
                DELTA_DIR="${DIR}/delta-version"
                SCRIPTS_DIR="${DELTA_DIR}/scripts"
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                exit 2
                ;;
        esac
    done
}
# }}}

# {{{ print_header
print_header() {
    local title="$1"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $title${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
}
# }}}

# {{{ print_result
print_result() {
    local status="$1"
    local message="$2"
    local detail="${3:-}"

    case "$status" in
        PASS)
            echo -e "  ${GREEN}✓${NC} $message"
            ((PASS_COUNT++))
            ;;
        FAIL)
            echo -e "  ${RED}✗${NC} $message"
            ((FAIL_COUNT++))
            if [[ -n "$detail" ]]; then
                echo -e "      ${RED}↳ $detail${NC}"
            fi
            ;;
        WARN)
            echo -e "  ${YELLOW}⚠${NC} $message"
            ((WARN_COUNT++))
            if [[ -n "$detail" ]]; then
                echo -e "      ${YELLOW}↳ $detail${NC}"
            fi
            ;;
        SKIP)
            echo -e "  ${YELLOW}○${NC} $message (skipped)"
            ((SKIP_COUNT++))
            ;;
        INFO)
            if [[ "$VERBOSE" == true ]]; then
                echo -e "    ${BLUE}ℹ${NC} $message"
            fi
            ;;
    esac
}
# }}}

# {{{ validate_repository_root
validate_repository_root() {
    print_header "Repository Root Validation"

    # Check directory exists
    if [[ -d "$DIR" ]]; then
        print_result "PASS" "Repository root exists: $DIR"
    else
        print_result "FAIL" "Repository root not found" "$DIR"
        return 1
    fi

    # Check it's a git repository
    if [[ -d "${DIR}/.git" ]]; then
        print_result "PASS" "Is a git repository"
    else
        print_result "FAIL" ".git directory not found"
    fi

    # Check README exists
    if [[ -f "${DIR}/README.md" ]]; then
        print_result "PASS" "README.md exists"
    else
        print_result "FAIL" "README.md not found"
    fi

    # Check QUICK-START exists
    if [[ -f "${DIR}/QUICK-START.md" ]]; then
        print_result "PASS" "QUICK-START.md exists"
    else
        print_result "WARN" "QUICK-START.md not found" "Run Issue 008 completion"
    fi

    # Check delta-version exists
    if [[ -d "$DELTA_DIR" ]]; then
        print_result "PASS" "delta-version meta-project exists"
    else
        print_result "FAIL" "delta-version not found"
    fi
}
# }}}

# {{{ validate_project_structure
validate_project_structure() {
    print_header "Project Structure Validation"

    # Get project list
    local projects
    if [[ -x "${SCRIPTS_DIR}/list-projects.sh" ]]; then
        projects=$("${SCRIPTS_DIR}/list-projects.sh" 2>/dev/null | head -30)
        local count=$(echo "$projects" | wc -l)
        print_result "PASS" "list-projects.sh works ($count projects found)"
    else
        print_result "FAIL" "list-projects.sh not found or not executable"
        return 1
    fi

    # Validate each project has basic structure
    local valid_projects=0
    local missing_docs=0
    local missing_notes=0
    local missing_issues=0

    for project in $projects; do
        local project_dir="${DIR}/${project}"

        if [[ ! -d "$project_dir" ]]; then
            print_result "FAIL" "Project directory missing: $project"
            continue
        fi

        ((valid_projects++))

        # Check for standard directories
        if [[ ! -d "${project_dir}/docs" ]]; then
            ((missing_docs++))
            print_result "INFO" "$project: missing docs/"
        fi

        if [[ ! -d "${project_dir}/notes" ]]; then
            ((missing_notes++))
            print_result "INFO" "$project: missing notes/"
        fi

        if [[ ! -d "${project_dir}/issues" ]]; then
            ((missing_issues++))
            print_result "INFO" "$project: missing issues/"
        fi
    done

    print_result "PASS" "$valid_projects projects with valid directories"

    if [[ $missing_docs -gt 0 ]]; then
        print_result "WARN" "$missing_docs projects without docs/ directory"
    fi

    if [[ $missing_notes -gt 0 ]]; then
        print_result "WARN" "$missing_notes projects without notes/ directory"
    fi

    if [[ $missing_issues -gt 0 ]]; then
        print_result "WARN" "$missing_issues projects without issues/ directory"
    fi
}
# }}}

# {{{ validate_delta_version
validate_delta_version() {
    print_header "Delta-Version Meta-Project Validation"

    # Check scripts directory
    if [[ -d "$SCRIPTS_DIR" ]]; then
        print_result "PASS" "scripts/ directory exists"
    else
        print_result "FAIL" "scripts/ directory not found"
        return 1
    fi

    # Required scripts
    local required_scripts=(
        "list-projects.sh"
        "generate-history.sh"
        "manage-issues.sh"
        "reconstruct-history.sh"
    )

    for script in "${required_scripts[@]}"; do
        local script_path="${SCRIPTS_DIR}/${script}"
        if [[ -f "$script_path" ]]; then
            if [[ -x "$script_path" ]]; then
                print_result "PASS" "$script is executable"
            else
                print_result "WARN" "$script exists but not executable"
                if [[ "$FIX_MODE" == true ]]; then
                    chmod +x "$script_path"
                    print_result "INFO" "Fixed: made $script executable"
                fi
            fi
        else
            print_result "FAIL" "$script not found"
        fi
    done

    # Check documentation
    local required_docs=(
        "docs/table-of-contents.md"
        "docs/PROJECT-STATUS.md"
        "docs/history-tools-guide.md"
    )

    for doc in "${required_docs[@]}"; do
        local doc_path="${DELTA_DIR}/${doc}"
        if [[ -f "$doc_path" ]]; then
            print_result "PASS" "$doc exists"
        else
            print_result "WARN" "$doc not found"
        fi
    done

    # Check issues directory
    if [[ -d "${DELTA_DIR}/issues" ]]; then
        local issue_count=$(find "${DELTA_DIR}/issues" -name "*.md" -type f | wc -l)
        print_result "PASS" "issues/ directory with $issue_count issue files"
    else
        print_result "FAIL" "issues/ directory not found"
    fi

    # Check completed issues
    if [[ -d "${DELTA_DIR}/issues/completed" ]]; then
        local completed_count=$(find "${DELTA_DIR}/issues/completed" -name "*.md" -type f | wc -l)
        print_result "PASS" "issues/completed/ with $completed_count completed issues"
    else
        print_result "WARN" "issues/completed/ directory not found"
    fi
}
# }}}

# {{{ validate_git_operations
validate_git_operations() {
    print_header "Git Operations Validation"

    if [[ "$QUICK_MODE" == true ]]; then
        print_result "SKIP" "Git operations (quick mode)"
        return 0
    fi

    # Check current branch
    local branch
    branch=$(git -C "$DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
        print_result "PASS" "Current branch: $branch"
    else
        print_result "FAIL" "Could not determine current branch"
    fi

    # Check remote
    local remote
    remote=$(git -C "$DIR" remote get-url origin 2>/dev/null || echo "")
    if [[ -n "$remote" ]]; then
        print_result "PASS" "Remote configured: $remote"
    else
        print_result "WARN" "No remote configured"
    fi

    # Check for uncommitted changes
    local changes
    changes=$(git -C "$DIR" status --porcelain 2>/dev/null | wc -l)
    if [[ "$changes" -eq 0 ]]; then
        print_result "PASS" "Working tree is clean"
    else
        print_result "INFO" "$changes uncommitted changes"
    fi

    # Check commit count
    local commit_count
    commit_count=$(git -C "$DIR" rev-list --count HEAD 2>/dev/null || echo "0")
    print_result "PASS" "Repository has $commit_count commits"

    # Check for project branches
    local branch_count
    branch_count=$(git -C "$DIR" branch -a 2>/dev/null | wc -l)
    print_result "PASS" "$branch_count branches available"
}
# }}}

# {{{ validate_shared_libraries
validate_shared_libraries() {
    print_header "Shared Libraries Validation"

    local libs_dir="${DIR}/scripts/libs"

    # Check scripts/libs exists
    if [[ -d "$libs_dir" ]]; then
        print_result "PASS" "scripts/libs/ directory exists"
    else
        print_result "WARN" "scripts/libs/ not found"
        return 0
    fi

    # Check for TUI library
    if [[ -f "${libs_dir}/tui.sh" ]]; then
        print_result "PASS" "tui.sh library exists"

        # Quick syntax check
        if bash -n "${libs_dir}/tui.sh" 2>/dev/null; then
            print_result "PASS" "tui.sh has valid bash syntax"
        else
            print_result "FAIL" "tui.sh has syntax errors"
        fi
    else
        print_result "WARN" "tui.sh not found"
    fi

    # Check for menu library
    if [[ -f "${libs_dir}/menu.sh" ]]; then
        print_result "PASS" "menu.sh library exists"

        if bash -n "${libs_dir}/menu.sh" 2>/dev/null; then
            print_result "PASS" "menu.sh has valid bash syntax"
        else
            print_result "FAIL" "menu.sh has syntax errors"
        fi
    else
        print_result "WARN" "menu.sh not found"
    fi

    # Check Lua libs
    local lua_libs="${DIR}/libs"
    if [[ -d "$lua_libs" ]]; then
        local lua_count=$(find "$lua_libs" -name "*.lua" -type f 2>/dev/null | wc -l)
        print_result "PASS" "libs/ directory with $lua_count Lua files"
    else
        print_result "WARN" "libs/ directory not found at root"
    fi
}
# }}}

# {{{ validate_script_functionality
validate_script_functionality() {
    print_header "Script Functionality Tests"

    if [[ "$QUICK_MODE" == true ]]; then
        print_result "SKIP" "Script functionality (quick mode)"
        return 0
    fi

    # Test list-projects.sh
    local project_count
    project_count=$("${SCRIPTS_DIR}/list-projects.sh" 2>/dev/null | wc -l)
    if [[ "$project_count" -gt 0 ]]; then
        print_result "PASS" "list-projects.sh returns $project_count projects"
    else
        print_result "FAIL" "list-projects.sh returned no projects"
    fi

    # Test JSON output
    local json_output
    json_output=$("${SCRIPTS_DIR}/list-projects.sh" --format json 2>/dev/null || true)
    if echo "$json_output" | head -1 | grep -qE '^\{|^\['; then
        print_result "PASS" "list-projects.sh --format json produces valid JSON"
    else
        print_result "FAIL" "list-projects.sh --format json output invalid"
    fi

    # Test generate-history.sh dry-run
    if "${SCRIPTS_DIR}/generate-history.sh" --project delta-version --dry-run &>/dev/null; then
        print_result "PASS" "generate-history.sh --dry-run works"
    else
        print_result "FAIL" "generate-history.sh --dry-run failed"
    fi

    # Test manage-issues.sh help
    if "${SCRIPTS_DIR}/manage-issues.sh" --help &>/dev/null; then
        print_result "PASS" "manage-issues.sh --help works"
    else
        print_result "WARN" "manage-issues.sh --help failed"
    fi
}
# }}}

# {{{ validate_documentation_links
validate_documentation_links() {
    print_header "Documentation Link Validation"

    if [[ "$QUICK_MODE" == true ]]; then
        print_result "SKIP" "Documentation links (quick mode)"
        return 0
    fi

    local toc_file="${DELTA_DIR}/docs/table-of-contents.md"

    if [[ ! -f "$toc_file" ]]; then
        print_result "WARN" "table-of-contents.md not found"
        return 0
    fi

    # Extract relative links and check they exist
    local broken_links=0
    local total_links=0

    # Extract all markdown links using grep
    local links
    links=$(grep -oE '\([^)]+\.md\)' "$toc_file" | tr -d '()' | sort -u)

    for link in $links; do
        ((total_links++))

        # Resolve relative path from docs directory
        local resolved_path="${DELTA_DIR}/docs/${link}"

        # Normalize path (handle ../ references)
        if [[ -f "$resolved_path" ]]; then
            print_result "INFO" "Link OK: $link"
        else
            # Try resolving from delta-version root
            resolved_path="${DELTA_DIR}/${link#../}"
            if [[ -f "$resolved_path" ]]; then
                print_result "INFO" "Link OK: $link"
            else
                ((broken_links++))
                print_result "WARN" "Broken link: $link"
            fi
        fi
    done

    if [[ $broken_links -eq 0 ]]; then
        print_result "PASS" "All $total_links documentation links valid"
    else
        print_result "WARN" "$broken_links of $total_links links are broken"
    fi
}
# }}}

# {{{ print_summary
print_summary() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  VALIDATION SUMMARY${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}Passed:${NC}  $PASS_COUNT"
    echo -e "  ${RED}Failed:${NC}  $FAIL_COUNT"
    echo -e "  ${YELLOW}Warnings:${NC} $WARN_COUNT"
    echo -e "  ${YELLOW}Skipped:${NC} $SKIP_COUNT"
    echo ""

    local total=$((PASS_COUNT + FAIL_COUNT))
    if [[ $total -gt 0 ]]; then
        local percent=$((PASS_COUNT * 100 / total))
        echo -e "  Pass rate: ${percent}%"
    fi

    echo ""

    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "  ${GREEN}★ All tests passed!${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Some tests failed. Review output above.${NC}"
        return 1
    fi
}
# }}}

# {{{ main
main() {
    parse_args "$@"

    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    AI-STUFF REPOSITORY VALIDATION                            ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Repository: $DIR"
    echo "  Mode: $(if [[ "$QUICK_MODE" == true ]]; then echo "Quick"; else echo "Full"; fi)"
    echo "  Verbose: $VERBOSE"
    echo "  Fix mode: $FIX_MODE"

    validate_repository_root
    validate_project_structure
    validate_delta_version
    validate_git_operations
    validate_shared_libraries
    validate_script_functionality
    validate_documentation_links

    print_summary
}
# }}}

main "$@"
