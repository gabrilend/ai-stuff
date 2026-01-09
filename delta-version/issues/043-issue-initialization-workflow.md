# Issue 043: Issue Initialization Workflow Script

## Vision

When starting work on a new issue, developers and AI agents should have a single command that handles all the setup work: creating the worktree, analyzing the issue for sub-tasks, generating sub-issue files, and preparing the development environment. This reduces friction and ensures consistent workflow practices.

## Current Behavior

To start work on an issue, the developer must manually:
1. Create a worktree: `./scripts/manage-worktree.sh create 042 delta-version`
2. Navigate to the worktree
3. Remember to run issue-splitter.sh if the issue might benefit from being split
4. Manually execute on the splitter's recommendations
5. Keep track of which issues have been initialized

This is error-prone and easy to forget steps.

## Intended Behavior

A single command handles the entire initialization:

```bash
./scripts/initialize-issue.sh issues/042-utility-health-checker.md
```

The script should:

1. **Parse issue metadata**
   - Extract issue number (042, 042a, etc.) from filename
   - Determine if it's a root issue or sub-issue
   - Identify the project (delta-version, world-edit-to-execute, etc.)

2. **Worktree management**
   - For root issues: Create worktree via `manage-worktree.sh create <issue> <project>`
   - For sub-issues: Use parent's worktree (don't create new one)
   - Copy issue file to worktree if not already there
   - Navigate to worktree automatically (or provide navigation command)

3. **Issue analysis and splitting**
   - Run `issue-splitter.sh --analyze <issue-file>` to analyze complexity
   - Display analysis results to user
   - If splittable, prompt: "Create sub-issues based on analysis? [y/N]"
   - If yes, run `issue-splitter.sh --execute <issue-file>` to generate sub-issue files

4. **Environment preparation**
   - Create any directories mentioned in the issue (if safe to do so)
   - Check for issue dependencies and warn if not met
   - Update project tracking (progress.md, PRIORITY.md if they exist)

5. **Status reporting**
   - Print summary of what was done
   - Show next steps (e.g., "cd <worktree-path>")
   - List any sub-issues created

## Suggested Implementation Steps

### 1. Create Script Skeleton

```bash
#!/usr/bin/env bash
# initialize-issue.sh - Issue Initialization Workflow Script
#
# Sets up development environment for an issue including worktree creation,
# issue analysis, and sub-issue generation.

DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
```

### 2. Parse Issue File

```bash
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
    local issue_dir=$(dirname "$issue_file")
    PROJECT_NAME=$(basename "$(dirname "$issue_dir")")

    return 0
}
# }}}
```

### 3. Worktree Management

```bash
# -- {{{ setup_worktree
setup_worktree() {
    local issue_num="$1"
    local project="$2"
    local is_subissue="$3"

    if $is_subissue; then
        echo -e "${CYAN}Sub-issue detected. Using parent worktree...${NC}"
        # Check if parent worktree exists
        local parent_worktree=$("${DIR}/scripts/manage-worktree.sh" path "$ROOT_ISSUE" "$project" 2>/dev/null)
        if [[ -z "$parent_worktree" ]]; then
            echo -e "${YELLOW}Warning: Parent worktree not found. Creating for root issue ${ROOT_ISSUE}${NC}"
            "${DIR}/scripts/manage-worktree.sh" create "$ROOT_ISSUE" "$project"
        fi
        WORKTREE_PATH=$("${DIR}/scripts/manage-worktree.sh" path "$ROOT_ISSUE" "$project")
    else
        echo -e "${GREEN}Creating worktree for root issue ${issue_num}...${NC}"
        "${DIR}/scripts/manage-worktree.sh" create "$issue_num" "$project"
        WORKTREE_PATH=$("${DIR}/scripts/manage-worktree.sh" path "$issue_num" "$project")
    fi

    if [[ ! -d "$WORKTREE_PATH" ]]; then
        echo -e "${RED}Error: Failed to create/find worktree${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}✓ Worktree ready:${NC} $WORKTREE_PATH"
    return 0
}
# }}}
```

### 4. Issue Analysis and Splitting

```bash
# -- {{{ analyze_and_split_issue
analyze_and_split_issue() {
    local issue_file="$1"
    local worktree_path="$2"

    # Check if issue-splitter.sh exists
    local splitter_script
    if [[ -x "${DIR}/scripts/issue-splitter.sh" ]]; then
        splitter_script="${DIR}/scripts/issue-splitter.sh"
    elif [[ -x "/mnt/mtwo/programming/ai-stuff/scripts/issue-splitter.sh" ]]; then
        splitter_script="/mnt/mtwo/programming/ai-stuff/scripts/issue-splitter.sh"
    else
        echo -e "${YELLOW}Warning: issue-splitter.sh not found, skipping analysis${NC}"
        return 0
    fi

    echo
    echo -e "${BOLD}Analyzing issue for potential sub-tasks...${NC}"

    # Run analysis
    local analysis_output
    analysis_output=$("$splitter_script" --analyze "$issue_file" 2>&1)
    local analysis_exit=$?

    if [[ $analysis_exit -ne 0 ]]; then
        echo -e "${YELLOW}Analysis completed with warnings${NC}"
    fi

    echo "$analysis_output"

    # Check if issue should be split
    if echo "$analysis_output" | grep -q "RECOMMEND.*SPLIT"; then
        echo
        echo -n "Create sub-issues based on analysis? [y/N]: "
        read -r response

        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Executing issue split...${NC}"
            "$splitter_script" --execute "$issue_file"

            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}✓ Sub-issues created${NC}"

                # List created sub-issues
                local issue_dir=$(dirname "$issue_file")
                local base_num="${ISSUE_NUM}"
                echo
                echo -e "${BOLD}Created sub-issues:${NC}"
                ls -1 "${issue_dir}/${base_num}"[a-z]-*.md 2>/dev/null | while read -r subissue; do
                    echo "  - $(basename "$subissue")"
                done
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
```

### 5. Environment Preparation

```bash
# -- {{{ prepare_environment
prepare_environment() {
    local issue_file="$1"
    local worktree_path="$2"

    echo
    echo -e "${BOLD}Preparing development environment...${NC}"

    # Copy issue file to worktree if needed
    local issue_basename=$(basename "$issue_file")
    local worktree_issue="${worktree_path}/${PROJECT_NAME}/issues/${issue_basename}"

    if [[ ! -f "$worktree_issue" ]]; then
        mkdir -p "$(dirname "$worktree_issue")"
        cp "$issue_file" "$worktree_issue"
        echo -e "${GREEN}✓ Copied issue file to worktree${NC}"
    fi

    # Check for common directory requirements
    local required_dirs=()
    if grep -q "scripts/" "$issue_file"; then
        required_dirs+=("${worktree_path}/${PROJECT_NAME}/scripts")
    fi
    if grep -q "libs/" "$issue_file"; then
        required_dirs+=("${worktree_path}/${PROJECT_NAME}/libs")
    fi
    if grep -q "src/" "$issue_file"; then
        required_dirs+=("${worktree_path}/${PROJECT_NAME}/src")
    fi

    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            echo -e "${GREEN}✓ Created directory: $(basename "$dir")/${NC}"
        fi
    done

    # Check dependencies (look for "Dependencies:" or "Blocks:" sections)
    local deps=$(grep -A 5 "^## Dependencies" "$issue_file" 2>/dev/null)
    if [[ -n "$deps" ]]; then
        echo -e "${CYAN}Note: This issue has dependencies. Review before starting.${NC}"
    fi
}
# }}}
```

### 6. Main Function

```bash
# -- {{{ main
main() {
    local issue_file="$1"

    if [[ -z "$issue_file" ]]; then
        echo "Usage: initialize-issue.sh <path-to-issue-file.md>"
        exit 1
    fi

    if [[ ! -f "$issue_file" ]]; then
        echo -e "${RED}Error: Issue file not found: $issue_file${NC}" >&2
        exit 1
    fi

    echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║         Issue Initialization Workflow                ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
    echo

    # Parse issue file
    if ! parse_issue_file "$issue_file"; then
        exit 1
    fi

    echo -e "${BOLD}Issue:${NC} $ISSUE_NUM"
    echo -e "${BOLD}Project:${NC} $PROJECT_NAME"
    echo -e "${BOLD}Type:${NC} $(if $IS_SUBISSUE; then echo "Sub-issue (parent: $ROOT_ISSUE)"; else echo "Root issue"; fi)"
    echo

    # Setup worktree
    if ! setup_worktree "$ISSUE_NUM" "$PROJECT_NAME" "$IS_SUBISSUE"; then
        exit 1
    fi

    # Only analyze root issues (not sub-issues)
    if ! $IS_SUBISSUE; then
        analyze_and_split_issue "$issue_file" "$WORKTREE_PATH"
    else
        echo -e "${CYAN}Sub-issue: Skipping analysis (work within parent worktree)${NC}"
    fi

    # Prepare environment
    prepare_environment "$issue_file" "$WORKTREE_PATH"

    # Print next steps
    echo
    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Setup complete!${NC}"
    echo
    echo -e "${BOLD}Next steps:${NC}"
    echo -e "  cd ${WORKTREE_PATH}/${PROJECT_NAME}"
    echo -e "  # Start working on issue $ISSUE_NUM"
    echo
    if ! $IS_SUBISSUE; then
        echo -e "${BOLD}When complete:${NC}"
        echo -e "  cd /mnt/mtwo/programming/ai-stuff"
        echo -e "  git checkout ${PROJECT_NAME%-*}/dev"
        echo -e "  git merge ${PROJECT_NAME%-*}/issue-${ISSUE_NUM}"
        echo -e "  ./delta-version/scripts/manage-worktree.sh remove $ISSUE_NUM $PROJECT_NAME"
    fi
    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
}
# }}}

main "$@"
```

## Additional Features to Consider

1. **Dry-run mode**: `--dry-run` to show what would be done without doing it
2. **Skip analysis**: `--no-analysis` to skip issue-splitter.sh entirely
3. **Auto-split**: `--auto-split` to automatically create sub-issues without prompting
4. **Template support**: `--template <name>` to apply issue templates
5. **Dependency checking**: Verify all blocking issues are completed
6. **Progress tracking**: Auto-update progress.md with "in progress" status
7. **IDE integration**: Generate `.vscode/launch.json` or similar if project uses it
8. **Pre-commit hooks**: Install project-specific git hooks in the worktree

## CLI Interface

```bash
Usage: initialize-issue.sh [OPTIONS] <issue-file>

OPTIONS:
    --dry-run           Show what would be done without doing it
    --no-analysis       Skip issue analysis and splitting
    --auto-split        Automatically create sub-issues without prompting
    --skip-worktree     Skip worktree creation (use existing)
    -h, --help          Show this help

EXAMPLES:
    initialize-issue.sh issues/043-new-feature.md
        Full initialization with interactive prompts

    initialize-issue.sh --dry-run issues/043-new-feature.md
        Preview what would happen

    initialize-issue.sh --no-analysis issues/043a-subtask.md
        Initialize sub-issue without analysis
```

## Files to Create

- `delta-version/scripts/initialize-issue.sh` - Main initialization script

## Related Issues

- Issue 041: Git Worktree Multi-Agent Architecture (provides worktree management)
- Issue 042: Utility Health Checker (could validate issue file format)
- Issue 030: Issue Management Utility (provides issue file operations)

## Acceptance Criteria

- [ ] Script parses issue numbers correctly (042, 042a, etc.)
- [ ] Root issues get new worktrees, sub-issues use parent's worktree
- [ ] Issue analysis runs with issue-splitter.sh (if available)
- [ ] Interactive prompt for sub-issue creation
- [ ] Sub-issues are generated when requested
- [ ] Issue file is copied to worktree
- [ ] Next steps are clearly displayed
- [ ] Handles missing dependencies gracefully
- [ ] Dry-run mode works correctly
- [ ] Help text documents all options

## Metadata

- **Priority**: High
- **Complexity**: Medium
- **Phase**: 1 (Foundation Infrastructure)
- **Dependencies**: Issue 041 (worktree system)
- **Blocks**: Developer workflow efficiency

## Notes

This script embodies the DRY principle - instead of repeating the same setup steps for every issue, it encapsulates the entire workflow into a single command. It also ensures consistency across agents and developers by standardizing the initialization process.
