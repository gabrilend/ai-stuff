#!/bin/bash
# Issue management utility for Delta-Version project
# Provides automated issue creation, validation, completion, and search functionality

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"

# -- {{{ get_next_issue_id
function get_next_issue_id() {
    local issues_dir="${DIR}/issues"

    # Find highest existing ID across all issue locations
    local max_id
    max_id=$(find "$issues_dir" -name "*.md" -type f 2>/dev/null | \
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

# -- {{{ list_issues
function list_issues() {
    local status="${1:-all}"
    local phase_filter="${2:-}"

    local issues_dir="${DIR}/issues"
    local completed_dir="${DIR}/issues/completed"

    echo "Issues (status: $status):"
    echo "========================="

    local count=0

    case "$status" in
        all)
            # All issues except in phase subdirs and completed
            while IFS= read -r file; do
                [[ -n "$file" ]] || continue
                display_issue_line "$file"
                ((count++))
            done < <(find "$issues_dir" -maxdepth 1 -name "[0-9]*.md" -type f 2>/dev/null | sort)

            # Include completed
            while IFS= read -r file; do
                [[ -n "$file" ]] || continue
                display_issue_line "$file" "[completed]"
                ((count++))
            done < <(find "$completed_dir" -name "[0-9]*.md" -type f 2>/dev/null | sort)
            ;;
        pending)
            while IFS= read -r file; do
                [[ -n "$file" ]] || continue
                display_issue_line "$file"
                ((count++))
            done < <(find "$issues_dir" -maxdepth 1 -name "[0-9]*.md" -type f 2>/dev/null | sort)
            ;;
        completed)
            while IFS= read -r file; do
                [[ -n "$file" ]] || continue
                display_issue_line "$file"
                ((count++))
            done < <(find "$completed_dir" -name "[0-9]*.md" -type f 2>/dev/null | sort)
            ;;
        *)
            echo "Unknown status: $status"
            echo "Valid statuses: all, pending, completed"
            return 1
            ;;
    esac

    echo
    echo "Total: $count issue(s)"
}
# }}}

# -- {{{ display_issue_line
function display_issue_line() {
    local file="$1"
    local suffix="${2:-}"
    local name
    name=$(basename "$file")

    # Extract issue number and title
    local issue_num
    issue_num=$(echo "$name" | grep -oP '^\d{3}')

    local title
    title=$(echo "$name" | sed 's/^[0-9]*-//;s/\.md$//' | tr '-' ' ')

    printf "  %s: %s %s\n" "$issue_num" "$title" "$suffix"
}
# }}}

# -- {{{ create_issue
function create_issue() {
    local title="$1"

    if [[ -z "$title" ]]; then
        echo "ERROR: Issue title is required"
        return 1
    fi

    local issue_id
    issue_id=$(get_next_issue_id)

    # Generate filename from title
    local filename
    filename=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')

    # Remove leading/trailing dashes and collapse multiple dashes
    filename=$(echo "$filename" | sed 's/^-*//;s/-*$//;s/--*/-/g')

    local full_name="${issue_id}-${filename}.md"
    local issue_path="${DIR}/issues/${full_name}"

    # Check if file already exists
    if [[ -f "$issue_path" ]]; then
        echo "ERROR: Issue file already exists: $issue_path"
        return 1
    fi

    # Generate issue from template
    cat > "$issue_path" <<EOF
# Issue ${issue_id}: ${title}

## Current Behavior

{Describe the current state of the system. What exists? What doesn't work?}

## Intended Behavior

{Describe what the system should do after this issue is resolved.}

1. **Feature 1**: {Description}
2. **Feature 2**: {Description}

## Suggested Implementation Steps

### 1. {First Step}
\`\`\`bash
# Implementation outline
\`\`\`

### 2. {Second Step}
{Description}

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
- {Criterion that indicates the issue is complete}
EOF

    echo "Created: $issue_path"
    echo "Issue ID: $issue_id"
    echo
    echo "Next steps:"
    echo "  1. Edit the file to complete the issue specification"
    echo "  2. Add to docs/table-of-contents.md"
    echo "  3. Update issues/progress.md if appropriate"
}
# }}}

# -- {{{ validate_issue
function validate_issue() {
    local issue_file="$1"
    local errors=()
    local warnings=()

    if [[ ! -f "$issue_file" ]]; then
        echo "ERROR: File not found: $issue_file"
        return 1
    fi

    # Check for required sections
    grep -q "## Current Behavior" "$issue_file" || errors+=("Missing section: Current Behavior")
    grep -q "## Intended Behavior" "$issue_file" || errors+=("Missing section: Intended Behavior")
    grep -q "## Suggested Implementation" "$issue_file" || errors+=("Missing section: Suggested Implementation Steps")
    grep -q "## Metadata" "$issue_file" || errors+=("Missing section: Metadata")
    grep -q "## Success Criteria" "$issue_file" || errors+=("Missing section: Success Criteria")

    # Check metadata fields
    grep -q "\*\*Priority\*\*:" "$issue_file" || errors+=("Missing metadata: Priority")
    grep -q "\*\*Dependencies\*\*:" "$issue_file" || errors+=("Missing metadata: Dependencies")
    grep -q "\*\*Complexity\*\*:" "$issue_file" || warnings+=("Missing metadata: Complexity")
    grep -q "\*\*Impact\*\*:" "$issue_file" || warnings+=("Missing metadata: Impact")

    # Check for unfilled placeholders
    if grep -q "{Describe" "$issue_file" || grep -q "{Description}" "$issue_file"; then
        warnings+=("Contains unfilled template placeholders")
    fi

    local name
    name=$(basename "$issue_file")

    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "INVALID: $name"
        echo "  Errors:"
        printf "    - %s\n" "${errors[@]}"
        if [[ ${#warnings[@]} -gt 0 ]]; then
            echo "  Warnings:"
            printf "    - %s\n" "${warnings[@]}"
        fi
        return 1
    elif [[ ${#warnings[@]} -gt 0 ]]; then
        echo "VALID (with warnings): $name"
        echo "  Warnings:"
        printf "    - %s\n" "${warnings[@]}"
        return 0
    else
        echo "VALID: $name"
        return 0
    fi
}
# }}}

# -- {{{ complete_issue
function complete_issue() {
    local issue_file="$1"

    if [[ ! -f "$issue_file" ]]; then
        echo "ERROR: File not found: $issue_file"
        return 1
    fi

    # Validate first
    echo "Validating issue..."
    if ! validate_issue "$issue_file"; then
        echo
        echo "ERROR: Issue validation failed. Fix errors before completing."
        return 1
    fi

    local issue_name
    issue_name=$(basename "$issue_file")
    local completed_dir="${DIR}/issues/completed"

    # Move to completed
    echo
    echo "Moving to completed directory..."
    mv "$issue_file" "${completed_dir}/${issue_name}"
    echo "  Moved to: ${completed_dir}/${issue_name}"

    # Extract issue number for logging
    local issue_num
    issue_num=$(echo "$issue_name" | grep -oP '^\d{3}')

    echo
    echo "Issue $issue_num completed successfully!"
    echo
    echo "Remaining manual steps:"
    echo "  1. Update issues/progress.md to reflect completion"
    echo "  2. Update docs/table-of-contents.md if needed"
    echo "  3. Update any related issues"
    echo "  4. Commit changes to version control"
}
# }}}

# -- {{{ search_issues
function search_issues() {
    local term="$1"

    if [[ -z "$term" ]]; then
        echo "ERROR: Search term is required"
        return 1
    fi

    local issues_dir="${DIR}/issues"

    echo "Searching for: '$term'"
    echo "========================="

    local count=0
    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        local name
        name=$(basename "$file")
        local match_line
        match_line=$(grep -n -i "$term" "$file" | head -1)
        if [[ -n "$match_line" ]]; then
            local line_num
            line_num=$(echo "$match_line" | cut -d: -f1)
            echo "  $name (line $line_num)"
            ((count++))
        fi
    done < <(find "$issues_dir" -name "*.md" -type f 2>/dev/null)

    echo
    echo "Found: $count match(es)"
}
# }}}

# -- {{{ show_stats
function show_stats() {
    local issues_dir="${DIR}/issues"
    local completed_dir="${DIR}/issues/completed"

    local pending_count
    pending_count=$(find "$issues_dir" -maxdepth 1 -name "[0-9]*.md" -type f 2>/dev/null | wc -l)

    local completed_count
    completed_count=$(find "$completed_dir" -name "[0-9]*.md" -type f 2>/dev/null | wc -l)

    local phase1_count
    phase1_count=$(find "$issues_dir/phase-1" -name "*.md" -type f 2>/dev/null | wc -l)

    local phase2_count
    phase2_count=$(find "$issues_dir/phase-2" -name "*.md" -type f 2>/dev/null | wc -l)

    echo "Issue Statistics"
    echo "================"
    echo "  Pending issues:   $pending_count"
    echo "  Completed issues: $completed_count"
    echo "  Phase 1 issues:   $phase1_count"
    echo "  Phase 2 issues:   $phase2_count"
    echo
    echo "  Next issue ID:    $(get_next_issue_id)"
}
# }}}

# -- {{{ interactive_create_issue
function interactive_create_issue() {
    echo
    read -p "Enter issue title: " title

    if [[ -z "$title" ]]; then
        echo "Cancelled - no title provided"
        return 1
    fi

    create_issue "$title"
}
# }}}

# -- {{{ interactive_validate_issue
function interactive_validate_issue() {
    echo
    echo "Pending issues:"
    local issues=()
    local i=1
    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        issues+=("$file")
        printf "  %d. %s\n" "$i" "$(basename "$file")"
        ((i++))
    done < <(find "${DIR}/issues" -maxdepth 1 -name "[0-9]*.md" -type f 2>/dev/null | sort)

    if [[ ${#issues[@]} -eq 0 ]]; then
        echo "  No pending issues found"
        return 0
    fi

    echo
    read -p "Select issue to validate [1-${#issues[@]}]: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#issues[@]} )); then
        echo
        validate_issue "${issues[$((choice-1))]}"
    else
        echo "Invalid selection"
        return 1
    fi
}
# }}}

# -- {{{ interactive_complete_issue
function interactive_complete_issue() {
    echo
    echo "Pending issues:"
    local issues=()
    local i=1
    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        issues+=("$file")
        printf "  %d. %s\n" "$i" "$(basename "$file")"
        ((i++))
    done < <(find "${DIR}/issues" -maxdepth 1 -name "[0-9]*.md" -type f 2>/dev/null | sort)

    if [[ ${#issues[@]} -eq 0 ]]; then
        echo "  No pending issues found"
        return 0
    fi

    echo
    read -p "Select issue to complete [1-${#issues[@]}]: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#issues[@]} )); then
        echo
        complete_issue "${issues[$((choice-1))]}"
    else
        echo "Invalid selection"
        return 1
    fi
}
# }}}

# -- {{{ interactive_search
function interactive_search() {
    echo
    read -p "Enter search term: " term

    if [[ -z "$term" ]]; then
        echo "Cancelled - no search term provided"
        return 1
    fi

    echo
    search_issues "$term"
}
# }}}

# -- {{{ run_interactive_mode
function run_interactive_mode() {
    while true; do
        echo
        echo "=== Issue Management Utility ==="
        echo "  1. List pending issues"
        echo "  2. List completed issues"
        echo "  3. List all issues"
        echo "  4. Create new issue"
        echo "  5. Validate issue"
        echo "  6. Complete issue"
        echo "  7. Search issues"
        echo "  8. Show statistics"
        echo "  q. Quit"
        echo

        read -p "Select option: " choice

        case $choice in
            1) list_issues "pending" ;;
            2) list_issues "completed" ;;
            3) list_issues "all" ;;
            4) interactive_create_issue ;;
            5) interactive_validate_issue ;;
            6) interactive_complete_issue ;;
            7) interactive_search ;;
            8) show_stats ;;
            q|Q) echo "Exiting."; exit 0 ;;
            *) echo "Invalid selection" ;;
        esac
    done
}
# }}}

# -- {{{ show_help
function show_help() {
    echo "Usage: manage-issues.sh [COMMAND] [OPTIONS]"
    echo
    echo "Issue management utility for Delta-Version project."
    echo "Provides automated issue creation, validation, and completion."
    echo
    echo "Commands:"
    echo "  list [--status STATUS]      List issues (default: pending)"
    echo "  create TITLE                Create new issue with given title"
    echo "  validate FILE               Validate issue file structure"
    echo "  complete FILE               Complete and archive issue"
    echo "  search TERM                 Search issues by content"
    echo "  stats                       Show issue statistics"
    echo
    echo "Options:"
    echo "  --status STATUS   Filter by status: all, pending, completed"
    echo "  -I, --interactive Run in interactive mode"
    echo "  --help            Show this help message"
    echo
    echo "Examples:"
    echo "  manage-issues.sh list --status pending"
    echo "  manage-issues.sh create 'Add verbose flag to list-projects'"
    echo "  manage-issues.sh validate issues/031-new-feature.md"
    echo "  manage-issues.sh complete issues/030-issue-management.md"
    echo "  manage-issues.sh search 'gitignore'"
    echo "  manage-issues.sh -I"
}
# }}}

# -- {{{ main
function main() {
    local command=""
    local status="pending"
    local title=""
    local file=""
    local term=""

    # No arguments - run interactive
    if [[ $# -eq 0 ]]; then
        run_interactive_mode
        exit 0
    fi

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            list)
                command="list"
                shift
                ;;
            create)
                command="create"
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    title="$1"
                    shift
                fi
                ;;
            validate)
                command="validate"
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    file="$1"
                    shift
                fi
                ;;
            complete)
                command="complete"
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    file="$1"
                    shift
                fi
                ;;
            search)
                command="search"
                shift
                if [[ -n "$1" && "$1" != -* ]]; then
                    term="$1"
                    shift
                fi
                ;;
            stats)
                command="stats"
                shift
                ;;
            --status)
                status="$2"
                shift 2
                ;;
            -I|--interactive)
                run_interactive_mode
                exit 0
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                # Could be a title, file, or term for the current command
                if [[ "$command" == "create" && -z "$title" ]]; then
                    title="$1"
                elif [[ "$command" == "validate" && -z "$file" ]]; then
                    file="$1"
                elif [[ "$command" == "complete" && -z "$file" ]]; then
                    file="$1"
                elif [[ "$command" == "search" && -z "$term" ]]; then
                    term="$1"
                else
                    echo "Unknown argument: $1"
                    echo "Use --help for usage information"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Execute command
    case "$command" in
        list)
            list_issues "$status"
            ;;
        create)
            create_issue "$title"
            ;;
        validate)
            if [[ -z "$file" ]]; then
                echo "ERROR: File path required for validate command"
                exit 1
            fi
            validate_issue "$file"
            ;;
        complete)
            if [[ -z "$file" ]]; then
                echo "ERROR: File path required for complete command"
                exit 1
            fi
            complete_issue "$file"
            ;;
        search)
            search_issues "$term"
            ;;
        stats)
            show_stats
            ;;
        "")
            show_help
            ;;
        *)
            echo "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}
# }}}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
