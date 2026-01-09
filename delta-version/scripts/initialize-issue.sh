#!/usr/bin/env bash
# initialize-issue.sh - Issue Initialization Workflow Script
#
# Sets up development environment for an issue including worktree creation,
# issue analysis, and sub-issue generation.
#
# General approach: Parse issue metadata, create/reuse worktree based on
# root/sub-issue status, optionally analyze and split, prepare environment.

set -euo pipefail

DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Color codes
# -- {{{ COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
# }}}

# Global variables
# -- {{{ GLOBALS
ISSUE_NUM=""
PROJECT_NAME=""
IS_SUBISSUE=false
ROOT_ISSUE=""
WORKTREE_PATH=""
ISSUE_FILE=""
DRY_RUN=false
NO_ANALYSIS=false
AUTO_SPLIT=false
SKIP_WORKTREE=false
# }}}

# -- {{{ show_help
show_help() {
    cat <<EOF
${BOLD}USAGE:${NC}
    initialize-issue.sh [OPTIONS] <issue-file>

${BOLD}DESCRIPTION:${NC}
    Sets up development environment for an issue including worktree
    creation, issue analysis, and sub-issue generation.

${BOLD}OPTIONS:${NC}
    --dry-run           Show what would be done without doing it
    --no-analysis       Skip issue analysis and splitting
    --auto-split        Automatically create sub-issues without prompting
    --skip-worktree     Skip worktree creation (use existing)
    -h, --help          Show this help

${BOLD}EXAMPLES:${NC}
    initialize-issue.sh issues/043-new-feature.md
        Full initialization with interactive prompts

    initialize-issue.sh --dry-run issues/043-new-feature.md
        Preview what would happen

    initialize-issue.sh --no-analysis issues/043a-subtask.md
        Initialize sub-issue without analysis
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
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-analysis)
                NO_ANALYSIS=true
                shift
                ;;
            --auto-split)
                AUTO_SPLIT=true
                shift
                ;;
            --skip-worktree)
                SKIP_WORKTREE=true
                shift
                ;;
            -*)
                echo -e "${RED}Error: Unknown option $1${NC}" >&2
                exit 1
                ;;
            *)
                if [[ -z "$ISSUE_FILE" ]]; then
                    ISSUE_FILE="$1"
                else
                    echo -e "${RED}Error: Multiple issue files specified${NC}" >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$ISSUE_FILE" ]]; then
        echo -e "${RED}Error: No issue file specified${NC}" >&2
        echo "Usage: initialize-issue.sh <issue-file>"
        exit 1
    fi

    if [[ ! -f "$ISSUE_FILE" ]]; then
        echo -e "${RED}Error: Issue file not found: $ISSUE_FILE${NC}" >&2
        exit 1
    fi
}
# }}}

# -- {{{ parse_issue_file
parse_issue_file() {
    local issue_file="$1"

    # Extract issue number and project
    local basename=$(basename "$issue_file")

    # Pattern: 042-name.md or 042a-name.md
    if [[ $basename =~ ^([0-9]+[a-z]?)-.*\.md$ ]]; then
        ISSUE_NUM="${BASH_REMATCH[1]}"
    else
        echo -e "${RED}Error: Cannot parse issue number from $basename${NC}" >&2
        echo "Expected format: ###-name.md or ###X-name.md (e.g., 043-feature.md or 043a-subtask.md)"
        return 1
    fi

    # Determine if sub-issue
    if [[ $ISSUE_NUM =~ ^([0-9]+)([a-z])$ ]]; then
        IS_SUBISSUE=true
        ROOT_ISSUE="${BASH_REMATCH[1]}"
    else
        IS_SUBISSUE=false
        ROOT_ISSUE="$ISSUE_NUM"
    fi

    # Determine project from issue file location
    local issue_dir=$(cd "$(dirname "$issue_file")" && pwd)
    local potential_project=$(basename "$(dirname "$issue_dir")")

    # Validate it's a real project directory
    if [[ -d "$(dirname "$issue_dir")" ]]; then
        PROJECT_NAME="$potential_project"
    else
        echo -e "${RED}Error: Cannot determine project from path${NC}" >&2
        return 1
    fi

    return 0
}
# }}}

# -- {{{ setup_worktree
setup_worktree() {
    local issue_num="$1"
    local project="$2"
    local is_subissue="$3"

    if $SKIP_WORKTREE; then
        echo -e "${CYAN}Skipping worktree setup (--skip-worktree specified)${NC}"
        # Set WORKTREE_PATH to current directory
        WORKTREE_PATH=$(pwd)
        return 0
    fi

    local manage_script="${DIR}/scripts/manage-worktree.sh"

    if [[ ! -x "$manage_script" ]]; then
        echo -e "${RED}Error: manage-worktree.sh not found or not executable${NC}" >&2
        echo "Expected at: $manage_script"
        return 1
    fi

    if $is_subissue; then
        echo -e "${CYAN}Sub-issue detected. Checking for parent worktree...${NC}"

        # Check if parent worktree exists
        if $DRY_RUN; then
            echo -e "${CYAN}[DRY RUN]${NC} Would check for worktree: $ROOT_ISSUE"
            # Get the path that would be used (don't hardcode "dv")
            WORKTREE_PATH=$("$manage_script" path "$ROOT_ISSUE" "$project" 2>/dev/null || echo "/mnt/mtwo/programming/ai-worktrees/${project}/issue-${ROOT_ISSUE}")
        else
            local parent_worktree=$("$manage_script" path "$ROOT_ISSUE" "$project" 2>/dev/null || echo "")

            if [[ -z "$parent_worktree" || ! -d "$parent_worktree" ]]; then
                echo -e "${YELLOW}Warning: Parent worktree not found. Creating for root issue ${ROOT_ISSUE}${NC}"
                "$manage_script" create "$ROOT_ISSUE" "$project"
            fi

            WORKTREE_PATH=$("$manage_script" path "$ROOT_ISSUE" "$project")
        fi
    else
        echo -e "${GREEN}Creating worktree for root issue ${issue_num}...${NC}"

        if $DRY_RUN; then
            echo -e "${CYAN}[DRY RUN]${NC} Would create worktree for issue $issue_num"
            # Get the path that would be used (don't hardcode "dv")
            WORKTREE_PATH=$("$manage_script" path "$issue_num" "$project" 2>/dev/null || echo "/mnt/mtwo/programming/ai-worktrees/${project}/issue-${issue_num}")
        else
            "$manage_script" create "$issue_num" "$project"
            WORKTREE_PATH=$("$manage_script" path "$issue_num" "$project")
        fi
    fi

    if [[ ! -d "$WORKTREE_PATH" ]] && ! $DRY_RUN; then
        echo -e "${RED}Error: Failed to create/find worktree${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}✓ Worktree ready:${NC} $WORKTREE_PATH"
    return 0
}
# }}}

# -- {{{ analyze_and_split_issue
analyze_and_split_issue() {
    local issue_file="$1"
    local worktree_path="$2"

    if $NO_ANALYSIS; then
        echo -e "${CYAN}Skipping issue analysis (--no-analysis specified)${NC}"
        return 0
    fi

    # Note: issue-splitter.sh operates on directories, not individual files
    # For now, skip automatic analysis and just note that it's available
    echo
    echo -e "${BOLD}Issue analysis:${NC}"
    echo -e "${CYAN}To analyze and split issues, use issue-splitter.sh on the issues directory${NC}"

    if $DRY_RUN; then
        return 0
    fi

    # Skip analysis for now - issue-splitter.sh doesn't support single-file analysis
    # Users can manually run issue-splitter.sh on the project's issues/ directory
    local analysis_output=""

    echo "$analysis_output"

    # Check if issue should be split
    local should_split=false
    if echo "$analysis_output" | grep -qi "RECOMMEND.*SPLIT"; then
        should_split=true
    elif echo "$analysis_output" | grep -qi "splittable"; then
        should_split=true
    fi

    if $should_split; then
        local response="n"

        if $AUTO_SPLIT; then
            response="y"
            echo "Auto-splitting enabled"
        else
            echo
            echo -n "Create sub-issues based on analysis? [y/N]: "
            read -r response
        fi

        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Executing issue split...${NC}"

            if "$splitter_script" --execute "$issue_file"; then
                echo -e "${GREEN}✓ Sub-issues created${NC}"

                # List created sub-issues
                local issue_dir=$(dirname "$issue_file")
                local base_num="${ISSUE_NUM}"
                echo
                echo -e "${BOLD}Created sub-issues:${NC}"

                local count=0
                for subissue in "${issue_dir}/${base_num}"[a-z]-*.md; do
                    if [[ -f "$subissue" ]]; then
                        echo "  - $(basename "$subissue")"
                        ((count++))
                    fi
                done

                if [[ $count -eq 0 ]]; then
                    echo "  (No sub-issues found - check issue-splitter output)"
                fi
            else
                echo -e "${RED}✗ Failed to create sub-issues${NC}" >&2
            fi
        else
            echo "Skipping sub-issue creation"
        fi
    else
        echo -e "${CYAN}Issue does not require splitting${NC}"
    fi
}
# }}}

# -- {{{ prepare_environment
prepare_environment() {
    local issue_file="$1"
    local worktree_path="$2"

    echo
    echo -e "${BOLD}Preparing development environment...${NC}"

    # Copy issue file to worktree if needed
    local issue_basename=$(basename "$issue_file")
    local worktree_issue="${worktree_path}/issues/${issue_basename}"

    if $DRY_RUN; then
        echo -e "${CYAN}[DRY RUN]${NC} Would copy issue file to worktree"
    else
        if [[ ! -f "$worktree_issue" ]]; then
            mkdir -p "$(dirname "$worktree_issue")"
            cp "$issue_file" "$worktree_issue"
            echo -e "${GREEN}✓ Copied issue file to worktree${NC}"
        else
            echo -e "${CYAN}Issue file already in worktree${NC}"
        fi
    fi

    # Check for common directory requirements by scanning issue content
    if ! $DRY_RUN; then
        local required_dirs=()

        if grep -q "scripts/" "$issue_file" 2>/dev/null; then
            required_dirs+=("${worktree_path}/scripts")
        fi
        if grep -q "libs/" "$issue_file" 2>/dev/null; then
            required_dirs+=("${worktree_path}/libs")
        fi
        if grep -q "src/" "$issue_file" 2>/dev/null; then
            required_dirs+=("${worktree_path}/src")
        fi

        for dir in "${required_dirs[@]}"; do
            if [[ ! -d "$dir" ]]; then
                mkdir -p "$dir"
                echo -e "${GREEN}✓ Created directory: $(basename "$dir")/${NC}"
            fi
        done
    fi

    # Check dependencies (look for "Dependencies:" or "Blocks:" sections)
    if grep -qi "^## Dependencies" "$issue_file" 2>/dev/null; then
        echo -e "${CYAN}Note: This issue has dependencies. Review before starting.${NC}"
    fi

    if grep -qi "^## Blocked" "$issue_file" 2>/dev/null; then
        echo -e "${CYAN}Note: This issue may have blocking relationships. Review issue file.${NC}"
    fi
}
# }}}

# -- {{{ print_next_steps
print_next_steps() {
    local worktree_path="$1"
    local is_subissue="$2"
    local issue_num="$3"
    local project="$4"

    echo
    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Setup complete!${NC}"
    echo
    echo -e "${BOLD}Next steps:${NC}"
    echo -e "  cd ${worktree_path}"
    echo -e "  # Start working on issue $issue_num"
    echo

    if ! $is_subissue; then
        # Get short project name for branch naming
        local short_name="${project}"
        case "$project" in
            delta-version) short_name="dv" ;;
            neocities-modernization) short_name="neo" ;;
            world-edit-to-execute) short_name="wete" ;;
        esac

        echo -e "${BOLD}When complete:${NC}"
        echo -e "  cd /mnt/mtwo/programming/ai-stuff"
        echo -e "  git checkout master"
        echo -e "  git merge ${short_name}/issue-${issue_num}"
        echo -e "  ./delta-version/scripts/manage-worktree.sh remove $issue_num $project"
    else
        echo -e "${BOLD}Sub-issue workflow:${NC}"
        echo -e "  Work within parent worktree (issue $ROOT_ISSUE)"
        echo -e "  Commit with: git commit -m \"Issue ${issue_num}: <description>\""
        echo -e "  Complete all sub-issues before closing root issue"
    fi

    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
}
# }}}

# -- {{{ main
main() {
    # Parse arguments
    parse_args "$@"

    if ! $DRY_RUN; then
        echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║         Issue Initialization Workflow                ║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
        echo
    else
        echo -e "${CYAN}${BOLD}[DRY RUN MODE]${NC}"
        echo
    fi

    # Parse issue file
    if ! parse_issue_file "$ISSUE_FILE"; then
        return 1
    fi

    echo -e "${BOLD}Issue:${NC} $ISSUE_NUM"
    echo -e "${BOLD}Project:${NC} $PROJECT_NAME"
    echo -e "${BOLD}Type:${NC} $(if $IS_SUBISSUE; then echo "Sub-issue (parent: $ROOT_ISSUE)"; else echo "Root issue"; fi)"
    echo

    # Setup worktree
    if ! setup_worktree "$ISSUE_NUM" "$PROJECT_NAME" "$IS_SUBISSUE"; then
        return 1
    fi

    # Only analyze root issues (not sub-issues)
    if ! $IS_SUBISSUE; then
        analyze_and_split_issue "$ISSUE_FILE" "$WORKTREE_PATH"
    else
        echo -e "${CYAN}Sub-issue: Skipping analysis (work within parent worktree)${NC}"
    fi

    # Prepare environment
    prepare_environment "$ISSUE_FILE" "$WORKTREE_PATH"

    # Print next steps
    if ! $DRY_RUN; then
        print_next_steps "$WORKTREE_PATH" "$IS_SUBISSUE" "$ISSUE_NUM" "$PROJECT_NAME"
    fi

    return 0
}
# }}}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
