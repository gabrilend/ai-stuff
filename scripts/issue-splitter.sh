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
#   -C, --clear           Clear analysis sections from issue files (no Claude)
#   -F, --feedback        Enable interactive feedback loop with Claude
#   -S, --session         Reuse Claude context across issues (sequential only)
#   -E, --expert          Fresh context per issue for focused analysis (default)
#   --max-rounds <n>      Max feedback rounds per issue (default: 10)
#   --stream              Enable streaming mode with parallel processing
#   --parallel <n>        Max concurrent Claude calls (default: 3, requires --stream)
#   --delay <n>           Seconds between streamed outputs (default: 5)
#   -h, --help            Show this help message

set -euo pipefail

# {{{ TUI Libraries
# Resolve symlinks to find actual script location
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
LIBS_DIR="${SCRIPT_DIR}/libs"

# Source TUI libraries if available
TUI_AVAILABLE=false
if [[ -f "${LIBS_DIR}/lua-menu.sh" ]] && command -v luajit &>/dev/null; then
    # Use Lua-based menu for stable rendering (fixes off-by-one bug in bash TUI)
    source "${LIBS_DIR}/lua-menu.sh"
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
CLEAR_MODE=false         # Clear analysis sections from issue files
FEEDBACK_MODE=false      # Interactive feedback loop with Claude
MAX_FEEDBACK_ROUNDS=10   # Safety limit on conversation rounds
SESSION_MODE=false       # Reuse Claude context across issues (--continue)
EXPERT_MODE=false        # Fresh context per issue (explicit default)
SESSION_STARTED=false    # Track if first call has been made in session mode

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

# {{{ handle_interrupt
# Handle Ctrl+C - cleanup and exit immediately
handle_interrupt() {
    cleanup_queue
    # Reset terminal in case we were in raw mode
    stty sane 2>/dev/null || true
    echo ""
    echo "Interrupted."
    exit 130
}
# }}}

# Trap EXIT for normal cleanup, INT/TERM for immediate exit
trap cleanup_queue EXIT
trap handle_interrupt INT TERM

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
    # Note: Parallel mode always uses fresh context (--session not compatible)
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
    # Note: Parallel mode always uses fresh context (--session not compatible with parallel)
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
            -C|--clear)
                CLEAR_MODE=true
                shift
                ;;
            -F|--feedback)
                FEEDBACK_MODE=true
                shift
                ;;
            -S|--session)
                SESSION_MODE=true
                shift
                ;;
            -E|--expert)
                EXPERT_MODE=true
                shift
                ;;
            --max-rounds)
                MAX_FEEDBACK_ROUNDS="$2"
                shift 2
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

# {{{ is_text_file
is_text_file() {
    # Check if first ~100 bytes are ASCII (printable + whitespace)
    # Returns 0 if text, 1 if binary
    local file="$1"
    local sample
    sample=$(head -c 100 "$file" 2>/dev/null | tr -d '[:print:][:space:]')
    # If removing printable chars + whitespace leaves nothing, it's text
    [[ -z "$sample" ]]
}
# }}}

# {{{ get_issues
get_issues() {
    local pattern="$1"
    local issues=()
    local -A seen=()  # Track unique files by basename

    # First pass: find files matching the exact pattern
    while IFS= read -r -d '' file; do
        if [[ "$file" != *"/completed/"* ]] && [[ "$file" != *"/analysis/"* ]]; then
            local base
            base=$(basename "$file")
            if [[ -z "${seen[$base]:-}" ]]; then
                issues+=("$file")
                seen[$base]=1
            fi
        fi
    done < <(find "$ISSUES_DIR" -maxdepth 1 -name "$pattern" -type f -print0 2>/dev/null | sort -z)

    # Second pass: if pattern ends with .md, also check for extension-less files
    # This handles projects where issue files don't have .md extension
    if [[ "$pattern" == *.md ]]; then
        local base_pattern="${pattern%.md}"
        while IFS= read -r -d '' file; do
            if [[ "$file" != *"/completed/"* ]] && [[ "$file" != *"/analysis/"* ]]; then
                local base
                base=$(basename "$file")
                # Skip if already found (with .md) or if it has any extension
                if [[ -z "${seen[$base]:-}" ]] && [[ "$base" != *.* ]]; then
                    # Validate it's a text file, not binary
                    if is_text_file "$file"; then
                        issues+=("$file")
                        seen[$base]=1
                    fi
                fi
            fi
        done < <(find "$ISSUES_DIR" -maxdepth 1 -name "$base_pattern" -type f -print0 2>/dev/null | sort -z)
    fi

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
        "Ask Claude to analyze issues and suggest sub-issue splits" "a" ""
    menu_add_item "mode" "feedback" "Feedback Loop" "checkbox" "0" \
        "Interactive Q&A with Claude until analysis is complete" "f" "-F"
    menu_add_item "mode" "review" "Review Structures" "checkbox" "0" \
        "Review root issues that already have sub-issues" "r" "-r"
    menu_add_item "mode" "execute" "Execute Recommendations" "checkbox" "0" \
        "Create sub-issue files from analysis recommendations" "x" "-x"
    menu_add_item "mode" "implement" "Auto-Implement" "checkbox" "0" \
        "Invoke Claude CLI to implement the selected issues" "m" "-A"
    menu_add_item "mode" "clear" "Clear Analysis" "checkbox" "0" \
        "Remove analysis sections from issue files (no Claude)" "l" "-C"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 2: Processing Options (multi - can select multiple)
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "processing" "multi" "Processing Options"
    menu_add_item "processing" "streaming" "Enable Streaming" "checkbox" "0" \
        "Process issues in parallel with real-time output" "s" "--stream"
    menu_add_item "processing" "skip_existing" "Skip Analyzed" "checkbox" "1" \
        "Don't re-analyze issues that already have analysis" "p" "-s"
    menu_add_item "processing" "archive" "Archive Outputs" "checkbox" "0" \
        "Save copies of analyses to issues/analysis/" "c" "-a"
    menu_add_item "processing" "execute_all" "No Confirmations" "checkbox" "0" \
        "Execute/implement without asking for confirmation" "n" "-X"
    menu_add_item "processing" "dry_run" "Dry Run" "checkbox" "0" \
        "Show what would happen without actually doing it" "d" "-n"
    menu_add_item "processing" "session" "Session Mode" "checkbox" "0" \
        "Reuse Claude context across issues (faster, sequential only)" "e" "-S"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 3: Streaming Settings (inline editable flag values)
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "streaming" "multi" "Streaming Settings (type digits, >=default, <=off)"
    menu_add_item "streaming" "parallel" "Parallel Jobs" "flag" "3:2" \
        "Max concurrent Claude calls (type 1-10)" "" "--parallel"
    menu_add_item "streaming" "delay" "Output Delay (sec)" "flag" "5:2" \
        "Seconds between streamed outputs (type 0-30)" "" "--delay"

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
        # Set file path for preview when this item is selected
        menu_set_item_filepath "file_$i" "$issue"
        ((++i))  # Pre-increment to avoid exit code 1 when i=0
    done

    # ═══════════════════════════════════════════════════════════════════════════
    # Content Preview: Show first N lines of selected issue file
    # Uses remaining screen space, separated by dashed box-drawing line
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_content_source "item_file" "" ""

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 5: Command Preview (shows the command that will be executed)
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "preview" "multi" "Command Preview"
    menu_add_item "preview" "cmd_preview" "" "text" "" \
        "The command that will be executed (press ~ to copy to clipboard)"

    # Configure command preview
    menu_set_command_config "./issue-splitter.sh" "cmd_preview" "files"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 6: Actions (execute button)
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "actions" "single" "Actions"
    menu_add_item "actions" "run" "Run Selected Operations" "action" "" \
        "Execute the selected mode with chosen options and files"

    # ═══════════════════════════════════════════════════════════════════════════
    # Dependencies: disable options that don't apply based on mode selection
    # ═══════════════════════════════════════════════════════════════════════════
    # "No Confirmations" only relevant when execute or implement mode is selected
    menu_add_dependency_multi "execute_all" "execute:1 implement:1" "false" \
        "Only applies to Execute or Implement modes" "yellow"

    # "Feedback Loop" and "Streaming" are mutually exclusive
    # (feedback is interactive Q&A, streaming is parallel batch processing)
    menu_add_dependency "feedback" "streaming" "1" "true" \
        "Incompatible with Streaming (feedback is interactive)" "yellow"
    menu_add_dependency "streaming" "feedback" "1" "true" \
        "Incompatible with Feedback Loop (streaming is batch processing)" "yellow"

    # "Session Mode" is incompatible with streaming (parallel processing)
    menu_add_dependency "session" "streaming" "1" "true" \
        "Incompatible with Streaming (parallel workers can't share context)" "yellow"

    # "Parallel Jobs" and "Output Delay" only apply when streaming is enabled
    # (these cascade-disable when streaming is disabled by feedback loop)
    menu_add_dependency "parallel" "streaming" "1" "false" \
        "Requires Streaming mode to be enabled" "yellow"
    menu_add_dependency "delay" "streaming" "1" "false" \
        "Requires Streaming mode to be enabled" "yellow"

    # "Clear Analysis" mode doesn't use Claude - disable Claude-related options
    menu_add_dependency "streaming" "clear" "1" "true" \
        "Clear mode doesn't use Claude" "yellow"
    menu_add_dependency "skip_existing" "clear" "1" "true" \
        "Clear mode doesn't use Claude" "yellow"
    menu_add_dependency "archive" "clear" "1" "true" \
        "Clear mode doesn't use Claude" "yellow"
    menu_add_dependency "session" "clear" "1" "true" \
        "Clear mode doesn't use Claude" "yellow"

    # "Execute Recommendations" mode only processes issues WITH analysis
    # Skipping analyzed issues would skip the only ones that can be executed
    menu_add_dependency "skip_existing" "execute" "1" "true" \
        "Execute mode requires analysis (would skip processable issues)" "yellow"

    # Run the menu
    if menu_run; then
        tui_cleanup

        # ═══════════════════════════════════════════════════════════════════════
        # Extract mode selection (radio button behavior)
        # ═══════════════════════════════════════════════════════════════════════
        REVIEW_ONLY=false
        EXECUTE_MODE=false
        AUTO_IMPLEMENT=false
        CLEAR_MODE=false
        FEEDBACK_MODE=false

        if [[ "$(menu_get_value "feedback")" == "1" ]]; then
            FEEDBACK_MODE=true
        elif [[ "$(menu_get_value "review")" == "1" ]]; then
            REVIEW_ONLY=true
        elif [[ "$(menu_get_value "execute")" == "1" ]]; then
            EXECUTE_MODE=true
        elif [[ "$(menu_get_value "implement")" == "1" ]]; then
            AUTO_IMPLEMENT=true
        elif [[ "$(menu_get_value "clear")" == "1" ]]; then
            CLEAR_MODE=true
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
        SESSION_MODE=false

        [[ "$(menu_get_value "streaming")" == "1" ]] && STREAMING_MODE=true
        [[ "$(menu_get_value "skip_existing")" == "1" ]] && SKIP_EXISTING=true
        [[ "$(menu_get_value "archive")" == "1" ]] && ARCHIVE_MODE=true
        [[ "$(menu_get_value "execute_all")" == "1" ]] && EXECUTE_ALL=true
        [[ "$(menu_get_value "dry_run")" == "1" ]] && DRY_RUN=true
        [[ "$(menu_get_value "session")" == "1" ]] && SESSION_MODE=true

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
            ((++j))
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
        [[ "$FEEDBACK_MODE" == true ]] && mode_str="Feedback Loop"
        [[ "$REVIEW_ONLY" == true ]] && mode_str="Review"
        [[ "$EXECUTE_MODE" == true ]] && mode_str="Execute"
        [[ "$AUTO_IMPLEMENT" == true ]] && mode_str="Implement"
        [[ "$CLEAR_MODE" == true ]] && mode_str="Clear Analysis"
        echo "║ Mode: $(printf '%-54s' "$mode_str")║"

        # Options
        local opts=""
        [[ "$STREAMING_MODE" == true ]] && opts+="streaming, "
        [[ "$SKIP_EXISTING" == true ]] && opts+="skip-existing, "
        [[ "$ARCHIVE_MODE" == true ]] && opts+="archive, "
        [[ "$EXECUTE_ALL" == true ]] && opts+="no-confirm, "
        [[ "$DRY_RUN" == true ]] && opts+="dry-run, "
        [[ "$SESSION_MODE" == true ]] && opts+="session, "
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

# {{{ call_claude
# Wrapper to invoke Claude with appropriate session/expert mode flags
# Session mode: reuse context across calls with --continue
# Expert mode: fresh context per call (default behavior)
call_claude() {
    local prompt="$1"
    local timeout_seconds="${2:-300}"

    if [[ "$SESSION_MODE" == true ]] && [[ "$SESSION_STARTED" == true ]]; then
        # Continue previous conversation to reuse context
        # Claude won't need to re-read project files
        timeout "$timeout_seconds" claude --continue -p "$prompt" 2>&1
    else
        # Fresh context (expert mode or first call in session)
        timeout "$timeout_seconds" claude -p "$prompt" 2>&1

        # Mark session as started for subsequent calls
        if [[ "$SESSION_MODE" == true ]]; then
            SESSION_STARTED=true
        fi
    fi
}
# }}}

# {{{ build_prompt
build_prompt() {
    local issue_path="$1"
    local issue_content
    issue_content=$(cat "$issue_path")

    cat <<'EOF'
Hello computer, all is well. Can you analyze this issue and suggest how it could be split into sub-issues?

If you recommend splitting, format your suggestions as a markdown table with these exact columns:

| ID | Name | Description |
|----|------|-------------|
| 103a | parse-header | Parse the header structure and validate magic bytes |
| 103b | parse-body | Parse the main body content |

FORMAT REQUIREMENTS (for automatic parsing):
- ID: parent issue number + lowercase letter (e.g., 103a, 103b, 103c)
- Name: dash-separated lowercase words (e.g., parse-header, validate-input)
- Description: brief explanation of what this sub-issue covers
- Each row must have pipes | separating the columns
- Do NOT include a header row separator in data rows

If the issue is already small enough or doesn't benefit from splitting, explain why
and do not include a recommendations table.

EOF
    echo "Here is the issue file located at: $issue_path"
    echo ""
    echo "---"
    echo ""
    echo "$issue_content"
}
# }}}

# {{{ build_feedback_prompt
# Build initial prompt for feedback mode - instructs Claude to ask questions
build_feedback_prompt() {
    local issue_path="$1"
    local issue_content
    issue_content=$(cat "$issue_path")

    cat <<'PROMPT_HEADER'
Hello computer, all is well. I need your help analyzing this issue to create a detailed implementation plan.

## Your Task

Analyze the issue and help me understand exactly how to break it down into sub-issues.
This is an interactive conversation - please ask me clarifying questions to ensure you
fully understand the requirements before finalizing your analysis.

## Conversation Protocol

1. **Ask Questions First**: Before providing a final analysis, ask me 2-5 clarifying questions
   about aspects that are unclear, ambiguous, or where my input would improve the plan.

2. **Format Questions**: Start your questions block with "## Questions" and number each question.

3. **When Satisfied**: Once you have enough information, provide your final analysis.
   Start the final analysis with "## ANALYSIS COMPLETE" on its own line.

4. **Final Analysis Format**: After "## ANALYSIS COMPLETE", provide:
   - A summary of understanding based on our conversation
   - Suggested sub-issues as a markdown table:

     | ID | Name | Description |
     |----|------|-------------|
     | 103a | setup-foundation | Initial setup and scaffolding |
     | 103b | implement-core | Core implementation logic |

   FORMAT: ID must be parent number + letter (103a), Name must be dash-separated.

## Types of Good Questions

- Architecture decisions: "Should this use X pattern or Y pattern?"
- Scope clarification: "Should this include Z functionality or is that separate?"
- Priority/ordering: "Which sub-component is most critical to implement first?"
- Integration points: "How should this interact with the existing X system?"
- Edge cases: "What should happen when X occurs?"

## Issue to Analyze

PROMPT_HEADER

    echo "File: $issue_path"
    echo ""
    echo "---"
    echo ""
    echo "$issue_content"
}
# }}}

# {{{ build_followup_prompt
# Build a follow-up prompt with conversation history
build_followup_prompt() {
    local conversation_history="$1"
    local user_response="$2"

    cat <<EOF
$conversation_history

---

## User Response

$user_response

---

Please continue the analysis. If you need more clarification, ask additional questions
(starting with "## Questions"). If you have enough information, provide your final
analysis (starting with "## ANALYSIS COMPLETE").
EOF
}
# }}}

# {{{ has_questions
# Check if Claude's response contains questions (not yet complete)
has_questions() {
    local response="$1"
    # Has questions section but NOT the completion marker
    if echo "$response" | grep -q "^## Questions" && \
       ! echo "$response" | grep -q "^## ANALYSIS COMPLETE"; then
        return 0
    fi
    return 1
}
# }}}

# {{{ extract_questions
# Extract the questions section from Claude's response for display
extract_questions() {
    local response="$1"
    # Extract from "## Questions" to the next "##" or end
    echo "$response" | sed -n '/^## Questions/,/^## [^Q]/p' | head -n -1
    # If that didn't work (no following section), try to end of response
    if [[ -z "$(echo "$response" | sed -n '/^## Questions/,/^## [^Q]/p')" ]]; then
        echo "$response" | sed -n '/^## Questions/,$p'
    fi
}
# }}}

# {{{ prompt_user_response
# Display questions and prompt user for response using TUI dialog
# Requires luajit (same as the rest of the TUI system)
prompt_user_response() {
    local questions="$1"
    local round="$2"

    # Verify TUI input dialog is available
    if [[ ! -f "${LIBS_DIR}/input-dialog.lua" ]]; then
        error "input-dialog.lua not found in ${LIBS_DIR}/"
    fi
    if ! command -v luajit &>/dev/null; then
        error "luajit required for feedback mode (TUI input dialog)"
    fi

    # Write questions to temp file for the dialog
    local prompt_file
    prompt_file=$(mktemp /tmp/feedback-prompt-XXXXXX.txt)

    {
        echo "Claude has questions (Round $round)"
        echo ""
        echo "$questions"
    } > "$prompt_file"

    # Run the TUI input dialog
    # Set LUA_PATH so input-dialog.lua can find tui.lua and other modules
    local response
    if response=$(LUA_PATH="${LIBS_DIR}/?.lua;;" luajit "${LIBS_DIR}/input-dialog.lua" "Feedback Response" "$prompt_file" </dev/tty); then
        rm -f "$prompt_file"
        echo "$response"
        return 0
    else
        rm -f "$prompt_file"
        # User cancelled
        echo ""
        return 1
    fi
}
# }}}

# {{{ process_issue_with_feedback
# Process an issue with interactive feedback loop
process_issue_with_feedback() {
    local issue_path="$1"
    local basename
    basename=$(basename "$issue_path")
    local root_id
    root_id=$(get_root_id "$basename")

    log "Processing with feedback: $basename"

    # Skip sub-issues
    if is_subissue "$basename"; then
        log "  Skipping (is a sub-issue)"
        return 0
    fi

    # Skip root issues that already have sub-issues
    if has_subissues "$root_id"; then
        log "  Skipping (already has sub-issues: will review at end)"
        ROOTS_WITH_SUBS+=("$issue_path")
        return 0
    fi

    # Check if already has analysis
    if [[ "$SKIP_EXISTING" == true ]]; then
        if has_subissue_analysis "$issue_path" || has_initial_analysis "$issue_path"; then
            log "  Skipping (already has analysis)"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "  [DRY RUN] Would analyze with feedback loop"
        return 0
    fi

    # Build initial prompt
    local prompt
    prompt=$(build_feedback_prompt "$issue_path")

    local conversation_history="$prompt"
    local round=1
    local response=""
    local final_analysis=""

    echo ""
    echo "════════════════════════════════════════════════════════════════════════"
    echo "  Starting feedback loop for: $basename"
    echo "════════════════════════════════════════════════════════════════════════"
    echo ""

    while [[ $round -le $MAX_FEEDBACK_ROUNDS ]]; do
        log "  Round $round: Sending to Claude..."

        # Get Claude's response (uses call_claude for session/expert mode)
        if ! response=$(call_claude "$conversation_history" 300); then
            log "  [ERROR] Claude failed or timed out"
            return 1
        fi

        # Check if response has questions or is complete
        if has_questions "$response"; then
            # Extract and display questions
            local questions
            questions=$(extract_questions "$response")

            # Get user's response via TUI dialog
            local user_response
            if ! user_response=$(prompt_user_response "$questions" "$round"); then
                log "  User cancelled feedback loop"
                echo ""
                echo "Feedback loop cancelled. No analysis saved."
                return 0
            fi

            # Check for empty response (user might have submitted empty)
            if [[ -z "$user_response" ]]; then
                log "  Empty response - treating as skip"
                user_response="(No response provided - please continue with your best judgment)"
            fi

            # Build updated conversation
            conversation_history=$(build_followup_prompt "$conversation_history

---

## Claude (Round $round)

$response" "$user_response")

            ((++round))
        else
            # Analysis is complete
            final_analysis="$response"
            log "  Analysis complete after $round round(s)"
            break
        fi
    done

    if [[ -z "$final_analysis" ]]; then
        log "  [WARNING] Reached max rounds ($MAX_FEEDBACK_ROUNDS) without completion"
        final_analysis="$response"
    fi

    # Append the full conversation and final analysis to the issue file
    {
        echo ""
        echo "---"
        echo ""
        echo "## Sub-Issue Analysis (Feedback Mode)"
        echo ""
        echo "*Generated by Claude Code on $(date '+%Y-%m-%d %H:%M') after $round round(s)*"
        echo ""
        echo "### Conversation Summary"
        echo ""
        echo "Rounds: $round"
        echo ""
        echo "### Final Analysis"
        echo ""
        echo "$final_analysis"
    } >> "$issue_path"

    log "  Analysis appended to issue"

    # Archive if enabled
    if [[ "$ARCHIVE_MODE" == true ]]; then
        mkdir -p "$ARCHIVE_DIR"
        local archive_file="${ARCHIVE_DIR}/${basename%.md}-feedback-analysis.md"
        {
            echo "# Feedback Analysis: $basename"
            echo ""
            echo "Generated: $(date '+%Y-%m-%d %H:%M')"
            echo "Rounds: $round"
            echo ""
            echo "---"
            echo ""
            echo "$final_analysis"
        } > "$archive_file"
        log "  Archived to: $archive_file"
    fi

    return 0
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

If you recommend NEW sub-issues, format them as a markdown table:

| ID | Name | Description |
|----|------|-------------|
| 103d | handle-edge-cases | Handle error conditions and edge cases |

FORMAT: ID must be parent number + letter (103d), Name must be dash-separated.
For existing sub-issues, just reference them by their current ID.

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

# {{{ clear_analysis_from_issue
# Remove analysis sections from an issue file, archiving them first
# Sections removed:
#   - ## Sub-Issue Analysis
#   - ## Initial Analysis
#   - ## Structure Review
#   - ## Generated Sub-Issues
# Archived to: issues/analysis/<basename>-cleared-<timestamp>.md
# Preserves all other content in original file
clear_analysis_from_issue() {
    local issue_path="$1"
    local basename
    basename=$(basename "$issue_path")

    log "Clearing analysis: $basename"

    if [[ ! -f "$issue_path" ]]; then
        error "File not found: $issue_path"
        return 1
    fi

    # First, extract the analysis sections to archive
    local analysis_content
    analysis_content=$(awk '
    BEGIN { skip = 0; found = 0 }
    /^## Sub-Issue Analysis$/ || /^## Initial Analysis$/ || /^## Structure Review$/ || /^## Generated Sub-Issues$/ {
        skip = 1
        found = 1
        print
        next
    }
    /^## / {
        skip = 0
    }
    skip == 1 { print }
    END { exit (found ? 0 : 1) }
    ' "$issue_path")

    if [[ -z "$analysis_content" ]]; then
        log "  No analysis sections found"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "  [DRY RUN] Would archive and clear analysis sections"
        return 0
    fi

    # Archive the extracted analysis
    mkdir -p "$ARCHIVE_DIR"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local archive_file="${ARCHIVE_DIR}/${basename%.md}-cleared-${timestamp}.md"

    {
        echo "# Archived Analysis: $basename"
        echo "# Cleared on: $(date)"
        echo "# Original file: $issue_path"
        echo ""
        echo "$analysis_content"
    } > "$archive_file"
    log "  Archived to: $(basename "$archive_file")"

    # Create temp file for the cleaned content
    local temp_file
    temp_file=$(mktemp)

    # Use awk to remove analysis sections
    # A section starts with ## <heading> and ends at the next ## or end of file
    # Pattern matches EXACT section headers (anchored start and end)
    awk '
    BEGIN { skip = 0 }
    /^## Sub-Issue Analysis$/ || /^## Initial Analysis$/ || /^## Structure Review$/ || /^## Generated Sub-Issues$/ {
        skip = 1
        next
    }
    /^## / {
        # New section starts - stop skipping
        skip = 0
    }
    skip == 0 { print }
    ' "$issue_path" > "$temp_file"

    # Remove trailing blank lines that might be left over
    # (keep at most one trailing newline)
    sed -i -e :a -e '/^\s*$/{ $d; N; ba; }' "$temp_file"

    # Replace original file
    mv "$temp_file" "$issue_path"
    log "  Cleared analysis sections"
    return 0
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

    # Use call_claude wrapper to handle session/expert mode
    # Timeout after 5 minutes per issue
    local response
    if response=$(call_claude "$prompt" 300); then
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

    # Use call_claude wrapper to handle session/expert mode
    local response
    if response=$(call_claude "$prompt" 300); then
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
    # Must continue through sub-headings like "## Recommended Sub-Issues"
    # until we hit a section separator "---" or end of file
    #
    # Strategy: Find the LAST "## Sub-Issue Analysis" section (most recent)
    # and extract everything from there to the next "---" or EOF
    local section=""

    # Use awk to find the last Sub-Issue Analysis section and extract to --- or EOF
    section=$(awk '
        /^## Sub-Issue Analysis/ {
            # Start capturing from this line
            capturing = 1
            buffer = ""
        }
        capturing {
            if (/^---$/) {
                # End of section - print what we have and stop capturing
                print buffer
                capturing = 0
                buffer = ""
            } else {
                buffer = buffer $0 "\n"
            }
        }
        END {
            # If still capturing at EOF, print the buffer
            if (capturing) print buffer
        }
    ' "$issue_path" 2>/dev/null)

    # If not found, try Initial Analysis with same logic
    if [[ -z "$section" ]]; then
        section=$(awk '
            /^## Initial Analysis/ {
                capturing = 1
                buffer = ""
            }
            capturing {
                if (/^---$/) {
                    print buffer
                    capturing = 0
                    buffer = ""
                } else {
                    buffer = buffer $0 "\n"
                }
            }
            END {
                if (capturing) print buffer
            }
        ' "$issue_path" 2>/dev/null)
    fi

    echo "$section"
}
# }}}

# {{{ extract_recommendations
# Parses Claude's analysis to extract sub-issue recommendations.
#
# SUPPORTED FORMATS (Claude must use one of these):
#
# 1. Markdown table (preferred):
#    | 103a | parse-header | Description of the sub-issue |
#    | 103b | parse-body   | Another description here     |
#
# 2. Bold list format:
#    - **103a-parse-header**: Description of the sub-issue
#    - **103b-parse-body**: Another description here
#
# 3. Bold ID with backtick name:
#    | **103a** | `parse-header` | Description of the sub-issue |
#
# The ID must match pattern: {digits}{letter(s)} (e.g., 103a, 201b, 42abc)
# The name should be dash-separated lowercase words.
#
extract_recommendations() {
    local analysis="$1"
    local -a recommendations=()

    # Parse markdown table format: | 103a | parse-header | description |
    while IFS='|' read -r _ id name desc _; do
        id=$(echo "$id" | tr -d ' ')
        name=$(echo "$name" | tr -d ' ' | sed 's/^-//' | sed 's/-$//')
        if [[ "$id" =~ ^[0-9]+[a-z]+$ ]]; then
            recommendations+=("$id|$name|$desc")
        fi
    done <<< "$analysis"

    # Parse bold list format: - **103a-parse-header**: description
    # Or bold ID with backtick name: | **103a** | `parse-header` | description
    while IFS= read -r line; do
        # Format: **103a-name**: description
        if [[ "$line" =~ \*\*([0-9]+[a-z]+)-([^*]+)\*\*:?[[:space:]]*(.+) ]]; then
            local id="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]}"
            local desc="${BASH_REMATCH[3]}"
            recommendations+=("$id|$name|$desc")
        # Format: **103a** | `name` | description
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

    # Warn about incompatible options
    if [[ "$SESSION_MODE" == true ]] && [[ "$STREAMING_MODE" == true ]]; then
        log "WARNING: --session is incompatible with --stream (parallel processing)"
        log "         Session mode disabled; using fresh context per issue."
        SESSION_MODE=false
    fi

    if [[ "$SESSION_MODE" == true ]] && [[ "$EXPERT_MODE" == true ]]; then
        log "WARNING: --session and --expert are mutually exclusive"
        log "         Using session mode (--session takes precedence)."
        EXPERT_MODE=false
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

    # Phase 1: Process issues (mode determines action)
    if [[ "$CLEAR_MODE" == true ]]; then
        # Clear mode - remove analysis sections from issues (no Claude)
        echo "════════════════════════════════════════════════════════════════"
        log "Clearing analysis sections from selected issues"
        echo "════════════════════════════════════════════════════════════════"
        echo

        for issue in "${SELECTED_ISSUES[@]}"; do
            if clear_analysis_from_issue "$issue"; then
                ((++processed))
            else
                ((++skipped))
            fi
        done
        echo
        log "Clear complete: $processed processed, $skipped skipped"

    elif [[ "$REVIEW_ONLY" != true ]]; then
        echo "════════════════════════════════════════════════════════════════"
        if [[ "$FEEDBACK_MODE" == true ]]; then
            log "PHASE 1: Analyzing issues with interactive feedback loop"
        elif [[ "$STREAMING_MODE" == true ]]; then
            log "PHASE 1: Analyzing issues (streaming mode, parallel=$PARALLEL_COUNT)"
        elif [[ "$SESSION_MODE" == true ]]; then
            log "PHASE 1: Analyzing issues (session mode - reusing context)"
        else
            log "PHASE 1: Analyzing issues for sub-issue splitting (expert mode)"
        fi
        echo "════════════════════════════════════════════════════════════════"
        echo

        if [[ "$FEEDBACK_MODE" == true ]]; then
            # Interactive feedback mode - process one at a time with user input
            for issue in "${SELECTED_ISSUES[@]}"; do
                if process_issue_with_feedback "$issue"; then
                    ((++processed))
                else
                    ((++skipped))
                fi
            done
            echo
            log "Phase 1 complete: $processed processed, $skipped skipped"
        elif [[ "$STREAMING_MODE" == true ]]; then
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

    # Skip remaining phases for clear mode (it's a standalone operation)
    if [[ "$CLEAR_MODE" != true ]]; then
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
