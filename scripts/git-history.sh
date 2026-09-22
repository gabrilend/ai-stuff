#!/bin/bash
# git-history.sh
# Generates prettified commit logs segmented by project phase.
# Outputs human-readable markdown files preserving statistics and metadata.
# Project-abstract: works on any project following the issue naming convention.
#
# How it decides which phase a commit belongs to: by the issue files the commit
# touched. Every piece of finished work edits its issue file and, at the end,
# moves it into issues/completed/; the issue's filename (or the phase-N/ folder
# it sits in) names its phase. Commit messages are not read for this, because
# the house style writes them in plain English with no issue numbers. Works for
# a project that is its own repository and for one folder of a monorepo; the
# statistics count only the lines changed inside the project folder.
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
#   git_history_format_markdown 2 > output.md

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
# Initialize with project directory. The project may be a whole repository or
# one folder inside a larger one (the ai-stuff monorepo holds thirty-odd
# projects in a single repository), so the repository root is asked of git
# rather than assumed to be the project folder itself.
git_history_init() {
    PROJECT_DIR="${1:-$(pwd)}"
    if ! REPO_ROOT="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel)"; then
        echo "Error: Not inside a git repository: $PROJECT_DIR" >&2
        return 1
    fi
    # Where the project's issues/ folder sits, spelled the way git spells paths
    # in its output (relative to the repository root, no leading slash).
    PROJECT_PREFIX="$(git -C "$PROJECT_DIR" rev-parse --show-prefix)"
    ISSUES_PREFIX="${PROJECT_PREFIX}issues/"
    if [[ ! -d "${PROJECT_DIR}/issues" ]]; then
        echo "Error: No issues/ folder in $PROJECT_DIR -- phases are read from issue files" >&2
        return 1
    fi
    git_history_index_commits
}
# }}}

# {{{ git_history_phase_of_issue_path
# Turn an issue file's path into the phase it belongs to.
#
# Why phases come from issue files and not from commit messages: this tool
# used to read "Issue 204:" or "Phase 2:" out of each commit subject. The
# house commit style changed to plain descriptive English (no issue numbers,
# no function names), after which no commit matched and every phase came out
# empty. What every completed piece of work still does, whatever its message
# says, is touch its issue file -- and the commit that finishes it moves that
# file into issues/completed/. The filename carries the phase.
#
# Filename shapes seen across the projects, and the phase each yields:
#   522-fix-update-script.md    three digits  -> first digit      (5)
#   1001-phase-10-intro.md      four digits   -> first two digits (10)
#   10-004-command-preview.md   digits-dash-  -> the part before the dash (10)
#   A03-unified-test-runner.md  a capital     -> the letter       (A)
#   042a-deferred-audits.md     sub-issue     -> as its parent    (0)
#   phase-1/004-extract.md      in a phase-N/ folder -> the folder (1)
# The folder rule comes first: delta-version files its early issues under
# phase-1/ and phase-2/ with plain three-digit numbers, and the folder is the
# author's more specific statement of which phase they meant.
# Anything else (progress files, CLAUDE.md, READMEs, folders of notes) is not
# an issue file and yields nothing.
#
# The four-digit rule is a convention, not a certainty: 1001 could also be read
# as phase 1, issue 001. It is written down in scripts/issues/A01 as an open
# question for the owner; until it is settled, four digits mean a two-digit
# phase because that is how the one project past phase 9 (soren-ds) named its
# files.
git_history_phase_of_issue_path() {
    local path="$1"
    local name="${path##*/}"
    [[ "$name" == *.md ]] || return 0
    local folder_phase=""
    if [[ "$path" =~ /phase-([0-9A-Z]+)/[^/]+$ ]]; then
        folder_phase="${BASH_REMATCH[1]}"
    fi
    if [[ -n "$folder_phase" ]] && [[ "$name" =~ ^[0-9A-Z]+[a-z]?- ]]; then
        echo "$folder_phase"
    elif [[ "$name" =~ ^([0-9]+)-[0-9]{3}[a-z]?- ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$name" =~ ^([A-Z])[0-9]+[a-z]?- ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$name" =~ ^([0-9]{2})[0-9]{2}[a-z]?- ]]; then
        echo "$((10#${BASH_REMATCH[1]}))"
    elif [[ "$name" =~ ^([0-9])[0-9]{2}[a-z]?- ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}
# }}}

# {{{ git_history_index_commits
# Read the project's issue-file history once and remember, for every commit,
# which phases it touched. One git call for the whole history, instead of one
# git call per commit, which is what made the old version slow on big repos.
#
# Fills two globals:
#   COMMIT_PHASES[hash]  = space-separated phases that commit touched
#   PHASE_ORDER          = every phase seen, sorted
# A commit that touches issue files of two phases belongs to both.
declare -gA COMMIT_PHASES=()
declare -ga PHASE_ORDER=()
declare -ga INDEXED_COMMITS=()
git_history_index_commits() {
    COMMIT_PHASES=()
    PHASE_ORDER=()
    INDEXED_COMMITS=()
    local git_args=("log" "--all" "--name-status" "-M" "--format=@@%H")
    [[ -n "$SINCE_DATE" ]] && git_args+=("--since=$SINCE_DATE")
    [[ -n "$UNTIL_DATE" ]] && git_args+=("--until=$UNTIL_DATE")
    git_args+=("--" "$ISSUES_PREFIX")

    local log_text
    log_text="$(git -C "$REPO_ROOT" "${git_args[@]}")"

    local hash="" line path phase
    local -A seen_phase=()
    while IFS= read -r line; do
        # "@@<hash>" starts a commit; the file lines follow it.
        if [[ "$line" == @@* ]]; then
            hash="${line#@@}"
            INDEXED_COMMITS+=("$hash")
            continue
        fi
        [[ -z "$line" || -z "$hash" ]] && continue
        # Status lines are "M<TAB>path" or, for a rename, "R100<TAB>old<TAB>new".
        # The last field is the path as it stands after the commit.
        path="${line##*$'\t'}"
        phase="$(git_history_phase_of_issue_path "$path")"
        [[ -z "$phase" ]] && continue
        if [[ " ${COMMIT_PHASES[$hash]:-} " != *" $phase "* ]]; then
            COMMIT_PHASES[$hash]="${COMMIT_PHASES[$hash]:-}${COMMIT_PHASES[$hash]:+ }$phase"
        fi
        seen_phase[$phase]=1
    done <<< "$log_text"

    if [[ ${#seen_phase[@]} -gt 0 ]]; then
        mapfile -t PHASE_ORDER < <(printf '%s\n' "${!seen_phase[@]}" | sort -V)
    fi
}
# }}}

# {{{ git_history_get_phases
# Every phase that has at least one commit touching one of its issue files.
git_history_get_phases() {
    [[ ${#PHASE_ORDER[@]} -gt 0 ]] && printf '%s\n' "${PHASE_ORDER[@]}"
    return 0
}
# }}}

# {{{ git_history_get_phase_commits
# Commit hashes (newest first) that touched an issue file of the given phase.
git_history_get_phase_commits() {
    local phase="$1"
    local hash
    for hash in "${INDEXED_COMMITS[@]}"; do
        if [[ " ${COMMIT_PHASES[$hash]:-} " == *" $phase "* ]]; then
            echo "$hash"
        fi
    done
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
    local files_changed=$(git -C "$PROJECT_DIR" diff-tree --relative --no-commit-id --name-status -r "$hash")
    local stats=$(git -C "$PROJECT_DIR" diff-tree --relative --no-commit-id --stat "$hash" | tail -1)

    echo "## [$short_hash] $subject"
    echo ""
    echo "**Date:** $date | **Author:** $author <$email>"
    echo ""

    if [[ -n "$body" ]]; then
        head -20 <<< "$body"
        echo ""
    fi

    if [[ -n "$files_changed" ]]; then
        echo "**Files changed:**"
        echo "\`\`\`"
        head -20 <<< "$files_changed"
        if [[ $(wc -l <<< "$files_changed") -gt 20 ]]; then
            echo "... ($(wc -l <<< "$files_changed") files total)"
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
        commit_count=$((commit_count + 1))

        # Get date
        local date=$(git -C "$PROJECT_DIR" log -1 --format="%ad" --date=short "$hash")
        # Commits arrive newest first, so the first date seen is the last one.
        [[ -z "$last_date" ]] && last_date="$date"
        first_date="$date"

        # Get stats
        local stat_line=$(git -C "$PROJECT_DIR" diff-tree --relative --no-commit-id --stat "$hash" | tail -1)
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
