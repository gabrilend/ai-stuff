#!/bin/bash
# check-utilities.sh - Project Integration Checker and Auto-Remediation System
#
# This script audits delta-version utilities and scans all monorepo projects
# for integration opportunities. It detects missing metadata, broken symlinks,
# and provides interactive remediation (auto-fix or create issue files).
#
# General approach: Registry-based checking with pluggable check functions,
# interactive prompting for remediation, and comprehensive reporting.

# Set DIR to script's parent directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Color codes for output
# -- {{{ COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'
# }}}

# Global counters
# -- {{{ COUNTERS
ISSUES_FOUND=0
ISSUES_FIXED=0
ISSUES_CREATED=0
ISSUES_SKIPPED=0
# }}}

# Mode flags
# -- {{{ MODE_FLAGS
INTERACTIVE=true
QUIET=false
FIX_ALL=false
CREATE_ALL=false
DRY_RUN=false
CHECK_UTILITIES=false
CHECK_DEPENDENCIES=false
CHECK_STRUCTURE=false
CHECK_METADATA=false
CHECK_SYMLINKS=false
CHECK_TUI_AUDIT=false
CHECK_TRANSCRIPTS=false
CHECK_ISSUE_STANDARDS=false
ALL_PROJECTS=false
SPECIFIC_PROJECTS=()
# }}}

# -- {{{ show_help
show_help() {
    cat <<EOF
${BOLD}USAGE:${NC}
    check-utilities.sh [OPTIONS] [PROJECT...]

${BOLD}DESCRIPTION:${NC}
    Audits delta-version utilities and scans monorepo projects for
    integration opportunities. Provides interactive remediation for
    detected issues.

${BOLD}MODES:${NC}
    (default)              Check delta-version utilities only
    --all-projects         Check all discovered projects
    --project NAME         Check specific project(s)

${BOLD}DELTA-VERSION CHECKS:${NC}
    --utilities            Check delta-version script health
    --dependencies         Check external dependencies (jq, git, etc.)
    --structure            Check directory structure

${BOLD}PROJECT INTEGRATION CHECKS:${NC}
    --metadata             Check for project.meta.json
    --symlinks             Check for shared utility symlinks
    --tui-audit            Find TUI scripts not using menu library
    --transcripts          Check LLM transcript registration
    --issue-standards      Check issue file format compliance

${BOLD}ACTIONS:${NC}
    -i, --interactive      Prompt for each issue (default)
    -q, --quiet            Report only, no prompts
    --fix-all              Auto-fix everything possible
    --create-issues        Create issues for all problems
    --dry-run              Show what would be done
    -h, --help             Show this help

${BOLD}EXAMPLES:${NC}
    check-utilities.sh
        Check delta-version utilities only

    check-utilities.sh --all-projects --metadata
        Check all projects for project.meta.json

    check-utilities.sh --project world-edit-to-execute --tui-audit
        Audit TUI scripts in specific project

    check-utilities.sh --all-projects --fix-all --symlinks
        Auto-fix all symlink issues in all projects

    check-utilities.sh --utilities --dependencies --structure
        Complete delta-version health check
EOF
}
# }}}

# -- {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                INTERACTIVE=false
                shift
                ;;
            --fix-all)
                FIX_ALL=true
                shift
                ;;
            --create-issues)
                CREATE_ALL=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --utilities)
                CHECK_UTILITIES=true
                shift
                ;;
            --dependencies)
                CHECK_DEPENDENCIES=true
                shift
                ;;
            --structure)
                CHECK_STRUCTURE=true
                shift
                ;;
            --metadata)
                CHECK_METADATA=true
                shift
                ;;
            --symlinks)
                CHECK_SYMLINKS=true
                shift
                ;;
            --tui-audit)
                CHECK_TUI_AUDIT=true
                shift
                ;;
            --transcripts)
                CHECK_TRANSCRIPTS=true
                shift
                ;;
            --issue-standards)
                CHECK_ISSUE_STANDARDS=true
                shift
                ;;
            --all-projects)
                ALL_PROJECTS=true
                shift
                ;;
            --project)
                if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    echo -e "${RED}Error: --project requires a project name${NC}" >&2
                    exit 1
                fi
                SPECIFIC_PROJECTS+=("$2")
                shift 2
                ;;
            *)
                # Treat as project name
                SPECIFIC_PROJECTS+=("$1")
                shift
                ;;
        esac
    done

    # Default to utilities check if no checks specified
    if ! $CHECK_UTILITIES && ! $CHECK_DEPENDENCIES && ! $CHECK_STRUCTURE && \
       ! $CHECK_METADATA && ! $CHECK_SYMLINKS && ! $CHECK_TUI_AUDIT && \
       ! $CHECK_TRANSCRIPTS && ! $CHECK_ISSUE_STANDARDS; then
        CHECK_UTILITIES=true
        CHECK_DEPENDENCIES=true
        CHECK_STRUCTURE=true
    fi
}
# }}}

# Utility registry
# -- {{{ UTILITY_REGISTRY
# Format: name|path|type|description
declare -a UTILITY_REGISTRY=(
    "list-projects|scripts/list-projects.sh|required|Project discovery utility"
    "validate-repository|scripts/validate-repository.sh|required|Repository validation"
    "manage-metadata|scripts/manage-metadata.sh|required|Metadata management"
    "manage-issues|scripts/manage-issues.sh|required|Issue tracking utility"
    "reconstruct-history|scripts/reconstruct-history.sh|optional|History reconstruction"
    "generate-history|scripts/generate-history.sh|optional|History narrative generation"
    "visualize-deps|scripts/visualize-deps.sh|optional|Dependency visualization"
    "analyze-gitignore|scripts/analyze-gitignore.sh|optional|Gitignore analysis"
    "generate-unified-gitignore|scripts/generate-unified-gitignore.sh|optional|Gitignore generation"
    "maintain-gitignore|scripts/maintain-gitignore.sh|optional|Gitignore maintenance"
    "validate-gitignore|scripts/validate-gitignore.sh|optional|Gitignore validation"
    "import-project-histories|scripts/import-project-histories.sh|optional|Project history import"
    "history-viewer|scripts/history-viewer.sh|optional|TUI history viewer"
    "build-storyline-library|scripts/build-storyline-library.sh|optional|Chronological transcript shelf builder"
    "test-storyline-library|scripts/test-storyline-library.sh|optional|Storyline shelf test suite"
)
# }}}

# External dependencies
# -- {{{ DEPENDENCY_REGISTRY
# Format: command|required_by|check_command
declare -a DEPENDENCY_REGISTRY=(
    "bash|All scripts|bash --version"
    "git|Repository operations|git --version"
    "jq|JSON processing|jq --version"
    "find|File discovery|find --version"
    "stat|File metadata|stat --version"
)
# }}}

# Required directories
# -- {{{ REQUIRED_DIRS
declare -a REQUIRED_DIRS=(
    "scripts"
    "docs"
    "issues"
    "issues/completed"
    "issues/completed/demos"
)
# }}}

# Optional directories
# -- {{{ OPTIONAL_DIRS
declare -a OPTIONAL_DIRS=(
    "libs"
    "assets"
    "notes"
    "src"
    "config"
)
# }}}

# Check functions
# -- {{{ check_script_exists
check_script_exists() {
    local script_path="$1"
    [[ -f "$script_path" ]]
}
# }}}

# -- {{{ check_script_executable
check_script_executable() {
    local script_path="$1"
    [[ -x "$script_path" ]]
}
# }}}

# -- {{{ check_script_syntax
check_script_syntax() {
    local script_path="$1"
    if [[ "$script_path" == *.sh ]]; then
        bash -n "$script_path" 2>/dev/null
    elif [[ "$script_path" == *.lua ]]; then
        # Lua syntax check if luac available
        if command -v luac &>/dev/null; then
            luac -p "$script_path" 2>/dev/null
        else
            return 0  # Skip if luac not available
        fi
    else
        return 0  # Unknown type, skip
    fi
}
# }}}

# -- {{{ check_script_shebang
check_script_shebang() {
    local script_path="$1"
    local first_line
    first_line=$(head -1 "$script_path" 2>/dev/null)

    if [[ "$script_path" == *.sh ]]; then
        echo "$first_line" | grep -qE '^#!/(bin/(ba)?sh|usr/bin/env (ba)?sh)'
    elif [[ "$script_path" == *.lua ]]; then
        echo "$first_line" | grep -qE '^#!/usr/bin/(env )?lua'
    else
        return 0  # Unknown type, skip
    fi
}
# }}}

# -- {{{ check_external_dependency
check_external_dependency() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null
}
# }}}

# -- {{{ check_directory_exists
check_directory_exists() {
    local dir_path="$1"
    [[ -d "$dir_path" ]]
}
# }}}

# Remediation functions
# -- {{{ fix_executable_permission
fix_executable_permission() {
    local script_path="$1"

    if $DRY_RUN; then
        echo -e "${CYAN}[DRY RUN]${NC} Would make $script_path executable"
        return 0
    fi

    chmod +x "$script_path"
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Fixed:${NC} Made $script_path executable"
        ((ISSUES_FIXED++))
        return 0
    else
        echo -e "${RED}✗ Failed:${NC} Could not make $script_path executable"
        return 1
    fi
}
# }}}

# -- {{{ fix_missing_directory
fix_missing_directory() {
    local dir_path="$1"

    if $DRY_RUN; then
        echo -e "${CYAN}[DRY RUN]${NC} Would create directory $dir_path"
        return 0
    fi

    mkdir -p "$dir_path"
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Fixed:${NC} Created directory $dir_path"
        ((ISSUES_FIXED++))
        return 0
    else
        echo -e "${RED}✗ Failed:${NC} Could not create directory $dir_path"
        return 1
    fi
}
# }}}

# -- {{{ get_next_issue_id
get_next_issue_id() {
    local project_dir="$1"
    local issues_dir="${project_dir}/issues"

    # Find highest issue number
    local max_id=0
    if [[ -d "$issues_dir" ]]; then
        for issue_file in "$issues_dir"/*.md; do
            [[ -f "$issue_file" ]] || continue
            local basename=$(basename "$issue_file")
            # Extract number from patterns like "042-name.md" or "042a-name.md"
            if [[ $basename =~ ^([0-9]+) ]]; then
                local num="${BASH_REMATCH[1]}"
                if (( num > max_id )); then
                    max_id=$num
                fi
            fi
        done
    fi

    # Return next ID with zero-padding
    printf "%03d" $((max_id + 1))
}
# }}}

# -- {{{ create_issue_for_problem
create_issue_for_problem() {
    local problem_type="$1"
    local affected_item="$2"
    local description="$3"
    local project_dir="$4"

    if $DRY_RUN; then
        echo -e "${CYAN}[DRY RUN]${NC} Would create issue for $problem_type in $project_dir"
        return 0
    fi

    # Ensure issues directory exists
    mkdir -p "${project_dir}/issues"

    local issue_id
    issue_id=$(get_next_issue_id "$project_dir")

    # Sanitize problem_type for filename
    local sanitized_type=$(echo "$problem_type" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
    local issue_file="${project_dir}/issues/${issue_id}-fix-${sanitized_type}.md"

    cat > "$issue_file" <<EOF
# Issue ${issue_id}: Fix ${problem_type}

## Current Behavior

${description}

Affected: \`${affected_item}\`

## Intended Behavior

The ${problem_type} should be resolved so the utility functions correctly.

## Suggested Implementation Steps

1. Investigate the root cause
2. Implement the fix
3. Test the utility
4. Update this issue with completion notes

## Metadata

- **Priority**: Medium
- **Created**: $(date +%Y-%m-%d)
- **Created By**: check-utilities.sh (auto-generated)
EOF

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Created issue:${NC} $issue_file"
        ((ISSUES_CREATED++))
        return 0
    else
        echo -e "${RED}✗ Failed:${NC} Could not create issue file"
        return 1
    fi
}
# }}}

# Interactive prompting
# -- {{{ prompt_for_action
prompt_for_action() {
    local problem="$1"
    local can_auto_fix="$2"
    local fix_function="$3"
    shift 3
    local fix_args=("$@")

    # Non-interactive modes
    if $FIX_ALL && [[ "$can_auto_fix" == "true" ]]; then
        $fix_function "${fix_args[@]}"
        return $?
    fi

    if $CREATE_ALL; then
        # Extract project_dir (last argument) for issue creation
        local project_dir="${DIR}"
        create_issue_for_problem "$problem" "${fix_args[0]}" "$problem" "$project_dir"
        return $?
    fi

    if ! $INTERACTIVE; then
        ((ISSUES_SKIPPED++))
        return 0
    fi

    # Interactive prompt
    echo
    echo -e "${YELLOW}Problem detected:${NC} $problem"
    echo

    if [[ "$can_auto_fix" == "true" ]]; then
        echo "  1) Fix automatically"
        echo "  2) Create issue file"
        echo "  3) Skip"
        echo -n "  Choice [1/2/3]: "
    else
        echo "  1) Create issue file"
        echo "  2) Skip"
        echo -n "  Choice [1/2]: "
    fi

    read -r choice

    case "$choice" in
        1)
            if [[ "$can_auto_fix" == "true" ]]; then
                $fix_function "${fix_args[@]}"
            else
                local project_dir="${DIR}"
                create_issue_for_problem "$problem" "${fix_args[0]}" "$problem" "$project_dir"
            fi
            ;;
        2)
            if [[ "$can_auto_fix" == "true" ]]; then
                local project_dir="${DIR}"
                create_issue_for_problem "$problem" "${fix_args[0]}" "$problem" "$project_dir"
            else
                ((ISSUES_SKIPPED++))
            fi
            ;;
        *)
            ((ISSUES_SKIPPED++))
            ;;
    esac
}
# }}}

# Handler functions
# -- {{{ handle_missing_script
handle_missing_script() {
    local name="$1"
    local path="$2"
    local type="$3"

    local severity
    if [[ "$type" == "required" ]]; then
        severity="${RED}CRITICAL${NC}"
    else
        severity="${YELLOW}NOTICE${NC}"
    fi

    if ! $QUIET; then
        echo -e "  [${severity}] ${name}: Script not found at ${path}"
    fi

    prompt_for_action \
        "missing-script-${name}" \
        "false" \
        "" \
        "$path"
}
# }}}

# -- {{{ handle_not_executable
handle_not_executable() {
    local name="$1"
    local path="$2"

    if ! $QUIET; then
        echo -e "  [${YELLOW}WARN${NC}] ${name}: Not executable"
    fi

    prompt_for_action \
        "not-executable" \
        "true" \
        "fix_executable_permission" \
        "$path"
}
# }}}

# -- {{{ handle_syntax_error
handle_syntax_error() {
    local name="$1"
    local path="$2"

    if ! $QUIET; then
        echo -e "  [${RED}ERROR${NC}] ${name}: Syntax error detected"
    fi

    prompt_for_action \
        "syntax-error" \
        "false" \
        "" \
        "$path"
}
# }}}

# -- {{{ handle_missing_shebang
handle_missing_shebang() {
    local name="$1"
    local path="$2"

    if ! $QUIET; then
        echo -e "  [${YELLOW}WARN${NC}] ${name}: Missing or invalid shebang"
    fi

    prompt_for_action \
        "missing-shebang" \
        "false" \
        "" \
        "$path"
}
# }}}

# -- {{{ handle_missing_dependency
handle_missing_dependency() {
    local cmd="$1"
    local required_by="$2"

    if ! $QUIET; then
        echo -e "  [${RED}CRITICAL${NC}] ${cmd}: External dependency not found (required by ${required_by})"
    fi

    prompt_for_action \
        "missing-dependency-${cmd}" \
        "false" \
        "" \
        "$cmd"
}
# }}}

# -- {{{ handle_missing_directory
handle_missing_directory() {
    local dir="$1"
    local is_required="$2"

    local severity
    if [[ "$is_required" == "true" ]]; then
        severity="${YELLOW}WARN${NC}"
    else
        severity="${CYAN}INFO${NC}"
    fi

    if ! $QUIET; then
        echo -e "  [${severity}] Directory not found: ${dir}"
    fi

    if [[ "$is_required" == "true" ]]; then
        prompt_for_action \
            "missing-directory" \
            "true" \
            "fix_missing_directory" \
            "${DIR}/${dir}"
    fi
}
# }}}

# Main audit functions
# -- {{{ audit_utilities
audit_utilities() {
    if ! $QUIET; then
        echo -e "${BOLD}Checking delta-version utilities...${NC}"
    fi

    for entry in "${UTILITY_REGISTRY[@]}"; do
        IFS='|' read -r name path type desc <<< "$entry"
        local full_path="${DIR}/${path}"

        # Check existence
        if ! check_script_exists "$full_path"; then
            ((ISSUES_FOUND++))
            handle_missing_script "$name" "$full_path" "$type"
            continue
        fi

        # Check executable
        if ! check_script_executable "$full_path"; then
            ((ISSUES_FOUND++))
            handle_not_executable "$name" "$full_path"
        fi

        # Check syntax
        if ! check_script_syntax "$full_path"; then
            ((ISSUES_FOUND++))
            handle_syntax_error "$name" "$full_path"
        fi

        # Check shebang
        if ! check_script_shebang "$full_path"; then
            ((ISSUES_FOUND++))
            handle_missing_shebang "$name" "$full_path"
        fi
    done

    if ! $QUIET && [[ $ISSUES_FOUND -eq 0 ]]; then
        echo -e "${GREEN}✓ All utilities passed checks${NC}"
    fi
}
# }}}

# -- {{{ audit_dependencies
audit_dependencies() {
    if ! $QUIET; then
        echo
        echo -e "${BOLD}Checking external dependencies...${NC}"
    fi

    local dep_issues=0

    for entry in "${DEPENDENCY_REGISTRY[@]}"; do
        IFS='|' read -r cmd required_by check_cmd <<< "$entry"

        if ! check_external_dependency "$cmd"; then
            ((ISSUES_FOUND++))
            ((dep_issues++))
            handle_missing_dependency "$cmd" "$required_by"
        fi
    done

    if ! $QUIET && [[ $dep_issues -eq 0 ]]; then
        echo -e "${GREEN}✓ All dependencies found${NC}"
    fi
}
# }}}

# -- {{{ audit_structure
audit_structure() {
    if ! $QUIET; then
        echo
        echo -e "${BOLD}Checking directory structure...${NC}"
    fi

    local struct_issues=0

    for dir in "${REQUIRED_DIRS[@]}"; do
        if ! check_directory_exists "${DIR}/${dir}"; then
            ((ISSUES_FOUND++))
            ((struct_issues++))
            handle_missing_directory "$dir" "true"
        fi
    done

    if ! $QUIET && [[ $struct_issues -eq 0 ]]; then
        echo -e "${GREEN}✓ Required directories exist${NC}"
    fi
}
# }}}

# Project integration functions
# -- {{{ get_project_path
get_project_path() {
    local project_name="$1"
    local parent_dir=$(dirname "$DIR")
    echo "${parent_dir}/${project_name}"
}
# }}}

# -- {{{ check_project_metadata
check_project_metadata() {
    local project_dir="$1"
    [[ -f "${project_dir}/project.meta.json" ]]
}
# }}}

# -- {{{ check_delta_guide_symlink
check_delta_guide_symlink() {
    local project_dir="$1"
    [[ -L "${project_dir}/docs/delta-guide.md" ]]
}
# }}}

# -- {{{ create_metadata_template
create_metadata_template() {
    local project_dir="$1"
    local project_name=$(basename "$project_dir")

    if $DRY_RUN; then
        echo -e "${CYAN}[DRY RUN]${NC} Would create project.meta.json in $project_name"
        return 0
    fi

    # Interactive prompts for metadata
    local status language description

    if $INTERACTIVE; then
        echo
        echo -n "  Project status? [active/maintenance/experimental/archived]: "
        read -r status
        status=${status:-active}

        echo -n "  Primary language? [lua/bash/c/python/other]: "
        read -r language
        language=${language:-other}

        echo -n "  Brief description: "
        read -r description
        description=${description:-"No description"}
    else
        status="active"
        language="other"
        description="Auto-generated metadata"
    fi

    cat > "${project_dir}/project.meta.json" <<EOF
{
  "name": "${project_name}",
  "status": "${status}",
  "language": "${language}",
  "description": "${description}",
  "created": "$(date +%Y-%m-%d)",
  "updated": "$(date +%Y-%m-%d)"
}
EOF

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Created:${NC} ${project_name}/project.meta.json"
        ((ISSUES_FIXED++))
        return 0
    else
        echo -e "${RED}✗ Failed:${NC} Could not create metadata file"
        return 1
    fi
}
# }}}

# -- {{{ create_delta_guide_symlink
create_delta_guide_symlink() {
    local project_dir="$1"
    local project_name=$(basename "$project_dir")
    local docs_dir="${project_dir}/docs"

    if $DRY_RUN; then
        echo -e "${CYAN}[DRY RUN]${NC} Would create delta-guide.md symlink in $project_name"
        return 0
    fi

    # Ensure docs directory exists
    if [[ ! -d "$docs_dir" ]]; then
        mkdir -p "$docs_dir"
    fi

    # Create relative symlink to delta-version/docs/delta-guide.md
    ln -sf "../../delta-version/docs/delta-guide.md" "${docs_dir}/delta-guide.md"

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Created symlink:${NC} ${project_name}/docs/delta-guide.md"
        ((ISSUES_FIXED++))
        return 0
    else
        echo -e "${RED}✗ Failed:${NC} Could not create symlink"
        return 1
    fi
}
# }}}

# -- {{{ audit_project_metadata
audit_project_metadata() {
    local project_name="$1"
    local project_dir=$(get_project_path "$project_name")

    if ! check_project_metadata "$project_dir"; then
        ((ISSUES_FOUND++))

        if ! $QUIET; then
            echo -e "  [${YELLOW}NOTICE${NC}] ${project_name}: Missing project.meta.json"
        fi

        if $FIX_ALL || $INTERACTIVE; then
            prompt_for_action \
                "missing-metadata" \
                "true" \
                "create_metadata_template" \
                "$project_dir"
        else
            ((ISSUES_SKIPPED++))
        fi
    fi
}
# }}}

# -- {{{ audit_project_symlinks
audit_project_symlinks() {
    local project_name="$1"
    local project_dir=$(get_project_path "$project_name")

    # Check delta-guide.md symlink
    if ! check_delta_guide_symlink "$project_dir"; then
        ((ISSUES_FOUND++))

        if ! $QUIET; then
            echo -e "  [${CYAN}INFO${NC}] ${project_name}: Missing delta-guide.md symlink"
        fi

        if $FIX_ALL || $INTERACTIVE; then
            prompt_for_action \
                "missing-delta-guide-symlink" \
                "true" \
                "create_delta_guide_symlink" \
                "$project_dir"
        else
            ((ISSUES_SKIPPED++))
        fi
    fi
}
# }}}

# -- {{{ audit_project
audit_project() {
    local project_name="$1"

    if ! $QUIET; then
        echo
        echo -e "${BOLD}Checking: ${project_name}${NC}"
        echo "──────────────────────────────────────────────────────────"
    fi

    if $CHECK_METADATA; then
        audit_project_metadata "$project_name"
    fi

    if $CHECK_SYMLINKS; then
        audit_project_symlinks "$project_name"
    fi

    # TODO: Implement TUI audit, transcript cataloging, issue standards
    if $CHECK_TUI_AUDIT || $CHECK_TRANSCRIPTS || $CHECK_ISSUE_STANDARDS; then
        if ! $QUIET; then
            echo -e "  [${YELLOW}TODO${NC}] TUI/transcript/issue checks not yet implemented"
        fi
    fi
}
# }}}

# -- {{{ audit_projects
audit_projects() {
    local projects=("$@")

    if ! $QUIET; then
        echo
        echo -e "${BOLD}Scanning ${#projects[@]} projects...${NC}"
    fi

    for project in "${projects[@]}"; do
        # Skip delta-version itself
        if [[ "$project" == "delta-version" ]]; then
            continue
        fi

        audit_project "$project"
    done
}
# }}}

# Summary reporting
# -- {{{ print_summary
print_summary() {
    echo
    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Summary:${NC}"
    echo -e "  Issues found:     ${ISSUES_FOUND}"
    echo -e "  Issues fixed:     ${GREEN}${ISSUES_FIXED}${NC}"
    echo -e "  Issues created:   ${CYAN}${ISSUES_CREATED}${NC}"
    echo -e "  Issues skipped:   ${YELLOW}${ISSUES_SKIPPED}${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"

    if [[ $ISSUES_FOUND -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ All checks passed!${NC}"
        return 0
    elif [[ $((ISSUES_FIXED + ISSUES_CREATED)) -ge $ISSUES_FOUND ]]; then
        echo -e "${GREEN}${BOLD}✓ All issues addressed!${NC}"
        return 0
    else
        echo -e "${YELLOW}${BOLD}! Some issues remain${NC}"
        return 1
    fi
}
# }}}

# Main function
# -- {{{ main
main() {
    parse_args "$@"

    # Print header
    if ! $QUIET; then
        echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║     Delta-Version Utility Health Checker v1.0        ║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
        echo
    fi

    # Run delta-version checks
    if $CHECK_UTILITIES; then
        audit_utilities
    fi

    if $CHECK_DEPENDENCIES; then
        audit_dependencies
    fi

    if $CHECK_STRUCTURE; then
        audit_structure
    fi

    # Run project integration checks
    if $CHECK_METADATA || $CHECK_SYMLINKS || $CHECK_TUI_AUDIT || \
       $CHECK_TRANSCRIPTS || $CHECK_ISSUE_STANDARDS; then
        local projects=()

        # Determine which projects to check
        if $ALL_PROJECTS; then
            # Use list-projects.sh if available
            if [[ -x "${DIR}/scripts/list-projects.sh" ]]; then
                mapfile -t projects < <("${DIR}/scripts/list-projects.sh" --names 2>/dev/null)
            else
                echo -e "${RED}Error: list-projects.sh not found${NC}" >&2
                return 1
            fi
        elif [[ ${#SPECIFIC_PROJECTS[@]} -gt 0 ]]; then
            projects=("${SPECIFIC_PROJECTS[@]}")
        fi

        if [[ ${#projects[@]} -gt 0 ]]; then
            audit_projects "${projects[@]}"
        fi
    fi

    # Print summary
    print_summary
    return $?
}
# }}}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
