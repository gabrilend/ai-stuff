#!/bin/bash
# issue-splitter.sh
# Iterates through issue files and asks Claude Code to suggest sub-issue splits.
# Responses are appended to each issue file as a "Sub-Issue Analysis" section.
#
# Behavior:
#   - Skips sub-issues (102a, 102b, etc.)
#   - Skips root issues that already have sub-issues (102 if 102a exists)
#   - After processing, reviews all root-with-sub-issues for further splitting
#
# Usage:
#   ./issue-splitter.sh [options]
#   ./issue-splitter.sh -I              (interactive mode)
#   ./issue-splitter.sh --dir /path     (override project directory)
#
# Options:
#   -d, --dir <path>      Project directory (default: script location)
#   -p, --pattern <glob>  Issue file pattern (default: "[0-9]*.md")
#   -s, --skip-existing   Skip issues that already have sub-issue analysis
#   -r, --review-only     Only run the final review pass (skip initial processing)
#   -n, --dry-run         Show what would be processed without running
#   -I, --interactive     Interactive mode for selecting options
#   -h, --help            Show this help message

set -euo pipefail

# {{{ Configuration
DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
ISSUES_DIR="${DIR}/issues"
PATTERN="[0-9]*.md"
SKIP_EXISTING=false
REVIEW_ONLY=false
DRY_RUN=false
INTERACTIVE=false
OUTPUT_DIR="${DIR}/issues/analysis"

# Track root issues that have sub-issues (for final review)
declare -a ROOTS_WITH_SUBS=()
# }}}

# {{{ print_help
print_help() {
    head -24 "$0" | tail -22 | sed 's/^# //' | sed 's/^#//'
}
# }}}

# {{{ log
log() {
    echo "[$(date '+%H:%M:%S')] $*"
}
# }}}

# {{{ error
error() {
    echo "[ERROR] $*" >&2
    exit 1
}
# }}}

# {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                DIR="$2"
                ISSUES_DIR="${DIR}/issues"
                OUTPUT_DIR="${DIR}/issues/analysis"
                shift 2
                ;;
            -p|--pattern)
                PATTERN="$2"
                shift 2
                ;;
            -s|--skip-existing)
                SKIP_EXISTING=true
                shift
                ;;
            -r|--review-only)
                REVIEW_ONLY=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -I|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}
# }}}

# {{{ get_issues
get_issues() {
    local pattern="$1"
    local issues=()

    while IFS= read -r -d '' file; do
        # Skip files in completed/ or analysis/ directories
        if [[ "$file" != *"/completed/"* ]] && [[ "$file" != *"/analysis/"* ]]; then
            issues+=("$file")
        fi
    done < <(find "$ISSUES_DIR" -maxdepth 1 -name "$pattern" -type f -print0 | sort -z)

    printf '%s\n' "${issues[@]}"
}
# }}}

# {{{ has_subissue_analysis
has_subissue_analysis() {
    local file="$1"
    grep -q "## Sub-Issue Analysis" "$file" 2>/dev/null
}
# }}}

# {{{ has_structure_review
has_structure_review() {
    local file="$1"
    grep -q "## Structure Review" "$file" 2>/dev/null
}
# }}}

# {{{ is_subissue
is_subissue() {
    local filename="$1"
    # Sub-issues have format like 102a-*, 102b-*, etc.
    [[ "$filename" =~ ^[0-9]+[a-z]- ]]
}
# }}}

# {{{ get_issue_id
get_issue_id() {
    local filename="$1"
    # Extract numeric ID from filename (e.g., "102" from "102-foo.md" or "102a" from "102a-bar.md")
    echo "$filename" | grep -oE '^[0-9]+[a-z]?' | head -1
}
# }}}

# {{{ get_root_id
get_root_id() {
    local filename="$1"
    # Extract root numeric ID (e.g., "102" from both "102-foo.md" and "102a-bar.md")
    echo "$filename" | grep -oE '^[0-9]+' | head -1
}
# }}}

# {{{ has_subissues
has_subissues() {
    local root_id="$1"
    # Check if any sub-issue files exist for this root (e.g., 102a-*, 102b-*)
    local subissue_pattern="${root_id}[a-z]-*.md"
    local count
    count=$(find "$ISSUES_DIR" -maxdepth 1 -name "$subissue_pattern" -type f 2>/dev/null | wc -l)
    [[ $count -gt 0 ]]
}
# }}}

# {{{ get_subissues_for_root
get_subissues_for_root() {
    local root_id="$1"
    local subissue_pattern="${root_id}[a-z]-*.md"
    find "$ISSUES_DIR" -maxdepth 1 -name "$subissue_pattern" -type f 2>/dev/null | sort
}
# }}}

# {{{ interactive_mode
interactive_mode() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           Issue Splitter - Interactive Mode                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    # Select directory
    echo "Project directory: $DIR"
    read -p "Use this directory? [Y/n]: " use_dir
    if [[ "$use_dir" =~ ^[Nn] ]]; then
        read -p "Enter project directory: " DIR
        ISSUES_DIR="${DIR}/issues"
        OUTPUT_DIR="${DIR}/issues/analysis"
    fi
    echo

    # List available issues with status
    echo "Available issues:"
    local issues
    mapfile -t issues < <(get_issues "$PATTERN")

    local i=1
    for issue in "${issues[@]}"; do
        local basename=$(basename "$issue")
        local root_id=$(get_root_id "$basename")
        local status=""

        if is_subissue "$basename"; then
            status=" [sub-issue of ${root_id}]"
        elif has_subissues "$root_id"; then
            status=" [has sub-issues - will skip, review at end]"
        elif has_subissue_analysis "$issue"; then
            status=" [has analysis]"
        fi
        echo "  [$i] $basename$status"
        ((i++))
    done
    echo "  [A] All eligible issues"
    echo "  [R] Review-only mode (just review existing sub-issue structures)"
    echo

    read -p "Select issues (comma-separated numbers, A, or R): " selection

    case "$selection" in
        [Aa])
            SELECTED_ISSUES=("${issues[@]}")
            ;;
        [Rr])
            REVIEW_ONLY=true
            SELECTED_ISSUES=("${issues[@]}")
            ;;
        *)
            SELECTED_ISSUES=()
            IFS=',' read -ra indices <<< "$selection"
            for idx in "${indices[@]}"; do
                idx=$(echo "$idx" | tr -d ' ')
                if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#issues[@]} )); then
                    SELECTED_ISSUES+=("${issues[$((idx-1))]}")
                fi
            done
            ;;
    esac
    echo

    if [[ "$REVIEW_ONLY" != true ]]; then
        # Skip existing?
        read -p "Skip issues that already have analysis? [Y/n]: " skip
        if [[ ! "$skip" =~ ^[Nn] ]]; then
            SKIP_EXISTING=true
        fi
        echo
    fi

    # Dry run?
    read -p "Dry run (show what would be processed)? [y/N]: " dry
    if [[ "$dry" =~ ^[Yy] ]]; then
        DRY_RUN=true
    fi
    echo

    echo "Configuration:"
    echo "  Directory: $DIR"
    echo "  Issues: ${#SELECTED_ISSUES[@]} selected"
    echo "  Skip existing: $SKIP_EXISTING"
    echo "  Review only: $REVIEW_ONLY"
    echo "  Dry run: $DRY_RUN"
    echo
    read -p "Proceed? [Y/n]: " proceed
    if [[ "$proceed" =~ ^[Nn] ]]; then
        echo "Aborted."
        exit 0
    fi
}
# }}}

# {{{ build_prompt
build_prompt() {
    local issue_path="$1"
    local issue_content
    issue_content=$(cat "$issue_path")

    cat <<EOF
Hello computer, all is well. Can you analyze this issue and suggest how it could be split into sub-issues?

For each suggested sub-issue, provide:
1. A suggested ID following the pattern {PARENT_ID}{letter} (e.g., if parent is 103, sub-issues are 103a, 103b, etc.)
2. A short dash-separated name
3. A brief description of what it covers
4. Dependencies on other sub-issues

If the issue is already small enough or doesn't benefit from splitting, say so.

Here is the issue file located at: $issue_path

---

$issue_content
EOF
}
# }}}

# {{{ build_review_prompt
build_review_prompt() {
    local root_path="$1"
    local basename=$(basename "$root_path")
    local root_id=$(get_root_id "$basename")

    local prompt="Hello computer, all is well. I have a root issue that already has sub-issues. Please review it and suggest:

1. Whether any existing sub-issues should be broken down further
2. Whether the root issue needs additional sub-issues to cover gaps
3. Any structural improvements to the sub-issue organization

For each suggestion, provide the issue ID and your recommendation.

Here is the root issue and its sub-issues:

═══════════════════════════════════════════════════════════════
ROOT ISSUE: $basename
═══════════════════════════════════════════════════════════════

$(cat "$root_path")

SUB-ISSUES:
"
    while IFS= read -r subissue; do
        if [[ -n "$subissue" ]]; then
            local sub_basename=$(basename "$subissue")
            prompt+="
───────────────────────────────────────────────────────────────
$sub_basename
───────────────────────────────────────────────────────────────

$(cat "$subissue")
"
        fi
    done < <(get_subissues_for_root "$root_id")

    echo "$prompt"
}
# }}}

# {{{ process_issue
process_issue() {
    local issue_path="$1"
    local basename
    basename=$(basename "$issue_path")
    local root_id
    root_id=$(get_root_id "$basename")

    log "Processing: $basename"

    # Skip sub-issues (they don't need further splitting in this pass)
    if is_subissue "$basename"; then
        log "  Skipping (is a sub-issue)"
        return 0
    fi

    # Skip root issues that already have sub-issues (will review at end)
    if has_subissues "$root_id"; then
        log "  Skipping (already has sub-issues: will review at end)"
        # Track for final review
        ROOTS_WITH_SUBS+=("$issue_path")
        return 0
    fi

    # Check if already has analysis
    if [[ "$SKIP_EXISTING" == true ]] && has_subissue_analysis "$issue_path"; then
        log "  Skipping (already has analysis)"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "  [DRY RUN] Would analyze for splitting"
        return 0
    fi

    # Build the prompt
    local prompt
    prompt=$(build_prompt "$issue_path")

    # Create output directory if needed
    mkdir -p "$OUTPUT_DIR"

    # Run claude-code and capture response
    local response_file="${OUTPUT_DIR}/${basename%.md}-analysis.md"
    log "  Sending to Claude Code..."

    # Use claude with --print flag for non-interactive single response
    # Timeout after 5 minutes per issue
    if timeout 300 claude -p "$prompt" > "$response_file" 2>&1; then
        log "  Response saved to: $response_file"

        # Append analysis to original issue
        {
            echo ""
            echo "---"
            echo ""
            echo "## Sub-Issue Analysis"
            echo ""
            echo "*Generated by Claude Code on $(date '+%Y-%m-%d %H:%M')*"
            echo ""
            cat "$response_file"
        } >> "$issue_path"

        log "  Analysis appended to issue"
    else
        log "  [ERROR] Claude Code failed or timed out"
        echo "ERROR: Failed to process $basename" >> "$response_file"
        return 1
    fi
}
# }}}

# {{{ find_roots_with_subissues
find_roots_with_subissues() {
    # Find all root issues that have sub-issues
    local issues
    mapfile -t issues < <(get_issues "$PATTERN")

    for issue in "${issues[@]}"; do
        local basename=$(basename "$issue")
        local root_id=$(get_root_id "$basename")

        # Only consider root issues (not sub-issues)
        if ! is_subissue "$basename"; then
            if has_subissues "$root_id"; then
                # Check if not already in array
                local found=false
                for existing in "${ROOTS_WITH_SUBS[@]:-}"; do
                    if [[ "$existing" == "$issue" ]]; then
                        found=true
                        break
                    fi
                done
                if [[ "$found" == false ]]; then
                    ROOTS_WITH_SUBS+=("$issue")
                fi
            fi
        fi
    done
}
# }}}

# {{{ review_root_issue
review_root_issue() {
    local root_path="$1"
    local basename
    basename=$(basename "$root_path")
    local root_id
    root_id=$(get_root_id "$basename")

    log "Reviewing: $basename"

    # Check if already has structure review
    if [[ "$SKIP_EXISTING" == true ]] && has_structure_review "$root_path"; then
        log "  Skipping (already has structure review)"
        return 0
    fi

    # Count sub-issues
    local sub_count
    sub_count=$(get_subissues_for_root "$root_id" | wc -l)
    log "  Found $sub_count sub-issue(s)"

    if [[ "$DRY_RUN" == true ]]; then
        log "  [DRY RUN] Would review structure"
        return 0
    fi

    # Build the review prompt
    local prompt
    prompt=$(build_review_prompt "$root_path")

    # Create output directory if needed
    mkdir -p "$OUTPUT_DIR"

    # Run claude-code and capture response
    local response_file="${OUTPUT_DIR}/${basename%.md}-structure-review.md"
    log "  Sending to Claude Code..."

    # Timeout after 5 minutes per review
    if timeout 300 claude -p "$prompt" > "$response_file" 2>&1; then
        log "  Response saved to: $response_file"

        # Append review to root issue
        {
            echo ""
            echo "---"
            echo ""
            echo "## Structure Review"
            echo ""
            echo "*Generated by Claude Code on $(date '+%Y-%m-%d %H:%M')*"
            echo ""
            cat "$response_file"
        } >> "$root_path"

        log "  Review appended to issue"
    else
        log "  [ERROR] Claude Code failed or timed out"
        echo "ERROR: Failed to review $basename" >> "$response_file"
        return 1
    fi
}
# }}}

# {{{ run_final_review
run_final_review() {
    if [[ ${#ROOTS_WITH_SUBS[@]} -eq 0 ]]; then
        log "No root issues with sub-issues to review"
        return 0
    fi

    echo
    echo "════════════════════════════════════════════════════════════════"
    log "PHASE 2: Reviewing ${#ROOTS_WITH_SUBS[@]} root issue(s) with existing sub-issues"
    echo "════════════════════════════════════════════════════════════════"
    echo

    local reviewed=0
    local skipped=0

    for root in "${ROOTS_WITH_SUBS[@]}"; do
        if review_root_issue "$root"; then
            ((++reviewed))
        else
            ((++skipped))
        fi
        echo
    done

    log "Phase 2 complete: $reviewed reviewed, $skipped skipped"
}
# }}}

# {{{ main
main() {
    parse_args "$@"

    # Verify claude command exists
    if ! command -v claude &> /dev/null; then
        error "claude command not found. Is Claude Code installed?"
    fi

    # Verify issues directory exists
    if [[ ! -d "$ISSUES_DIR" ]]; then
        error "Issues directory not found: $ISSUES_DIR"
    fi

    if [[ "$INTERACTIVE" == true ]]; then
        interactive_mode
    else
        # Get all matching issues
        mapfile -t SELECTED_ISSUES < <(get_issues "$PATTERN")
    fi

    local total=${#SELECTED_ISSUES[@]}
    if [[ $total -eq 0 ]]; then
        log "No issues found matching pattern: $PATTERN"
        exit 0
    fi

    log "Found $total issue(s)"
    echo

    local processed=0
    local skipped=0

    # Phase 1: Process issues without sub-issues (unless review-only mode)
    if [[ "$REVIEW_ONLY" != true ]]; then
        echo "════════════════════════════════════════════════════════════════"
        log "PHASE 1: Analyzing issues for sub-issue splitting"
        echo "════════════════════════════════════════════════════════════════"
        echo

        for issue in "${SELECTED_ISSUES[@]}"; do
            if process_issue "$issue"; then
                ((++processed))
            else
                ((++skipped))
            fi
        done

        echo
        log "Phase 1 complete: $processed processed, $skipped skipped"
    else
        # In review-only mode, just find roots with sub-issues
        find_roots_with_subissues
    fi

    # Phase 2: Review root issues that have sub-issues
    run_final_review

    echo
    echo "════════════════════════════════════════════════════════════════"
    log "All done!"

    if [[ "$DRY_RUN" == false ]] && [[ -d "$OUTPUT_DIR" ]]; then
        log "Analysis files saved to: $OUTPUT_DIR"
    fi
}
# }}}

main "$@"
