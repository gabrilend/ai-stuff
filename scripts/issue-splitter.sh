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
#   -a, --archive         Save copies of analyses to issues/analysis/ directory
#   -x, --execute         Execute recommendations (create sub-issue files)
#   -X, --execute-all     Execute all recommendations without confirmation
#   -A, --auto-implement  Auto-implement issues via Claude CLI
#   --stream              Enable streaming mode with parallel processing
#   --parallel <n>        Max concurrent Claude calls (default: 3, requires --stream)
#   --delay <n>           Seconds between streamed outputs (default: 5)
#   -h, --help            Show this help message

set -euo pipefail

# {{{ TUI Libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBS_DIR="${SCRIPT_DIR}/libs"

# Source TUI libraries if available
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

# {{{ Configuration
DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
ISSUES_DIR="${DIR}/issues"
PATTERN="[0-9]*.md"
SKIP_EXISTING=false
REVIEW_ONLY=false
DRY_RUN=false
INTERACTIVE=false
ARCHIVE_MODE=false
ARCHIVE_DIR="${DIR}/issues/analysis"
EXECUTE_MODE=false
EXECUTE_ALL=false
AUTO_IMPLEMENT=false

# Track root issues that have sub-issues (for final review)
declare -a ROOTS_WITH_SUBS=()
# }}}

# {{{ Queue Configuration
QUEUE_DIR=""
QUEUE_COUNTER=0
STREAM_INDEX=0
STREAMER_PID=""
PARALLEL_COUNT=3
STREAM_DELAY=5
STREAMING_MODE=false
# }}}

# {{{ setup_queue
setup_queue() {
    QUEUE_DIR=$(mktemp -d)
    QUEUE_COUNTER=0
    STREAM_INDEX=0
    STREAMER_PID=""
}
# }}}

# {{{ cleanup_queue
cleanup_queue() {
    # Kill streamer process if running
    if [[ -n "$STREAMER_PID" ]]; then
        kill "$STREAMER_PID" 2>/dev/null || true
        wait "$STREAMER_PID" 2>/dev/null || true
        STREAMER_PID=""
    fi
    # Remove temp directory
    if [[ -n "$QUEUE_DIR" ]] && [[ -d "$QUEUE_DIR" ]]; then
        rm -rf "$QUEUE_DIR"
        QUEUE_DIR=""
    fi
}
# }}}

# Exit trap for queue cleanup
trap cleanup_queue EXIT INT TERM

# {{{ queue_claude_response
queue_claude_response() {
    local issue_path="$1"
    local prompt="$2"
    local queue_num=$((QUEUE_COUNTER++))
    local output_file="$QUEUE_DIR/${queue_num}.output"
    local meta_file="$QUEUE_DIR/${queue_num}.meta"

    # Store metadata (issue path)
    echo "$issue_path" > "$meta_file"

    # Run Claude and capture output
    if timeout 300 claude -p "$prompt" > "$output_file" 2>&1; then
        echo "success" >> "$meta_file"
    else
        echo "failed" >> "$meta_file"
    fi

    # Mark as ready (atomic signal)
    touch "$QUEUE_DIR/${queue_num}.ready"
}
# }}}

# {{{ stream_queue
stream_queue() {
    local done_file="$QUEUE_DIR/done"
    local stream_idx=0
    local idle_count=0
    local max_idle=25  # 5 seconds at 0.2s poll interval

    while true; do
        local ready_file="$QUEUE_DIR/${stream_idx}.ready"

        if [[ -f "$ready_file" ]]; then
            idle_count=0
            local output_file="$QUEUE_DIR/${stream_idx}.output"
            local meta_file="$QUEUE_DIR/${stream_idx}.meta"
            local issue_path
            local status
            issue_path=$(head -1 "$meta_file")
            status=$(tail -1 "$meta_file")
            local basename
            basename=$(basename "$issue_path")

            # Display header
            echo ""
            echo "┌─────────────────────────────────────────────────────────────"
            echo "│ Response for: $basename [$status]"
            echo "└─────────────────────────────────────────────────────────────"
            echo ""

            # Display content
            cat "$output_file"

            echo ""
            echo "─────────────────────────────────────────────────────────────────"

            ((++stream_idx))

            # Wait before next (the "divider") unless done
            if [[ ! -f "$done_file" ]] || [[ -f "$QUEUE_DIR/${stream_idx}.ready" ]]; then
                sleep "${STREAM_DELAY:-5}"
            fi
        else
            # Check termination: done file exists and no more items coming
            if [[ -f "$done_file" ]]; then
                ((++idle_count))
                if [[ $idle_count -ge $max_idle ]]; then
                    break
                fi
            fi
            # Poll interval
            sleep 0.2
        fi
    done
}
# }}}

# {{{ process_issue_parallel
process_issue_parallel() {
    local issue_path="$1"
    local prompt="$2"
    local queue_num=$((QUEUE_COUNTER++))
    local output_file="$QUEUE_DIR/${queue_num}.output"
    local meta_file="$QUEUE_DIR/${queue_num}.meta"
    local basename
    basename=$(basename "$issue_path")

    # Store metadata
    echo "$issue_path" > "$meta_file"

    # Run Claude and capture output
    local response=""
    if timeout 300 claude -p "$prompt" > "$output_file" 2>&1; then
        echo "success" >> "$meta_file"
        response=$(cat "$output_file")

        # Append analysis to issue file
        {
            echo ""
            echo "---"
            echo ""
            echo "## Sub-Issue Analysis"
            echo ""
            echo "*Generated by Claude Code on $(date '+%Y-%m-%d %H:%M')*"
            echo ""
            echo "$response"
        } >> "$issue_path"

        # Archive if enabled
        if [[ "$ARCHIVE_MODE" == true ]]; then
            mkdir -p "$ARCHIVE_DIR"
            local archive_file="${ARCHIVE_DIR}/${basename%.md}-analysis.md"
            echo "$response" > "$archive_file"
        fi
    else
        echo "failed" >> "$meta_file"
    fi

    # Signal ready for streamer
    touch "$QUEUE_DIR/${queue_num}.ready"
}
# }}}

# {{{ parallel_process_issues
parallel_process_issues() {
    local issues=("$@")
    local max_parallel="${PARALLEL_COUNT:-3}"
    local running=0
    local pids=()

    setup_queue

    # Start streamer in background
    stream_queue &
    STREAMER_PID=$!

    for issue in "${issues[@]}"; do
        local basename
        basename=$(basename "$issue")
        local root_id
        root_id=$(get_root_id "$basename")

        # Skip sub-issues
        if is_subissue "$basename"; then
            continue
        fi

        # Skip roots with sub-issues (track for Phase 2)
        if has_subissues "$root_id"; then
            ROOTS_WITH_SUBS+=("$issue")
            continue
        fi

        # Skip if already analyzed
        if [[ "$SKIP_EXISTING" == true ]]; then
            if has_subissue_analysis "$issue" || has_initial_analysis "$issue"; then
                continue
            fi
        fi

        # Wait if at max parallel
        while (( running >= max_parallel )); do
            wait -n 2>/dev/null || true
            ((--running)) || true
        done

        # Start processing in background
        (
            local prompt
            prompt=$(build_prompt "$issue")
            process_issue_parallel "$issue" "$prompt"
        ) &
        pids+=($!)
        ((++running))
    done

    # Wait for all producers to complete
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # Signal streamer we're done
    touch "$QUEUE_DIR/done"

    # Wait for streamer to finish
    wait "$STREAMER_PID" 2>/dev/null || true
}
# }}}

# {{{ print_help
print_help() {
    head -30 "$0" | tail -28 | sed 's/^# //' | sed 's/^#//'
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
                ARCHIVE_DIR="${DIR}/issues/analysis"
                shift 2
                ;;
            -a|--archive)
                ARCHIVE_MODE=true
                shift
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
            -x|--execute)
                EXECUTE_MODE=true
                shift
                ;;
            -X|--execute-all)
                EXECUTE_MODE=true
                EXECUTE_ALL=true
                shift
                ;;
            -A|--auto-implement)
                AUTO_IMPLEMENT=true
                shift
                ;;
            --stream)
                STREAMING_MODE=true
                shift
                ;;
            --parallel)
                PARALLEL_COUNT="$2"
                shift 2
                ;;
            --delay)
                STREAM_DELAY="$2"
                shift 2
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
    # Use precise pattern to avoid matching content inside code blocks
    # Must be at start of line and followed by newline (actual section header)
    grep -qE "^## Sub-Issue Analysis$" "$file" 2>/dev/null
}
# }}}

# {{{ has_structure_review
has_structure_review() {
    local file="$1"
    # Use precise pattern to avoid matching content inside code blocks
    grep -qE "^## Structure Review$" "$file" 2>/dev/null
}
# }}}

# {{{ has_generated_subissues
has_generated_subissues() {
    local file="$1"
    grep -qE "^## Generated Sub-Issues$" "$file" 2>/dev/null
}
# }}}

# {{{ has_initial_analysis
has_initial_analysis() {
    local file="$1"
    grep -qE "^## Initial Analysis$" "$file" 2>/dev/null
}
# }}}

# {{{ rename_analysis_to_initial
rename_analysis_to_initial() {
    local issue_path="$1"

    # Only rename if has Sub-Issue Analysis but not already renamed
    if grep -qE "^## Sub-Issue Analysis$" "$issue_path" && \
       ! grep -qE "^## Initial Analysis$" "$issue_path"; then
        sed -i 's/^## Sub-Issue Analysis$/## Initial Analysis/' "$issue_path"
        log "  Renamed analysis section to 'Initial Analysis'"
    fi
}
# }}}

# {{{ get_phase_name
get_phase_name() {
    local phase="$1"
    case "$phase" in
        0) echo "Tooling/Infrastructure" ;;
        1) echo "Foundation - File Format Parsing" ;;
        2) echo "Data Model - Game Objects" ;;
        3) echo "Logic Layer - Triggers and JASS" ;;
        4) echo "Runtime - Basic Engine Loop" ;;
        5) echo "Rendering - Visual Abstraction" ;;
        6) echo "Asset System - Community Content" ;;
        7) echo "Gameplay - Core Mechanics" ;;
        8) echo "Multiplayer - Network Layer" ;;
        9) echo "Polish - Tools and UX" ;;
        *) echo "Unknown Phase" ;;
    esac
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


# {{{ interactive_mode_tui
interactive_mode_tui() {
    # TUI-based interactive mode using menu.sh
    local issues
    mapfile -t issues < <(get_issues "$PATTERN")

    if [[ ${#issues[@]} -eq 0 ]]; then
        echo "ERROR: No issues found matching pattern '$PATTERN' in $ISSUES_DIR"
        exit 1
    fi

    # Initialize TUI - requires a real terminal
    if ! tui_init; then
        echo "ERROR: TUI initialization failed." >&2
        echo "Interactive mode requires a terminal (stdin/stdout must be TTY)." >&2
        echo "Run from a terminal, not a pipe or script." >&2
        exit 1
    fi

    # Build the menu
    menu_init
    menu_set_title "Issue Splitter" "Interactive Mode - Use j/k to navigate, space to toggle, r to run"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 1: Mode Selection (single/radio - only one can be active)
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "mode" "single" "Operation Mode"
    menu_add_item "mode" "analyze" "Analyze Issues" "checkbox" "1" \
        "Ask Claude to analyze issues and suggest sub-issue splits"
    menu_add_item "mode" "review" "Review Structures" "checkbox" "0" \
        "Review root issues that already have sub-issues"
    menu_add_item "mode" "execute" "Execute Recommendations" "checkbox" "0" \
        "Create sub-issue files from analysis recommendations"
    menu_add_item "mode" "implement" "Auto-Implement" "checkbox" "0" \
        "Invoke Claude CLI to implement the selected issues"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 2: Processing Options (multi - can select multiple)
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "processing" "multi" "Processing Options"
    menu_add_item "processing" "streaming" "Enable Streaming" "checkbox" "0" \
        "Process issues in parallel with real-time output"
    menu_add_item "processing" "skip_existing" "Skip Analyzed" "checkbox" "1" \
        "Don't re-analyze issues that already have analysis"
    menu_add_item "processing" "archive" "Archive Outputs" "checkbox" "0" \
        "Save copies of analyses to issues/analysis/"
    menu_add_item "processing" "execute_all" "No Confirmations" "checkbox" "0" \
        "Execute/implement without asking for confirmation"
    menu_add_item "processing" "dry_run" "Dry Run" "checkbox" "0" \
        "Show what would happen without actually doing it"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 3: Streaming Settings (inline editable flag values)
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "streaming" "multi" "Streaming Settings (type digits, →=default, ←=off)"
    menu_add_item "streaming" "parallel" "Parallel Jobs" "flag" "3:2" \
        "Max concurrent Claude calls (type 1-10)"
    menu_add_item "streaming" "delay" "Output Delay (sec)" "flag" "5:2" \
        "Seconds between streamed outputs (type 0-30)"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 4: Issue Selection (list - scrollable checkbox list)
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "files" "list" "Issues to Process (use 'a' for all, 'n' for none)"
    local i=0
    for issue in "${issues[@]}"; do
        local basename
        basename=$(basename "$issue")
        local root_id
        root_id=$(get_root_id "$basename")
        local issue_id
        issue_id=$(get_issue_id "$basename")
        local label="$basename"
        local desc=""
        local default="1"

        # Build description based on issue status
        if is_subissue "$basename"; then
            desc="[SUB] Part of issue ${root_id}"
            default="0"  # Sub-issues off by default
        elif has_subissues "$root_id"; then
            local sub_count
            sub_count=$(get_subissues_for_root "$root_id" | wc -l)
            desc="[ROOT+${sub_count}] Has ${sub_count} sub-issue(s) - will review"
        elif has_subissue_analysis "$issue" || has_initial_analysis "$issue"; then
            desc="[ANALYZED] Has existing analysis"
        elif has_generated_subissues "$issue"; then
            desc="[EXECUTED] Sub-issues already generated"
        else
            desc="[NEW] Ready for analysis"
        fi

        menu_add_item "files" "file_$i" "$label" "checkbox" "$default" "$desc"
        ((i++))
    done

    # Run the menu
    if menu_run; then
        tui_cleanup

        # ═══════════════════════════════════════════════════════════════════════
        # Extract mode selection (radio button behavior)
        # ═══════════════════════════════════════════════════════════════════════
        REVIEW_ONLY=false
        EXECUTE_MODE=false
        AUTO_IMPLEMENT=false

        if [[ "$(menu_get_value "review")" == "1" ]]; then
            REVIEW_ONLY=true
        elif [[ "$(menu_get_value "execute")" == "1" ]]; then
            EXECUTE_MODE=true
        elif [[ "$(menu_get_value "implement")" == "1" ]]; then
            AUTO_IMPLEMENT=true
        fi
        # Default: analyze mode (none of the above set)

        # ═══════════════════════════════════════════════════════════════════════
        # Extract processing options
        # ═══════════════════════════════════════════════════════════════════════
        STREAMING_MODE=false
        SKIP_EXISTING=false
        ARCHIVE_MODE=false
        EXECUTE_ALL=false
        DRY_RUN=false

        [[ "$(menu_get_value "streaming")" == "1" ]] && STREAMING_MODE=true
        [[ "$(menu_get_value "skip_existing")" == "1" ]] && SKIP_EXISTING=true
        [[ "$(menu_get_value "archive")" == "1" ]] && ARCHIVE_MODE=true
        [[ "$(menu_get_value "execute_all")" == "1" ]] && EXECUTE_ALL=true
        [[ "$(menu_get_value "dry_run")" == "1" ]] && DRY_RUN=true

        # ═══════════════════════════════════════════════════════════════════════
        # Extract streaming settings (0 = use default)
        # ═══════════════════════════════════════════════════════════════════════
        local parallel_val
        parallel_val=$(menu_get_value "parallel")
        # Use value if non-zero, otherwise keep default
        [[ -n "$parallel_val" ]] && [[ "$parallel_val" != "0" ]] && PARALLEL_COUNT="$parallel_val"

        local delay_val
        delay_val=$(menu_get_value "delay")
        # Use value if set (0 is valid for delay - means no delay)
        [[ -n "$delay_val" ]] && STREAM_DELAY="$delay_val"

        # ═══════════════════════════════════════════════════════════════════════
        # Extract selected files
        # ═══════════════════════════════════════════════════════════════════════
        SELECTED_ISSUES=()
        local j=0
        for issue in "${issues[@]}"; do
            if [[ "$(menu_get_value "file_$j")" == "1" ]]; then
                SELECTED_ISSUES+=("$issue")
            fi
            ((j++))
        done

        # ═══════════════════════════════════════════════════════════════════════
        # Display configuration summary
        # ═══════════════════════════════════════════════════════════════════════
        echo
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    Configuration Summary                      ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║ Directory: $(printf '%-49s' "$DIR")║"
        echo "║ Issues selected: $(printf '%-43s' "${#SELECTED_ISSUES[@]}")║"
        echo "╠══════════════════════════════════════════════════════════════╣"

        # Mode
        local mode_str="Analyze"
        [[ "$REVIEW_ONLY" == true ]] && mode_str="Review"
        [[ "$EXECUTE_MODE" == true ]] && mode_str="Execute"
        [[ "$AUTO_IMPLEMENT" == true ]] && mode_str="Implement"
        echo "║ Mode: $(printf '%-54s' "$mode_str")║"

        # Options
        local opts=""
        [[ "$STREAMING_MODE" == true ]] && opts+="streaming, "
        [[ "$SKIP_EXISTING" == true ]] && opts+="skip-existing, "
        [[ "$ARCHIVE_MODE" == true ]] && opts+="archive, "
        [[ "$EXECUTE_ALL" == true ]] && opts+="no-confirm, "
        [[ "$DRY_RUN" == true ]] && opts+="dry-run, "
        [[ -z "$opts" ]] && opts="(none)"
        opts="${opts%, }"  # Remove trailing comma
        echo "║ Options: $(printf '%-51s' "$opts")║"

        # Streaming settings
        if [[ "$STREAMING_MODE" == true ]]; then
            echo "║ Parallel: $(printf '%-50s' "$PARALLEL_COUNT jobs, ${STREAM_DELAY}s delay")║"
        fi

        echo "╚══════════════════════════════════════════════════════════════╝"
        echo
    else
        tui_cleanup
        echo
        echo "Cancelled by user."
        exit 0
    fi
}
# }}}

# {{{ interactive_mode
interactive_mode() {
    if [[ "$TUI_AVAILABLE" != true ]]; then
        echo "ERROR: TUI libraries not available." >&2
        echo "Expected libraries in: ${LIBS_DIR}/" >&2
        echo "Required: tui.sh, menu.sh, checkbox.sh, multistate.sh, input.sh" >&2
        exit 1
    fi
    interactive_mode_tui
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

    # Check if already has analysis (either form)
    if [[ "$SKIP_EXISTING" == true ]]; then
        if has_subissue_analysis "$issue_path" || has_initial_analysis "$issue_path"; then
            log "  Skipping (already has analysis)"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "  [DRY RUN] Would analyze for splitting"
        return 0
    fi

    # Build the prompt
    local prompt
    prompt=$(build_prompt "$issue_path")

    log "  Sending to Claude Code..."

    # Use claude with --print flag for non-interactive single response
    # Timeout after 5 minutes per issue
    local response
    if response=$(timeout 300 claude -p "$prompt" 2>&1); then
        # Append analysis directly to original issue
        {
            echo ""
            echo "---"
            echo ""
            echo "## Sub-Issue Analysis"
            echo ""
            echo "*Generated by Claude Code on $(date '+%Y-%m-%d %H:%M')*"
            echo ""
            echo "$response"
        } >> "$issue_path"

        log "  Analysis appended to issue"

        # Optionally save to archive
        if [[ "$ARCHIVE_MODE" == true ]]; then
            mkdir -p "$ARCHIVE_DIR"
            local archive_file="${ARCHIVE_DIR}/${basename%.md}-analysis.md"
            echo "$response" > "$archive_file"
            log "  Archived to: $archive_file"
        fi
    else
        log "  [ERROR] Claude Code failed or timed out"
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

    log "  Sending to Claude Code..."

    # Timeout after 5 minutes per review
    local response
    if response=$(timeout 300 claude -p "$prompt" 2>&1); then
        # Append review directly to root issue
        {
            echo ""
            echo "---"
            echo ""
            echo "## Structure Review"
            echo ""
            echo "*Generated by Claude Code on $(date '+%Y-%m-%d %H:%M')*"
            echo ""
            echo "$response"
        } >> "$root_path"

        log "  Review appended to issue"

        # Optionally save to archive
        if [[ "$ARCHIVE_MODE" == true ]]; then
            mkdir -p "$ARCHIVE_DIR"
            local archive_file="${ARCHIVE_DIR}/${basename%.md}-structure-review.md"
            echo "$response" > "$archive_file"
            log "  Archived to: $archive_file"
        fi
    else
        log "  [ERROR] Claude Code failed or timed out"
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

# {{{ parse_analysis
parse_analysis() {
    local issue_path="$1"

    # Extract Sub-Issue Analysis section (or Initial Analysis if renamed)
    # Stop at the next ## heading or end of file
    local section=""
    section=$(sed -n '/^## Sub-Issue Analysis$/,/^## /p' "$issue_path" 2>/dev/null | head -n -1)

    # If not found, try Initial Analysis
    if [[ -z "$section" ]]; then
        section=$(sed -n '/^## Initial Analysis$/,/^## /p' "$issue_path" 2>/dev/null | head -n -1)
    fi

    echo "$section"
}
# }}}

# {{{ extract_recommendations
extract_recommendations() {
    local analysis="$1"
    local -a recommendations=()

    # Parse table format: | 002a | add-queue-infrastructure | description |
    while IFS='|' read -r _ id name desc _; do
        id=$(echo "$id" | tr -d ' ')
        name=$(echo "$name" | tr -d ' ' | sed 's/^-//' | sed 's/-$//')
        if [[ "$id" =~ ^[0-9]+[a-z]+$ ]]; then
            recommendations+=("$id|$name|$desc")
        fi
    done <<< "$analysis"

    # Parse bold list format: - **002a-add-queue-infrastructure**: description
    # Or: **002a** | `add-queue-infrastructure` | description
    while IFS= read -r line; do
        # Format: **002a-name**: description
        if [[ "$line" =~ \*\*([0-9]+[a-z]+)-([^*]+)\*\*:?[[:space:]]*(.+) ]]; then
            local id="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]}"
            local desc="${BASH_REMATCH[3]}"
            recommendations+=("$id|$name|$desc")
        # Format: **002a** | `name` | description (table with backticks)
        elif [[ "$line" =~ \*\*([0-9]+[a-z]+)\*\*[[:space:]]*\|[[:space:]]*\`([^\`]+)\`[[:space:]]*\|[[:space:]]*(.+) ]]; then
            local id="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]}"
            local desc="${BASH_REMATCH[3]}"
            recommendations+=("$id|$name|$desc")
        fi
    done <<< "$analysis"

    # Remove duplicates and print
    printf '%s\n' "${recommendations[@]}" | sort -u
}
# }}}

# {{{ generate_subissue
generate_subissue() {
    local parent_path="$1"
    local id="$2"
    local name="$3"
    local description="$4"
    local dependencies="${5:-}"

    local parent_basename
    parent_basename=$(basename "$parent_path")
    local parent_id
    parent_id=$(get_root_id "$parent_basename")
    local phase=$((parent_id / 100))

    # Clean up name - remove leading/trailing dashes and spaces
    name=$(echo "$name" | sed 's/^[- ]*//' | sed 's/[- ]*$//' | tr ' ' '-')

    local filename="${id}-${name}.md"
    local filepath="${ISSUES_DIR}/${filename}"

    # Don't overwrite existing files
    if [[ -f "$filepath" ]]; then
        log "    Skipping $filename (already exists)"
        return 1
    fi

    # Convert name to title case for heading
    local title
    title=$(echo "${name//-/ }" | sed 's/\b\(.\)/\u\1/g')

    cat > "$filepath" << EOF
# Issue ${id}: ${title}

**Phase:** ${phase} - $(get_phase_name "$phase")
**Type:** Sub-Issue of ${parent_id}
**Priority:** Medium
**Dependencies:** ${dependencies:-"None"}

---

## Current Behavior

(To be filled in during implementation)

---

## Intended Behavior

${description}

---

## Suggested Implementation Steps

1. (To be determined based on analysis)

---

## Related Documents

- ${parent_basename} (parent issue)

---

## Acceptance Criteria

- [ ] (To be defined)

---

## Notes

*This sub-issue was auto-generated from analysis recommendations.*
*Review and expand before implementation.*
EOF

    log "    Created: $filename"
    return 0
}
# }}}

# {{{ execute_recommendations
execute_recommendations() {
    local issue_path="$1"
    local basename
    basename=$(basename "$issue_path")

    log "Executing recommendations for: $basename"

    # Skip if already has generated sub-issues
    if has_generated_subissues "$issue_path"; then
        log "  Skipping (already has generated sub-issues)"
        return 0
    fi

    # Check if has analysis
    if ! has_subissue_analysis "$issue_path"; then
        log "  Skipping (no analysis found)"
        return 0
    fi

    # Parse and extract recommendations
    local analysis
    analysis=$(parse_analysis "$issue_path")
    local -a recommendations=()
    mapfile -t recommendations < <(extract_recommendations "$analysis")

    # Filter out empty entries
    local -a valid_recommendations=()
    for rec in "${recommendations[@]}"; do
        if [[ -n "$rec" ]]; then
            valid_recommendations+=("$rec")
        fi
    done

    if [[ ${#valid_recommendations[@]} -eq 0 ]]; then
        log "  No sub-issue recommendations found in analysis"
        return 0
    fi

    log "  Found ${#valid_recommendations[@]} recommendation(s)"

    # Show recommendations and confirm (unless --execute-all)
    if [[ "$EXECUTE_ALL" != true ]] && [[ "$DRY_RUN" != true ]]; then
        echo ""
        echo "  Recommended sub-issues:"
        for rec in "${valid_recommendations[@]}"; do
            IFS='|' read -r id name desc <<< "$rec"
            echo "    - ${id}-${name}: ${desc:0:60}..."
        done
        echo ""
        read -p "  Create these sub-issues? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy] ]]; then
            log "  Skipped by user"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "  [DRY RUN] Would create ${#valid_recommendations[@]} sub-issue file(s)"
        return 0
    fi

    # Generate sub-issue files
    local created=0
    for rec in "${valid_recommendations[@]}"; do
        IFS='|' read -r id name desc <<< "$rec"
        if generate_subissue "$issue_path" "$id" "$name" "$desc"; then
            ((++created))
        fi
    done

    log "  Created $created sub-issue file(s)"

    # Update parent issue to note sub-issues were created
    if [[ $created -gt 0 ]]; then
        {
            echo ""
            echo "---"
            echo ""
            echo "## Generated Sub-Issues"
            echo ""
            echo "*Auto-generated on $(date '+%Y-%m-%d %H:%M')*"
            echo ""
            for rec in "${valid_recommendations[@]}"; do
                IFS='|' read -r id name desc <<< "$rec"
                name=$(echo "$name" | sed 's/^[- ]*//' | sed 's/[- ]*$//' | tr ' ' '-')
                echo "- ${id}-${name}.md"
            done
        } >> "$issue_path"

        log "  Updated parent issue with generated sub-issues list"

        # Rename "Sub-Issue Analysis" to "Initial Analysis" for clarity
        rename_analysis_to_initial "$issue_path"
    fi
}
# }}}

# {{{ build_implementation_prompt
build_implementation_prompt() {
    local issue_path="$1"
    local issue_content
    issue_content=$(cat "$issue_path")

    cat <<EOF
Please implement the following issue. Read the file carefully, understand
the current behavior, intended behavior, and suggested implementation steps.
Then write the code to complete each step.

After implementation:
1. Test that the changes work
2. Update the issue file with an implementation log section
3. Report what was done

Issue file: $issue_path

---

$issue_content
EOF
}
# }}}

# {{{ auto_implement_issue
auto_implement_issue() {
    local issue_path="$1"
    local basename
    basename=$(basename "$issue_path")

    log "Auto-implementing: $basename"

    # Check if claude CLI is available
    if ! command -v claude &> /dev/null; then
        error "claude CLI not found. Please install Claude Code."
        return 1
    fi

    # Build the prompt
    local prompt
    prompt=$(build_implementation_prompt "$issue_path")

    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY RUN] Would invoke claude with implementation prompt"
        echo "--- Prompt Preview (first 30 lines) ---"
        echo "$prompt" | head -30
        echo "..."
        echo "--- End Preview ---"
        return 0
    fi

    # Confirm unless --execute-all
    if [[ "$EXECUTE_ALL" != true ]]; then
        echo ""
        echo "About to invoke Claude CLI to implement: $basename"
        echo "This will allow Claude to read/write files autonomously."
        echo ""
        read -p "Proceed? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy] ]]; then
            log "  Skipped by user"
            return 0
        fi
    fi

    # Invoke claude CLI
    log "  Invoking Claude CLI..."
    echo "$prompt" | claude --dangerously-skip-permissions

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log "  Implementation completed successfully"
    else
        log "  Implementation exited with code $exit_code"
    fi

    return $exit_code
}
# }}}

# {{{ run_implement_phase
run_implement_phase() {
    echo
    echo "════════════════════════════════════════════════════════════════"
    log "PHASE: Auto-implementing issues via Claude CLI"
    echo "════════════════════════════════════════════════════════════════"
    echo

    local implemented=0
    local skipped=0

    for issue in "${SELECTED_ISSUES[@]}"; do
        if auto_implement_issue "$issue"; then
            ((++implemented))
        else
            ((++skipped))
        fi
    done

    echo
    log "Implementation complete: $implemented processed, $skipped skipped"
}
# }}}

# {{{ run_execute_phase
run_execute_phase() {
    echo
    echo "════════════════════════════════════════════════════════════════"
    log "PHASE 3: Executing analysis recommendations"
    echo "════════════════════════════════════════════════════════════════"
    echo

    local executed=0
    local skipped=0

    for issue in "${SELECTED_ISSUES[@]}"; do
        local basename
        basename=$(basename "$issue")

        # Skip sub-issues
        if is_subissue "$basename"; then
            continue
        fi

        if execute_recommendations "$issue"; then
            ((++executed))
        else
            ((++skipped))
        fi
        echo
    done

    log "Phase 3 complete: $executed processed, $skipped skipped"
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
        if [[ "$STREAMING_MODE" == true ]]; then
            log "PHASE 1: Analyzing issues (streaming mode, parallel=$PARALLEL_COUNT)"
        else
            log "PHASE 1: Analyzing issues for sub-issue splitting"
        fi
        echo "════════════════════════════════════════════════════════════════"
        echo

        if [[ "$STREAMING_MODE" == true ]]; then
            # Use parallel processing with streaming output
            parallel_process_issues "${SELECTED_ISSUES[@]}"
        else
            # Sequential processing
            for issue in "${SELECTED_ISSUES[@]}"; do
                if process_issue "$issue"; then
                    ((++processed))
                else
                    ((++skipped))
                fi
            done
            echo
            log "Phase 1 complete: $processed processed, $skipped skipped"
        fi
    else
        # In review-only mode, just find roots with sub-issues
        find_roots_with_subissues
    fi

    # Phase 2: Review root issues that have sub-issues
    run_final_review

    # Phase 3: Execute recommendations (create sub-issue files)
    if [[ "$EXECUTE_MODE" == true ]]; then
        run_execute_phase
    fi

    # Phase 4: Auto-implement issues via Claude CLI
    if [[ "$AUTO_IMPLEMENT" == true ]]; then
        run_implement_phase
    fi

    echo
    echo "════════════════════════════════════════════════════════════════"
    log "All done!"

    if [[ "$ARCHIVE_MODE" == true ]] && [[ -d "$ARCHIVE_DIR" ]]; then
        log "Archive copies saved to: $ARCHIVE_DIR"
    fi
}
# }}}

main "$@"
