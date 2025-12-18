#!/usr/bin/env bash
# generate-history.sh - Generate readable history narratives from git log
#
# Creates HISTORY.txt files for each project that read like a story,
# with commits in chronological order (oldest first) and clean formatting.
# Supports multiple output formats (txt, md) and filtering options.

set -euo pipefail

# -- {{{ Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Output settings
OUTPUT_SUBDIR="docs"
OUTPUT_FILENAME="HISTORY.txt"
OUTPUT_FORMAT="txt"

# Filtering
MIN_COMMITS=1
SINCE_DATE=""
UNTIL_DATE=""
COMPLETED_ONLY=false
SKIP_SPECS=false

# Runtime options
DRY_RUN=false
VERBOSE=false
INTERACTIVE=false
ALL_PROJECTS=false
SPECIFIC_PROJECTS=()

# Output from generate_history_document
GENERATED_COMMIT_COUNT=0
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
    echo "[ERROR] $*" >&2
}
# }}}

# -- {{{ get_project_commits
get_project_commits() {
    local project_name="$1"
    local git_args=()

    git_args+=(log --reverse)

    # Format: hash, date, subject (body retrieved separately)
    git_args+=(--format='%H|%ci|%s')

    # Date filtering
    [[ -n "$SINCE_DATE" ]] && git_args+=(--since="$SINCE_DATE")
    [[ -n "$UNTIL_DATE" ]] && git_args+=(--until="$UNTIL_DATE")

    # Project path filter
    git_args+=(-- "${project_name}/")

    git -C "$DIR" "${git_args[@]}" 2>/dev/null || true
}
# }}}

# -- {{{ get_commit_body
get_commit_body() {
    local hash="$1"
    # Get just the body (everything after subject and blank line)
    git -C "$DIR" log -1 --format='%b' "$hash" 2>/dev/null || true
}
# }}}

# -- {{{ should_skip_commit
should_skip_commit() {
    local hash="$1"
    local project_name="$2"

    # Get files changed in this commit for this project
    # For root commits (no parent), use --root flag
    local changed_files
    local is_root
    is_root=$(git -C "$DIR" rev-parse --verify "${hash}^" 2>/dev/null || echo "root")

    if [[ "$is_root" == "root" ]]; then
        # Root commit - check if project files exist in tree
        changed_files=$(git -C "$DIR" ls-tree --name-only -r "$hash" -- "${project_name}/" 2>/dev/null)
    else
        changed_files=$(git -C "$DIR" diff-tree --no-commit-id --name-only -r "$hash" -- "${project_name}/" 2>/dev/null)
    fi

    if [[ -z "$changed_files" ]]; then
        return 0  # Skip - no files in this project
    fi

    # --completed-only: Only show commits touching issues/completed/
    if [[ "$COMPLETED_ONLY" == true ]]; then
        if ! echo "$changed_files" | grep -q "issues/completed/"; then
            return 0  # Skip - doesn't touch completed issues
        fi
    fi

    # --skip-specs: Hide commits that ONLY add issues/*.md (not completed/)
    if [[ "$SKIP_SPECS" == true ]]; then
        local non_spec_files
        non_spec_files=$(echo "$changed_files" | grep -v "^${project_name}/issues/[^/]*\.md$" | grep -v "^issues/[^/]*\.md$" || true)

        if [[ -z "$non_spec_files" ]]; then
            # All files are issue specs in root issues/ directory
            # Check if any are in completed/
            if ! echo "$changed_files" | grep -q "issues/completed/"; then
                log "Skipping spec-only commit: $hash"
                return 0  # Skip - only adds issue specs
            fi
        fi
    fi

    return 1  # Don't skip
}
# }}}

# -- {{{ format_commit_txt
format_commit_txt() {
    local index="$1"
    local date="$2"
    local subject="$3"
    local body="$4"

    # Extract just the date part (no time)
    local date_only="${date%% *}"

    echo "--------------------------------------------------------------------------------"
    echo ""
    echo "[$index] $subject"
    echo "    $date_only"
    echo ""

    # Format body with indentation if present
    if [[ -n "$body" ]]; then
        # Remove trailing whitespace and indent
        echo "$body" | sed 's/[[:space:]]*$//' | sed '/^$/d' | sed 's/^/    /'
        echo ""
    fi
}
# }}}

# -- {{{ format_commit_md
format_commit_md() {
    local index="$1"
    local date="$2"
    local subject="$3"
    local body="$4"

    # Extract just the date part (no time)
    local date_only="${date%% *}"

    echo "---"
    echo ""
    echo "## [$index] $subject"
    echo "**Date:** $date_only"
    echo ""

    # Body as-is for markdown
    if [[ -n "$body" ]]; then
        echo "$body" | sed 's/[[:space:]]*$//'
        echo ""
    fi
}
# }}}

# -- {{{ generate_header_txt
generate_header_txt() {
    local project_name="$1"
    local generated_date="$2"

    # Center the title
    local title="${project_name^^} - Development History"
    local padding=$(( (80 - ${#title}) / 2 ))
    [[ $padding -lt 0 ]] && padding=0

    cat <<EOF
================================================================================
$(printf '%*s' "$padding" '')$title
================================================================================

This document traces the development of $project_name from inception to present.
Generated: $generated_date

EOF
}
# }}}

# -- {{{ generate_header_md
generate_header_md() {
    local project_name="$1"
    local generated_date="$2"

    cat <<EOF
# ${project_name} - Development History

> This document traces the development of $project_name from inception to present.
> Generated: $generated_date

EOF
}
# }}}

# -- {{{ generate_footer_txt
generate_footer_txt() {
    local commit_count="$1"
    local first_date="$2"
    local last_date="$3"

    cat <<EOF
--------------------------------------------------------------------------------

================================================================================
                                 End of History
                              $commit_count commits recorded
EOF
    if [[ -n "$first_date" && -n "$last_date" ]]; then
        echo "                         ($first_date to $last_date)"
    fi
    echo "================================================================================"
}
# }}}

# -- {{{ generate_footer_md
generate_footer_md() {
    local commit_count="$1"
    local first_date="$2"
    local last_date="$3"

    echo "---"
    echo ""
    echo "*End of History - $commit_count commits recorded"
    if [[ -n "$first_date" && -n "$last_date" ]]; then
        echo "($first_date to $last_date)*"
    else
        echo "*"
    fi
}
# }}}

# -- {{{ generate_history_document
generate_history_document() {
    local project_name="$1"
    local generated_date
    generated_date=$(date '+%Y-%m-%d %H:%M:%S')

    local commit_count=0
    local first_date=""
    local last_date=""

    # Generate header
    case "$OUTPUT_FORMAT" in
        txt) generate_header_txt "$project_name" "$generated_date" ;;
        md)  generate_header_md "$project_name" "$generated_date" ;;
    esac

    # Process commits - parse pipe-separated records
    while IFS='|' read -r hash date subject; do
        [[ -z "$hash" ]] && continue

        # Get commit body separately
        local body
        body=$(get_commit_body "$hash")

        # Apply filters
        if should_skip_commit "$hash" "$project_name"; then
            continue
        fi

        ((++commit_count))

        # Track date range
        local date_only="${date%% *}"
        [[ -z "$first_date" ]] && first_date="$date_only"
        last_date="$date_only"

        # Format and output
        case "$OUTPUT_FORMAT" in
            txt) format_commit_txt "$commit_count" "$date" "$subject" "$body" ;;
            md)  format_commit_md "$commit_count" "$date" "$subject" "$body" ;;
        esac

    done < <(get_project_commits "$project_name")

    # Generate footer
    case "$OUTPUT_FORMAT" in
        txt) generate_footer_txt "$commit_count" "$first_date" "$last_date" ;;
        md)  generate_footer_md "$commit_count" "$first_date" "$last_date" ;;
    esac

    # Set global for caller to read
    GENERATED_COMMIT_COUNT="$commit_count"
}
# }}}

# -- {{{ get_commit_count
get_commit_count() {
    local project_name="$1"
    git -C "$DIR" log --oneline -- "${project_name}/" 2>/dev/null | wc -l
}
# }}}

# -- {{{ dry_run_report
dry_run_report() {
    local project_path="$1"
    local project_name
    project_name=$(basename "$project_path")

    # Determine output file
    local output_dir output_file extension
    case "$OUTPUT_FORMAT" in
        txt) extension="txt" ;;
        md)  extension="md" ;;
        *)   extension="txt" ;;
    esac

    output_dir="${project_path}/${OUTPUT_SUBDIR}"
    output_file="${output_dir}/${OUTPUT_FILENAME%.txt}.${extension}"

    echo "┌─────────────────────────────────────────────────────────────────────────────"
    echo "│ PROJECT: $project_name"
    echo "├─────────────────────────────────────────────────────────────────────────────"
    echo "│ Output:  $output_file"
    echo "│ Format:  $OUTPUT_FORMAT"
    echo "│"

    # Analyze commits
    local total_commits=0
    local included_commits=0
    local skipped_commits=0
    local first_date="" last_date=""
    local -a commit_subjects=()
    local -a skipped_subjects=()

    while IFS='|' read -r hash date subject; do
        [[ -z "$hash" ]] && continue

        ((++total_commits))
        local date_only="${date%% *}"

        if should_skip_commit "$hash" "$project_name"; then
            ((++skipped_commits))
            skipped_subjects+=("$subject")
        else
            ((++included_commits))
            [[ -z "$first_date" ]] && first_date="$date_only"
            last_date="$date_only"
            commit_subjects+=("$subject")
        fi
    done < <(get_project_commits "$project_name")

    echo "│ Commits: $included_commits included, $skipped_commits skipped (of $total_commits total)"

    if [[ -n "$first_date" && -n "$last_date" ]]; then
        echo "│ Range:   $first_date to $last_date"
    fi

    # Show filters if active
    if [[ "$COMPLETED_ONLY" == true || "$SKIP_SPECS" == true || -n "$SINCE_DATE" || -n "$UNTIL_DATE" ]]; then
        echo "│"
        echo "│ Active filters:"
        [[ "$COMPLETED_ONLY" == true ]] && echo "│   • --completed-only (only issues/completed/ commits)"
        [[ "$SKIP_SPECS" == true ]] && echo "│   • --skip-specs (hiding issue spec commits)"
        [[ -n "$SINCE_DATE" ]] && echo "│   • --since $SINCE_DATE"
        [[ -n "$UNTIL_DATE" ]] && echo "│   • --until $UNTIL_DATE"
    fi

    echo "│"
    echo "│ Commits to include:"

    if [[ ${#commit_subjects[@]} -eq 0 ]]; then
        echo "│   (none)"
    else
        local i=1
        for subject in "${commit_subjects[@]}"; do
            # Truncate long subjects
            if [[ ${#subject} -gt 55 ]]; then
                subject="${subject:0:52}..."
            fi
            printf "│   [%2d] %s\n" "$i" "$subject"
            ((++i))
            # Limit display to first 10 + summary
            if [[ $i -gt 10 && ${#commit_subjects[@]} -gt 10 ]]; then
                echo "│   ... and $((${#commit_subjects[@]} - 10)) more commits"
                break
            fi
        done
    fi

    if [[ ${#skipped_subjects[@]} -gt 0 ]]; then
        echo "│"
        echo "│ Commits skipped by filters:"
        local shown=0
        for subject in "${skipped_subjects[@]}"; do
            if [[ ${#subject} -gt 55 ]]; then
                subject="${subject:0:52}..."
            fi
            echo "│   ✗ $subject"
            ((++shown))
            if [[ $shown -ge 5 && ${#skipped_subjects[@]} -gt 5 ]]; then
                echo "│   ... and $((${#skipped_subjects[@]} - 5)) more skipped"
                break
            fi
        done
    fi

    echo "└─────────────────────────────────────────────────────────────────────────────"
    echo ""
}
# }}}

# -- {{{ process_project
process_project() {
    local project_path="$1"
    local project_name
    project_name=$(basename "$project_path")

    # Check if project has any commits
    local commit_count
    commit_count=$(get_commit_count "$project_name")

    if [[ "$commit_count" -lt "$MIN_COMMITS" ]]; then
        log "Skipping $project_name ($commit_count commits, min: $MIN_COMMITS)"
        return 0
    fi

    # Dry run mode - show detailed report
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_report "$project_path"
        return 0
    fi

    # Determine output file
    local output_dir output_file extension
    case "$OUTPUT_FORMAT" in
        txt) extension="txt" ;;
        md)  extension="md" ;;
        *)   extension="txt" ;;
    esac

    output_dir="${project_path}/${OUTPUT_SUBDIR}"
    output_file="${output_dir}/${OUTPUT_FILENAME%.txt}.${extension}"

    # Create output directory
    mkdir -p "$output_dir"

    echo "Generating: $project_name..."

    # Generate document (sets GENERATED_COMMIT_COUNT global)
    GENERATED_COMMIT_COUNT=0
    generate_history_document "$project_name" > "$output_file"

    echo "  Created: $output_file ($GENERATED_COMMIT_COUNT commits)"
}
# }}}

# -- {{{ process_all_projects
process_all_projects() {
    local projects_script="${DIR}/delta-version/scripts/list-projects.sh"

    if [[ ! -x "$projects_script" ]]; then
        error "Project listing script not found: $projects_script"
        return 1
    fi

    local total=0
    local processed=0

    while IFS= read -r project_path; do
        ((++total))
        process_project "$project_path"
        ((++processed))
    done < <("$projects_script" --paths)

    echo ""
    echo "=== Generation Complete ==="
    echo "Projects processed: $processed / $total"
}
# }}}

# -- {{{ interactive_select_projects
interactive_select_projects() {
    local projects_script="${DIR}/delta-version/scripts/list-projects.sh"

    if [[ ! -x "$projects_script" ]]; then
        error "Project listing script not found: $projects_script"
        return 1
    fi

    echo "Available projects:"
    echo ""

    local -a projects
    mapfile -t projects < <("$projects_script" --paths)

    if [[ ${#projects[@]} -eq 0 ]]; then
        error "No projects found"
        return 1
    fi

    local i=1
    for project in "${projects[@]}"; do
        local name commit_count
        name=$(basename "$project")
        commit_count=$(get_commit_count "$name")
        printf "  %2d) %-30s (%d commits)\n" "$i" "$name" "$commit_count"
        ((++i))
    done

    echo ""
    echo "Enter project numbers (comma-separated) or 'all': "
    read -r selection

    if [[ "$selection" == "all" ]]; then
        ALL_PROJECTS=true
        return 0
    fi

    # Parse comma-separated numbers
    IFS=',' read -ra selections <<< "$selection"
    for sel in "${selections[@]}"; do
        sel=$(echo "$sel" | tr -d ' ')
        if [[ "$sel" =~ ^[0-9]+$ ]] && [[ "$sel" -ge 1 ]] && [[ "$sel" -le ${#projects[@]} ]]; then
            SPECIFIC_PROJECTS+=("${projects[$((sel-1))]}")
        fi
    done

    if [[ ${#SPECIFIC_PROJECTS[@]} -eq 0 ]]; then
        error "No valid projects selected"
        return 1
    fi

    echo ""
    echo "Selected ${#SPECIFIC_PROJECTS[@]} project(s)"
}
# }}}

# -- {{{ show_help
show_help() {
    cat <<'EOF'
Usage: generate-history.sh [OPTIONS] [PROJECT...]

Generate readable history narrative files from git log.

Creates HISTORY.txt (or .md) files that present project development
as a story, with commits in chronological order (oldest first).

Options:
    -a, --all            Generate history for all projects
    -p, --project NAME   Generate history for specific project
    -o, --output DIR     Output subdirectory (default: docs)
    -f, --filename NAME  Output filename (default: HISTORY.txt)
    --format FORMAT      Output format: txt, md (default: txt)
    --since DATE         Only include commits after DATE
    --until DATE         Only include commits before DATE
    --min-commits N      Skip projects with fewer than N commits (default: 1)
    --completed-only     Only show commits touching issues/completed/
    --skip-specs         Hide commits that only add issues/*.md (not completed/)
    -n, --dry-run        Show what would be generated
    -v, --verbose        Show detailed progress
    -I, --interactive    Select projects interactively
    -h, --help           Show this help message

Output Format:
    The generated file reads like a story:
    - First commit at top, latest at bottom
    - Numbered commits: [1], [2], [3]...
    - Clean date display (YYYY-MM-DD)
    - Full commit messages with body text
    - Visual separators between commits

Examples:
    # Generate history for all projects
    generate-history.sh --all

    # Generate for specific project
    generate-history.sh --project delta-version

    # Generate markdown format
    generate-history.sh --all --format md

    # Only completed work (no planning commits)
    generate-history.sh --all --skip-specs

    # Recent history only
    generate-history.sh --all --since "2024-01-01"

    # Interactive selection
    generate-history.sh -I

    # Preview without creating files
    generate-history.sh --all --dry-run

EOF
}
# }}}

# -- {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)
                ALL_PROJECTS=true
                shift
                ;;
            -p|--project)
                SPECIFIC_PROJECTS+=("${DIR}/$2")
                shift 2
                ;;
            -o|--output)
                OUTPUT_SUBDIR="$2"
                shift 2
                ;;
            -f|--filename)
                OUTPUT_FILENAME="$2"
                shift 2
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --since)
                SINCE_DATE="$2"
                shift 2
                ;;
            --until)
                UNTIL_DATE="$2"
                shift 2
                ;;
            --min-commits)
                MIN_COMMITS="$2"
                shift 2
                ;;
            --completed-only)
                COMPLETED_ONLY=true
                shift
                ;;
            --skip-specs)
                SKIP_SPECS=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -I|--interactive)
                INTERACTIVE=true
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
                # Positional argument - treat as project name
                if [[ -d "${DIR}/$1" ]]; then
                    SPECIFIC_PROJECTS+=("${DIR}/$1")
                elif [[ -d "$1" ]]; then
                    SPECIFIC_PROJECTS+=("$1")
                else
                    error "Project not found: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done
}
# }}}

# -- {{{ main
main() {
    parse_args "$@"

    # Validate format
    case "$OUTPUT_FORMAT" in
        txt|md) ;;
        html)
            error "HTML format not yet implemented"
            exit 1
            ;;
        *)
            error "Unknown format: $OUTPUT_FORMAT (use txt or md)"
            exit 1
            ;;
    esac

    # Interactive mode
    if [[ "$INTERACTIVE" == true ]]; then
        if ! interactive_select_projects; then
            exit 1
        fi
    fi

    # Determine what to process
    if [[ "$ALL_PROJECTS" == true ]]; then
        process_all_projects
    elif [[ ${#SPECIFIC_PROJECTS[@]} -gt 0 ]]; then
        for project in "${SPECIFIC_PROJECTS[@]}"; do
            process_project "$project"
        done
        echo ""
        echo "=== Generation Complete ==="
        echo "Projects processed: ${#SPECIFIC_PROJECTS[@]}"
    else
        error "No projects specified"
        echo ""
        echo "Use --all to process all projects, --project NAME for specific projects,"
        echo "or --interactive to select from a list."
        echo ""
        show_help
        exit 1
    fi
}
# }}}

main "$@"
