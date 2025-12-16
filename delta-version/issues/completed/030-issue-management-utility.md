# Issue 030: Issue Management Utility

## Current Behavior

Issue management is done manually through file system operations. Creating new issues requires manually determining the next ID number, following the naming convention, and ensuring all required sections are present. Completing issues requires manually moving files, updating multiple progress files, and maintaining the table of contents.

### Current Issues
- No automated way to create new issues with correct ID numbering
- No validation that issues follow the required template
- Manual process for moving completed issues
- Easy to forget updating progress files
- No way to list or search issues from command line

## Intended Behavior

Create an issue management utility script that:
1. **Issue Creation**: Generate new issues with auto-incremented IDs and proper template
2. **Issue Listing**: List issues by status, phase, or search terms
3. **Issue Completion**: Automate the completion workflow (move, update progress, validate)
4. **Issue Validation**: Check issues for required sections and formatting
5. **Progress Updates**: Automatically update relevant progress files
6. **Interactive Mode**: Full interactive interface for issue management

## Suggested Implementation Steps

### 1. Issue Discovery and Listing
```bash
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"

# -- {{{ list_issues
function list_issues() {
    local status="${1:-all}"  # all, pending, completed, in_progress
    local phase="${2:-}"       # optional phase filter

    local issues_dir="${DIR}/issues"
    local completed_dir="${DIR}/issues/completed"

    case "$status" in
        all)
            find "$issues_dir" -name "*.md" -type f | grep -E '[0-9]{3}-'
            ;;
        completed)
            find "$completed_dir" -name "*.md" -type f 2>/dev/null
            ;;
        pending)
            find "$issues_dir" -maxdepth 1 -name "*.md" -type f | grep -E '[0-9]{3}-'
            ;;
    esac
}
# }}}
```

### 2. Next ID Generation
```bash
# -- {{{ get_next_issue_id
function get_next_issue_id() {
    local phase="${1:-}"
    local issues_dir="${DIR}/issues"

    # Find highest existing ID
    local max_id
    max_id=$(find "$issues_dir" -name "*.md" -type f | \
             grep -oP '\d{3}' | \
             sort -n | \
             tail -1)

    if [[ -z "$max_id" ]]; then
        echo "001"
    else
        printf "%03d" $((10#$max_id + 1))
    fi
}
# }}}
```

### 3. Issue Creation
```bash
# -- {{{ create_issue
function create_issue() {
    local title="$1"
    local phase="${2:-}"

    local issue_id
    issue_id=$(get_next_issue_id)

    # Generate filename from title
    local filename
    filename=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')

    local full_name="${issue_id}-${filename}.md"
    local issue_path="${DIR}/issues/${full_name}"

    # Generate issue from template
    cat > "$issue_path" <<EOF
# Issue ${issue_id}: ${title}

## Current Behavior

{Describe the current state}

## Intended Behavior

{Describe what should exist after completion}

1. **Feature 1**: {Description}
2. **Feature 2**: {Description}

## Suggested Implementation Steps

### 1. {First Step}
\`\`\`bash
# Implementation outline
\`\`\`

## Related Documents
- {Related issue or document}

## Metadata
- **Priority**: Medium
- **Complexity**: Medium
- **Dependencies**: None
- **Impact**: {Brief impact description}

## Success Criteria
- {Measurable criterion 1}
- {Measurable criterion 2}
EOF

    echo "Created: $issue_path"
    echo "Edit this file to complete the issue specification."
}
# }}}
```

### 4. Issue Validation
```bash
# -- {{{ validate_issue
function validate_issue() {
    local issue_file="$1"
    local errors=()

    # Check for required sections
    grep -q "## Current Behavior" "$issue_file" || errors+=("Missing: Current Behavior")
    grep -q "## Intended Behavior" "$issue_file" || errors+=("Missing: Intended Behavior")
    grep -q "## Suggested Implementation" "$issue_file" || errors+=("Missing: Implementation Steps")
    grep -q "## Metadata" "$issue_file" || errors+=("Missing: Metadata")
    grep -q "## Success Criteria" "$issue_file" || errors+=("Missing: Success Criteria")

    # Check metadata fields
    grep -q "Priority:" "$issue_file" || errors+=("Missing: Priority in Metadata")
    grep -q "Dependencies:" "$issue_file" || errors+=("Missing: Dependencies in Metadata")

    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "Validation errors in $(basename "$issue_file"):"
        printf "  - %s\n" "${errors[@]}"
        return 1
    else
        echo "$(basename "$issue_file"): Valid"
        return 0
    fi
}
# }}}
```

### 5. Issue Completion Workflow
```bash
# -- {{{ complete_issue
function complete_issue() {
    local issue_file="$1"

    # Validate first
    validate_issue "$issue_file" || {
        echo "ERROR: Issue validation failed. Fix errors before completing."
        return 1
    }

    local issue_name
    issue_name=$(basename "$issue_file")
    local completed_dir="${DIR}/issues/completed"

    # Move to completed
    mv "$issue_file" "${completed_dir}/${issue_name}"
    echo "Moved to: ${completed_dir}/${issue_name}"

    # Extract phase number for progress update
    local phase_num
    phase_num=$(echo "$issue_name" | grep -oP '^\d')

    if [[ -n "$phase_num" ]]; then
        update_phase_progress "$phase_num" "$issue_name"
    fi

    # Update main progress
    update_main_progress "$issue_name"

    echo "Issue completed: $issue_name"
    echo "Remember to commit changes to version control."
}
# }}}
```

### 6. Progress File Updates
```bash
# -- {{{ update_phase_progress
function update_phase_progress() {
    local phase="$1"
    local issue_name="$2"
    local progress_file="${DIR}/issues/phase-${phase}/progress.md"

    if [[ -f "$progress_file" ]]; then
        echo "Updated phase ${phase} progress file"
        # Add completion note with timestamp
        echo "" >> "$progress_file"
        echo "- **${issue_name}** completed $(date '+%Y-%m-%d')" >> "$progress_file"
    else
        echo "Warning: Phase ${phase} progress file not found"
    fi
}
# }}}

# -- {{{ update_main_progress
function update_main_progress() {
    local issue_name="$1"
    local progress_file="${DIR}/issues/progress.md"

    # This would update the Completed Issues section
    echo "Main progress file should be updated for: $issue_name"
}
# }}}
```

### 7. Interactive Mode
```bash
# -- {{{ run_interactive_mode
function run_interactive_mode() {
    echo "=== Issue Management Utility ==="
    echo "1. List all issues"
    echo "2. List pending issues"
    echo "3. List completed issues"
    echo "4. Create new issue"
    echo "5. Validate issue"
    echo "6. Complete issue"
    echo "7. Search issues"
    echo "q. Quit"

    read -p "Select option: " choice

    case $choice in
        1) list_issues "all" ;;
        2) list_issues "pending" ;;
        3) list_issues "completed" ;;
        4) interactive_create_issue ;;
        5) interactive_validate_issue ;;
        6) interactive_complete_issue ;;
        7) interactive_search_issues ;;
        q|Q) exit 0 ;;
        *) echo "Invalid selection" ;;
    esac
}
# }}}
```

### 8. Help and CLI Interface
```bash
# -- {{{ show_help
function show_help() {
    echo "Usage: manage-issues.sh [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  list [--status STATUS] [--phase N]  List issues"
    echo "  create TITLE [--phase N]            Create new issue"
    echo "  validate FILE                       Validate issue file"
    echo "  complete FILE                       Complete and archive issue"
    echo "  search TERM                         Search issues by content"
    echo
    echo "Options:"
    echo "  -I, --interactive   Run in interactive mode"
    echo "  --help              Show this help message"
    echo
    echo "Examples:"
    echo "  manage-issues.sh list --status pending"
    echo "  manage-issues.sh create 'Add verbose flag'"
    echo "  manage-issues.sh complete issues/029-demo-runner.md"
}
# }}}
```

## Implementation Details

### Script Location
```
scripts/manage-issues.sh
```

### Status Detection

Issues are categorized by location:
- `issues/*.md` - Pending (active) issues
- `issues/completed/*.md` - Completed issues
- `issues/phase-N/*.md` - Phase-specific issues

### Search Functionality

```bash
# -- {{{ search_issues
function search_issues() {
    local term="$1"
    local issues_dir="${DIR}/issues"

    echo "Searching for: $term"
    grep -rl "$term" "$issues_dir" --include="*.md" | while read -r file; do
        echo "  $(basename "$file")"
    done
}
# }}}
```

### Completion Checklist

When completing an issue, the utility should verify:
1. All success criteria documented
2. Related issues updated
3. Progress files updated
4. Table of contents updated (prompt)
5. Ready for version control commit

## Related Documents
- `docs/issue-template.md` - Issue template specification
- `docs/development-guide.md` - Development conventions
- `issues/progress.md` - Main progress tracking

## Tools Required
- Bash scripting
- File system operations
- Text processing (grep, sed)
- Template generation

## Metadata
- **Priority**: Medium
- **Complexity**: Medium-High
- **Dependencies**: None (infrastructure utility)
- **Impact**: Streamlines issue management workflow, reduces errors

## Success Criteria
- Script created at `scripts/manage-issues.sh` ✅
- Automatically generates unique issue IDs ✅
- Creates issues from template with required sections ✅
- Validates issues for completeness ✅
- Automates completion workflow (move, update progress) ✅
- Interactive mode provides full functionality ✅
- Headless mode supports all operations via flags ✅
- Search functionality works across all issues ✅
- Help message documents all commands and options ✅

## Implementation Notes

**Completed: 2024-12-15**

### Files Created
- `scripts/manage-issues.sh` - Main issue management utility (450+ lines)

### Commands Implemented
- `list [--status STATUS]` - List issues by status (all, pending, completed)
- `create TITLE` - Create new issue with auto-incremented ID
- `validate FILE` - Validate issue has required sections
- `complete FILE` - Move issue to completed directory
- `search TERM` - Search issues by content
- `stats` - Show issue statistics

### Features
- Vimfold organization for all functions
- Interactive mode with menu-driven interface (`-I`)
- Headless mode for all operations
- Validation checks for required sections and metadata
- Warning detection for unfilled placeholders
- Statistics display showing pending/completed counts

### Testing Results
- `stats`: Shows 29 pending, 1 completed, next ID 031
- `list --status pending`: Lists all pending issues with IDs
- `search "gitignore"`: Found 28 matches across issues
- `validate`: Correctly identifies valid issues with warnings
