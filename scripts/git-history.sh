#!/bin/bash
# git-history.sh
# Generates prettified commit logs segmented by project phase.
# Outputs human-readable markdown files preserving statistics and metadata.
# Project-abstract: works on any project following the issue naming convention.
#
# Usage:
#   ./git-history.sh [options]
#   ./git-history.sh -p 2          (generate for Phase 2)
#   ./git-history.sh -a            (generate for all phases)
#
# Options:
#   -d, --dir <path>    Project directory (default: current)
#   -o, --output <dir>  Output directory (default: docs/history)
#   -p, --phase <n>     Generate for specific phase
#   -a, --all           Generate for all detected phases
#   -s, --stats         Include detailed statistics
#   --since <date>      Only commits after date
#   --until <date>      Only commits before date
#   -I, --interactive   TUI mode for selecting phases
#   -h, --help          Show this help message
#
# Library usage:
#   source /path/to/scripts/git-history.sh
#   git_history_init "$PROJECT_DIR"
#   commits=$(git_history_get_phase_commits 2)
#   git_history_format_markdown "$commits" > output.md

set -euo pipefail

# {{{ Configuration
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
LIBS_DIR="${SCRIPT_DIR}/libs"

# Project config
PROJECT_DIR="$(pwd)"
OUTPUT_DIR=""
TARGET_PHASE=""
ALL_PHASES=false
INCLUDE_STATS=false
SINCE_DATE=""
UNTIL_DATE=""
INTERACTIVE=false

# Pattern for extracting phase from commit messages
# Default: "Issue XXX:" where first digit is phase
ISSUE_PATTERN='Issue ([A-Z]?[0-9]+)'
# }}}

# {{{ TUI Libraries
TUI_AVAILABLE=false
if [[ -f "${LIBS_DIR}/tui.sh" ]] && [[ -f "${LIBS_DIR}/menu.sh" ]]; then
    source "${LIBS_DIR}/tui.sh"
    source "${LIBS_DIR}/checkbox.sh"
    source "${LIBS_DIR}/multistate.sh"
    source "${LIBS_DIR}/input.sh"
    source "${LIBS_DIR}/menu.sh"
    TUI_AVAILABLE=true
fi
# }}}

# {{{ Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
# }}}

# {{{ show_help
show_help() {
    cat << 'EOF'
git-history.sh - Generate prettified commit logs by phase

USAGE:
    ./git-history.sh [options]

OPTIONS:
    -d, --dir <path>    Project directory (default: current)
    -o, --output <dir>  Output directory (default: docs/history)
    -p, --phase <n>     Generate for specific phase (0, 1, 2, A, etc.)
    -a, --all           Generate for all detected phases
    -s, --stats         Include detailed statistics
    --since <date>      Only commits after date (git date format)
    --until <date>      Only commits before date
    -I, --interactive   TUI mode for selecting phases
    -h, --help          Show this help message

EXAMPLES:
    ./git-history.sh -p 2              # Generate Phase 2 history
    ./git-history.sh -a -s             # All phases with stats
    ./git-history.sh --since "1 week"  # Recent commits only
    ./git-history.sh -I                # Interactive mode

OUTPUT:
    Creates docs/history/phase-X-commits.md for each phase.
    Files are formatted markdown suitable for reading and grepping.

EOF
}
# }}}

# {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                PROJECT_DIR="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -p|--phase)
                TARGET_PHASE="$2"
                shift 2
                ;;
            -a|--all)
                ALL_PHASES=true
                shift
                ;;
            -s|--stats)
                INCLUDE_STATS=true
                shift
                ;;
            --since)
                SINCE_DATE="$2"
                shift 2
                ;;
            --until)
                UNTIL_DATE="$2"
                shift 2
                ;;
            -I|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Set default output directory
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="${PROJECT_DIR}/docs/history"
    fi
}
# }}}

# {{{ git_history_init
# Initialize with project directory
git_history_init() {
    PROJECT_DIR="${1:-$(pwd)}"
    if [[ ! -d "${PROJECT_DIR}/.git" ]]; then
        echo "Error: Not a git repository: $PROJECT_DIR" >&2
        return 1
    fi
}
# }}}

# {{{ git_history_detect_phase
# Extract phase from commit message
# Returns: phase identifier (0, 1, 2, A, etc.) or empty
git_history_detect_phase() {
    local message="$1"

    # Try "Issue XXX:" pattern
    if [[ "$message" =~ $ISSUE_PATTERN ]]; then
        local issue_id="${BASH_REMATCH[1]}"
        # First character is phase
        echo "${issue_id:0:1}"
        return 0
    fi

    # Try "Phase X:" pattern
    if [[ "$message" =~ Phase[[:space:]]([A-Z0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    echo ""
}
# }}}

# {{{ git_history_get_phases
# Detect all phases present in commit history
git_history_get_phases() {
    local phases=()
    local seen=()

    local git_args=("log" "--oneline" "--all")
    [[ -n "$SINCE_DATE" ]] && git_args+=("--since=$SINCE_DATE")
    [[ -n "$UNTIL_DATE" ]] && git_args+=("--until=$UNTIL_DATE")

    while IFS= read -r line; do
        local phase=$(git_history_detect_phase "$line")
        if [[ -n "$phase" ]] && [[ ! " ${seen[*]} " =~ " $phase " ]]; then
            seen+=("$phase")
            phases+=("$phase")
        fi
    done < <(git -C "$PROJECT_DIR" "${git_args[@]}" 2>/dev/null)

    # Sort phases
    printf '%s\n' "${phases[@]}" | sort -u
}
# }}}

# {{{ git_history_get_phase_commits
# Get commit hashes for a specific phase
git_history_get_phase_commits() {
    local phase="$1"

    local git_args=("log" "--oneline" "--all" "--format=%H")
    [[ -n "$SINCE_DATE" ]] && git_args+=("--since=$SINCE_DATE")
    [[ -n "$UNTIL_DATE" ]] && git_args+=("--until=$UNTIL_DATE")

    while IFS= read -r hash; do
        local message=$(git -C "$PROJECT_DIR" log -1 --format="%s" "$hash" 2>/dev/null)
        local commit_phase=$(git_history_detect_phase "$message")
        if [[ "$commit_phase" == "$phase" ]]; then
            echo "$hash"
        fi
    done < <(git -C "$PROJECT_DIR" "${git_args[@]}" 2>/dev/null)
}
# }}}

# {{{ git_history_format_commit
# Format a single commit as markdown
git_history_format_commit() {
    local hash="$1"

    local short_hash=$(git -C "$PROJECT_DIR" log -1 --format="%h" "$hash")
    local subject=$(git -C "$PROJECT_DIR" log -1 --format="%s" "$hash")
    local author=$(git -C "$PROJECT_DIR" log -1 --format="%an" "$hash")
    local email=$(git -C "$PROJECT_DIR" log -1 --format="%ae" "$hash")
    local date=$(git -C "$PROJECT_DIR" log -1 --format="%ad" --date=short "$hash")
    local body=$(git -C "$PROJECT_DIR" log -1 --format="%b" "$hash")

    # Get file changes
    local files_changed=$(git -C "$PROJECT_DIR" diff-tree --no-commit-id --name-status -r "$hash" 2>/dev/null)
    local stats=$(git -C "$PROJECT_DIR" diff-tree --no-commit-id --stat "$hash" 2>/dev/null | tail -1)

    echo "## [$short_hash] $subject"
    echo ""
    echo "**Date:** $date | **Author:** $author <$email>"
    echo ""

    if [[ -n "$body" ]]; then
        echo "$body" | head -20
        echo ""
    fi

    if [[ -n "$files_changed" ]]; then
        echo "**Files changed:**"
        echo "\`\`\`"
        echo "$files_changed" | head -20
        if [[ $(echo "$files_changed" | wc -l) -gt 20 ]]; then
            echo "... ($(echo "$files_changed" | wc -l) files total)"
        fi
        echo "\`\`\`"
        echo ""
    fi

    if [[ -n "$stats" ]]; then
        echo "*$stats*"
        echo ""
    fi

    echo "---"
    echo ""
}
# }}}

# {{{ git_history_get_stats
# Get statistics for a phase
git_history_get_stats() {
    local phase="$1"
    local commits=$(git_history_get_phase_commits "$phase")
    local commit_count=0
    local insertions=0
    local deletions=0
    local files=0
    local first_date=""
    local last_date=""

    while IFS= read -r hash; do
        [[ -z "$hash" ]] && continue
        ((commit_count++))

        # Get date
        local date=$(git -C "$PROJECT_DIR" log -1 --format="%ad" --date=short "$hash")
        [[ -z "$first_date" ]] && first_date="$date"
        last_date="$date"

        # Get stats
        local stat_line=$(git -C "$PROJECT_DIR" diff-tree --no-commit-id --stat "$hash" 2>/dev/null | tail -1)
        if [[ "$stat_line" =~ ([0-9]+)[[:space:]]insertion ]]; then
            ((insertions += ${BASH_REMATCH[1]}))
        fi
        if [[ "$stat_line" =~ ([0-9]+)[[:space:]]deletion ]]; then
            ((deletions += ${BASH_REMATCH[1]}))
        fi
    done <<< "$commits"

    echo "commits=$commit_count"
    echo "insertions=$insertions"
    echo "deletions=$deletions"
    echo "first_date=$first_date"
    echo "last_date=$last_date"
}
# }}}

# {{{ git_history_format_markdown
# Generate full markdown document for a phase
git_history_format_markdown() {
    local phase="$1"
    local commits=$(git_history_get_phase_commits "$phase")
    local commit_count=$(echo "$commits" | grep -c . || echo 0)

    echo "# Phase $phase - Commit History"
    echo ""
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    if $INCLUDE_STATS; then
        local stats=$(git_history_get_stats "$phase")
        local s_commits=$(echo "$stats" | grep "commits=" | cut -d= -f2)
        local s_ins=$(echo "$stats" | grep "insertions=" | cut -d= -f2)
        local s_del=$(echo "$stats" | grep "deletions=" | cut -d= -f2)
        local s_first=$(echo "$stats" | grep "first_date=" | cut -d= -f2)
        local s_last=$(echo "$stats" | grep "last_date=" | cut -d= -f2)

        echo "## Statistics"
        echo ""
        echo "| Metric | Value |"
        echo "|--------|-------|"
        echo "| Commits | $s_commits |"
        echo "| Lines Added | +$s_ins |"
        echo "| Lines Removed | -$s_del |"
        echo "| Date Range | $s_first to $s_last |"
        echo ""
    fi

    echo "## Commits"
    echo ""
    echo "Total: $commit_count commits"
    echo ""
    echo "---"
    echo ""

    while IFS= read -r hash; do
        [[ -z "$hash" ]] && continue
        git_history_format_commit "$hash"
    done <<< "$commits"
}
# }}}

# {{{ generate_phase_history
# Generate history file for a phase
generate_phase_history() {
    local phase="$1"
    local output_file="${OUTPUT_DIR}/phase-${phase}-commits.md"

    mkdir -p "$OUTPUT_DIR"

    echo -e "${CYAN}Generating Phase $phase history...${NC}"

    git_history_format_markdown "$phase" > "$output_file"

    local commit_count=$(grep -c "^## \[" "$output_file" || echo 0)
    echo -e "${GREEN}✓${NC} Created $output_file ($commit_count commits)"
}
# }}}

# {{{ run_interactive
run_interactive() {
    if ! $TUI_AVAILABLE; then
        echo "TUI libraries not available. Using simple menu."
        echo ""

        # Get available phases
        echo "Detecting phases..."
        local phases=($(git_history_get_phases))

        if [[ ${#phases[@]} -eq 0 ]]; then
            echo "No phases detected in commit history."
            return 1
        fi

        echo "Available phases: ${phases[*]}"
        echo ""
        echo "Options:"
        echo "  a) Generate all phases"
        echo "  Enter phase number/letter to generate specific phase"
        echo "  q) Quit"
        echo ""
        read -p "Choice: " choice

        case "$choice" in
            a|A)
                for phase in "${phases[@]}"; do
                    generate_phase_history "$phase"
                done
                ;;
            q|Q)
                exit 0
                ;;
            *)
                if [[ " ${phases[*]} " =~ " $choice " ]]; then
                    generate_phase_history "$choice"
                else
                    echo "Invalid phase: $choice"
                    return 1
                fi
                ;;
        esac
        return 0
    fi

    # Full TUI mode
    tui_init
    menu_init

    menu_set_title "Git History Generator" "Select phases to export"

    # Detect phases
    local phases=($(git_history_get_phases))

    menu_add_section "phases" "multi" "Phases"
    for phase in "${phases[@]}"; do
        local count=$(git_history_get_phase_commits "$phase" | wc -l)
        menu_add_item "phases" "phase_$phase" "Phase $phase" "checkbox" "0" "$count commits"
    done

    menu_add_section "options" "multi" "Options"
    menu_add_item "options" "stats" "Include Statistics" "checkbox" "0" "Add detailed stats section"

    if menu_run; then
        tui_cleanup

        INCLUDE_STATS=$(menu_item_is_selected "options" "stats" && echo true || echo false)

        for phase in "${phases[@]}"; do
            if menu_item_is_selected "phases" "phase_$phase"; then
                generate_phase_history "$phase"
            fi
        done
    else
        tui_cleanup
        echo "Cancelled."
    fi
}
# }}}

# {{{ main
main() {
    parse_args "$@"
    git_history_init "$PROJECT_DIR"

    if $INTERACTIVE; then
        run_interactive
    elif $ALL_PHASES; then
        local phases=($(git_history_get_phases))
        if [[ ${#phases[@]} -eq 0 ]]; then
            echo "No phases detected in commit history."
            exit 1
        fi
        echo "Detected phases: ${phases[*]}"
        echo ""
        for phase in "${phases[@]}"; do
            generate_phase_history "$phase"
        done
    elif [[ -n "$TARGET_PHASE" ]]; then
        generate_phase_history "$TARGET_PHASE"
    else
        show_help
    fi
}
# }}}

# Only run main if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
