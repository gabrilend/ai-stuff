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
#   -G, --generate-complete  Generate complete issue files (not skeletons) via Claude
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
GENERATE_COMPLETE=false  # Use Claude tool calls to generate complete issue files
PRINT_COMMAND=false      # Print command instead of executing (Issue 011)

# {{{ User Config (can be overridden in ~/.config/issue-splitter/config)
# Copy command to clipboard when using --print-command
COPY_TO_CLIPBOARD=false

# Example config file (~/.config/issue-splitter/config):
#   COPY_TO_CLIPBOARD=true
# }}}

# Load config file for optional settings
CONFIG_FILE="${HOME}/.config/issue-splitter/config"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

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

        # Archive if enabled (append to preserve history)
        if [[ "$ARCHIVE_MODE" == true ]]; then
            mkdir -p "$ARCHIVE_DIR"
            local archive_file="${ARCHIVE_DIR}/${basename%.md}-analysis.md"
            {
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "Analysis: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "═══════════════════════════════════════════════════════════════"
                echo ""
                echo "$response"
            } >> "$archive_file"
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
            -G|--generate-complete)
                GENERATE_COMPLETE=true
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
            -P|--print-command)
                PRINT_COMMAND=true
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

# {{{ get_analysis_verdict
# Determines if an analyzed issue recommends splitting or not
# Returns: "split", "no-split", or "unknown"
# Searches ALL analysis sections (not just the last) because multiple
# analysis runs may exist, and later runs may be empty/timestamp-only
get_analysis_verdict() {
    local file="$1"

    # Extract ALL analysis section content (all Sub-Issue Analysis and Initial Analysis)
    # Only stop on --- or known non-analysis sections (not on sub-headings like ## Recommendation:)
    local analysis=""
    analysis=$(awk '
        /^## Sub-Issue Analysis$/ || /^## Initial Analysis$/ {
            capturing = 1
            next
        }
        capturing {
            # Stop on section separator or known non-analysis sections
            if (/^---$/ || /^## (Implementation Notes|Related Documents|Generated Sub-Issues|Structure Review|Acceptance Criteria|Notes)/) {
                capturing = 0
            } else {
                print $0
            }
        }
    ' "$file" 2>/dev/null)

    [[ -z "$analysis" ]] && echo "unknown" && return

    # Check for "don't split" indicators (check these first - more specific)
    # Case-insensitive matching using grep -i
    if echo "$analysis" | grep -qiE "(don't|do not|does not) (recommend )?split|keep as (single|one) issue|does not (need|benefit)|not (be )?split|Recommendation:.*Keep|Recommendation:.*Do Not Split|No splitting needed"; then
        echo "no-split"
        return
    fi

    # Check for "split" indicators
    if echo "$analysis" | grep -qiE "would benefit from split|Split into [0-9]+ sub-issues|Recommendation:.*Split|SPLIT|should be split|recommend split|split this issue"; then
        echo "split"
        return
    fi

    echo "unknown"
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
        "Share context across issues (cross-issue awareness, less per-issue depth)" "e" "-S"
    menu_add_item "processing" "generate_complete" "Generate Complete Issues" "checkbox" "0" \
        "Claude writes full issue files via tool calls (enables Session Mode)" "g" "-G"

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
    # Limit visible items to 10 to preserve space for description and command preview
    # When there are more items, a scrollbar appears and viewport scrolls with selection
    menu_set_section_max_visible "files" 10
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
        local item_id="file_$i"

        # Track file properties for dependency rules
        local is_sub=false
        local is_root_with_subs=false
        local has_analysis=false
        local has_struct_review=false

        # Determine file properties and build description
        if is_subissue "$basename"; then
            is_sub=true
            desc="[SUB] Part of issue ${root_id}"
            default="0"  # Sub-issues off by default
        elif has_subissues "$root_id"; then
            is_root_with_subs=true
            local sub_count
            sub_count=$(get_subissues_for_root "$root_id" | wc -l)
            # Check if this root has already been structure-reviewed
            if has_structure_review "$issue"; then
                has_struct_review=true
                desc="[ROOT+${sub_count} REVIEWED] Already structure-reviewed"
                default="0"  # Already reviewed = unchecked by default
            else
                desc="[ROOT+${sub_count}] Has ${sub_count} sub-issue(s) - ready for review"
            fi
        elif has_subissue_analysis "$issue" || has_initial_analysis "$issue"; then
            has_analysis=true
            # Check the verdict from analysis
            local verdict
            verdict=$(get_analysis_verdict "$issue")
            case "$verdict" in
                split)
                    desc="[ANALYZED] verdict: split"
                    ;;
                no-split)
                    desc="[ANALYZED] verdict: don't split"
                    default="0"  # Don't split = unchecked by default
                    ;;
                *)
                    desc="[ANALYZED] verdict: unclear"
                    ;;
            esac
        elif has_generated_subissues "$issue"; then
            has_analysis=true  # Has generated = had analysis
            desc="[EXECUTED] Sub-issues already generated"
        else
            desc="[NEW] Ready for analysis"
        fi

        menu_add_item "files" "$item_id" "$label" "checkbox" "$default" "$desc"
        # Set file path for preview when this item is selected
        menu_set_item_filepath "$item_id" "$issue"

        # ═══════════════════════════════════════════════════════════════════════
        # Add dynamic dependencies based on file properties and mode compatibility
        # ═══════════════════════════════════════════════════════════════════════

        # Rule 1: Review Structures mode only works on root issues with sub-issues
        # Disable non-roots when review mode is selected
        if [[ "$is_root_with_subs" == false ]]; then
            menu_add_dependency "$item_id" "review" "1" "true" \
                "Review mode: only root issues with sub-issues (enable Analyze)" "yellow"
        fi

        # Rule 2: Execute Recommendations requires existing analysis
        # Disable issues without analysis when execute mode is selected
        if [[ "$has_analysis" == false ]] && [[ "$is_root_with_subs" == false ]]; then
            menu_add_dependency "$item_id" "execute" "1" "true" \
                "Execute mode: no analysis to execute (run Analyze first)" "yellow"
        fi

        # Rule 3: Clear Analysis requires existing analysis
        # Disable issues without analysis when clear mode is selected
        if [[ "$has_analysis" == false ]] && [[ "$is_root_with_subs" == false ]]; then
            menu_add_dependency "$item_id" "clear" "1" "true" \
                "Clear mode: no analysis to clear" "yellow"
        fi

        # Rule 4: Skip Analyzed disables issues that have analysis (in analyze mode)
        # This only applies when NOT in review/execute/clear modes
        if [[ "$has_analysis" == true ]]; then
            # Disable when skip_existing=1 AND we're in analyze mode (not execute/clear/review)
            # Since analyze is the default, we check that none of the other modes are on
            menu_add_dependency "$item_id" "skip_existing" "1" "true" \
                "Skipped: has existing analysis (disable Skip Analyzed)" "yellow"
        fi

        # Rule 5: Skip Analyzed in Review mode disables structure-reviewed roots
        if [[ "$has_struct_review" == true ]]; then
            menu_add_dependency "$item_id" "skip_existing" "1" "true" \
                "Skipped: already structure-reviewed (disable Skip Analyzed)" "yellow"
        fi

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

    # "Generate Complete Issues" only available in Execute Recommendations mode
    menu_add_dependency "generate_complete" "execute" "0" "true" \
        "Only applies to Execute Recommendations mode" "yellow"

    # Suggest "Generate Complete Issues" when Execute mode is selected (yellow highlight)
    menu_add_dependency_suggest "generate_complete" "execute" "1" \
        "Recommended for complete specifications"

    # Auto-enable Session Mode when Generate Complete is selected
    menu_add_prerequisite "generate_complete" "session"

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
        [[ "$(menu_get_value "generate_complete")" == "1" ]] && GENERATE_COMPLETE=true

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
        echo "║                    Configuration Summary                     ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║ Directory: $(printf '%-49s' "$DIR") ║"
        echo "║ Issues selected: $(printf '%-43s' "${#SELECTED_ISSUES[@]}") ║"
        echo "╠══════════════════════════════════════════════════════════════╣"

        # Mode
        local mode_str="Analyze"
        [[ "$FEEDBACK_MODE" == true ]] && mode_str="Feedback Loop"
        [[ "$REVIEW_ONLY" == true ]] && mode_str="Review"
        [[ "$EXECUTE_MODE" == true ]] && mode_str="Execute"
        [[ "$AUTO_IMPLEMENT" == true ]] && mode_str="Implement"
        [[ "$CLEAR_MODE" == true ]] && mode_str="Clear Analysis"
        echo "║ Mode: $(printf '%-54s' "$mode_str") ║"

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
        echo "║ Options: $(printf '%-51s' "$opts") ║"

        # Streaming settings
        if [[ "$STREAMING_MODE" == true ]]; then
            echo "║ Parallel: $(printf '%-50s' "$PARALLEL_COUNT jobs, ${STREAM_DELAY}s delay")║"
        fi

        echo "╚══════════════════════════════════════════════════════════════╝"
        echo

        # If --print-command, show command and exit (Issue 011)
        if [[ "$PRINT_COMMAND" == true ]]; then
            local cmd
            cmd=$(menu_get_value "cmd_preview")

            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "║                      Command Ready                           ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo
            echo "  $cmd"
            echo

            # Copy to clipboard if enabled in config
            if [[ "$COPY_TO_CLIPBOARD" == true ]]; then
                if command -v xclip &>/dev/null; then
                    echo -n "$cmd" | xclip -selection clipboard
                    echo "(Copied to clipboard)"
                elif command -v xsel &>/dev/null; then
                    echo -n "$cmd" | xsel --clipboard
                    echo "(Copied to clipboard)"
                elif command -v pbcopy &>/dev/null; then
                    echo -n "$cmd" | pbcopy
                    echo "(Copied to clipboard)"
                else
                    echo "(Clipboard copy requested but no clipboard tool found)"
                fi
            fi

            exit 0
        fi
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

If you recommend splitting, provide:

### 1. Recommendation Table

Format your suggestions as a markdown table with these exact columns:

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| 103a | parse-header | None | Parse the header structure and validate magic bytes |
| 103b | parse-body | 103a | Parse the main body content (depends on header) |

FORMAT REQUIREMENTS (for automatic parsing):
- ID: parent issue number + lowercase letter (e.g., 103a, 103b, 103c)
- Name: dash-separated lowercase words (e.g., parse-header, validate-input)
- Dependencies: "None" or comma-separated IDs of sub-issues this depends on
- Description: brief explanation of what this sub-issue covers
- Each row must have pipes | separating the columns

### 2. Rationale

Explain WHY splitting makes sense for this issue:
- What distinct work streams exist?
- Why can't this be done as a single issue?
- What benefits does splitting provide?

### 3. Execution Order

Show the dependency graph and recommended implementation order:
```
103a (foundation) → 103b (depends on 103a) → 103c (parallel with 103b)
```

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

     | ID | Name | Dependencies | Description |
     |----|------|--------------|-------------|
     | 103a | setup-foundation | None | Initial setup and scaffolding |
     | 103b | implement-core | 103a | Core implementation logic |

   - A rationale section explaining why splitting makes sense
   - An execution order showing the dependency graph

   FORMAT: ID must be parent number + letter (103a), Name must be dash-separated.
   Dependencies: "None" or comma-separated IDs this sub-issue depends on.

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

    # Archive if enabled (append to preserve history)
    if [[ "$ARCHIVE_MODE" == true ]]; then
        mkdir -p "$ARCHIVE_DIR"
        local archive_file="${ARCHIVE_DIR}/${basename%.md}-feedback-analysis.md"
        {
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo "Feedback Analysis: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Rounds: $round"
            echo "═══════════════════════════════════════════════════════════════"
            echo ""
            echo "$final_analysis"
        } >> "$archive_file"
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

# {{{ build_generation_prompt
# Build a prompt that instructs Claude to generate complete issue files using Write tool
# Takes parent issue path and list of sub-issue file paths to generate
build_generation_prompt() {
    local parent_path="$1"
    shift
    local subissues=("$@")
    local parent_content
    parent_content=$(cat "$parent_path")

    cat <<'EOF'
TASK: Create issue documentation files (markdown only).

SCOPE RESTRICTION - READ CAREFULLY:
- You are ONLY creating issue DOCUMENTATION files (.md files in issues/ directory)
- Do NOT implement any code, tests, or functionality
- Do NOT modify any source files (src/, tests/, libs/, etc.)
- Do NOT continue any previous implementation work
- IGNORE any previous context about implementing issues
- Your ONLY job is to write markdown issue specification files

For each issue file, include these sections:
- **Current Behavior** - What exists now (infer from parent issue context)
- **Intended Behavior** - Detailed specification of what should happen
- **Suggested Implementation Steps** - Concrete, numbered, actionable steps
- **Related Documents** - Parent issue, siblings, relevant code paths
- **Acceptance Criteria** - Testable checkbox items (use markdown checkboxes)

REQUIREMENTS:
- Use the Write tool to create each .md file listed below
- Do NOT use placeholders like "(To be filled in)" - provide real content
- Each step should be specific enough for a developer to implement later
- Reference specific files, functions, or code patterns when describing the work

REMEMBER: Only create markdown issue files. No code implementation.

EOF

    echo "Parent issue context:"
    echo ""
    echo "---"
    echo ""
    echo "$parent_content"
    echo ""
    echo "---"
    echo ""
    echo "Files to generate (use Write tool for each):"
    echo ""

    for f in "${subissues[@]}"; do
        echo "- $f"
    done
}
# }}}

# {{{ generate_complete_issues
# Invoke Claude with Write tool permissions to generate complete issue files
# Falls back to skeleton generation on failure
generate_complete_issues() {
    local parent_path="$1"
    shift
    local subissues=("$@")

    local prompt
    prompt=$(build_generation_prompt "$parent_path" "${subissues[@]}")

    log "  Generating complete issue files via Claude..."
    echo "  ─────────────────────────────────────────────────────────────"

    # Use --continue in session mode for efficiency (avoids re-reading project context)
    # The prompt includes explicit SCOPE RESTRICTION to prevent implementation bleed
    # --allowedTools Write restricts to only file creation
    local claude_opts=("--allowedTools" "Write" "-p" "$prompt")
    if [[ "$SESSION_MODE" == true ]] && [[ "$SESSION_STARTED" == true ]]; then
        claude_opts=("--continue" "--allowedTools" "Write" "-p" "$prompt")
    fi

    # Run Claude with real-time output visible to user
    # No timeout - let Claude complete naturally. Timeouts waste tokens since
    # partial Write tool calls may have already succeeded. User can Ctrl+C if needed.
    if claude "${claude_opts[@]}"; then
        # Mark session as started if using session mode
        if [[ "$SESSION_MODE" == true ]]; then
            SESSION_STARTED=true
        fi
        echo "  ─────────────────────────────────────────────────────────────"
        log "  Generation complete"
        return 0
    else
        local exit_code=$?
        echo "  ─────────────────────────────────────────────────────────────"
        log "  [ERROR] Generation failed (exit code: $exit_code)"
        log "  Note: Some files may have been created before failure - check issues directory"
        return 1
    fi
}
# }}}

# {{{ validate_issue_file
# Check that a generated issue file has all required sections
# Returns 0 if valid, 1 if missing sections (with warnings logged)
validate_issue_file() {
    local file="$1"
    local missing=()

    # Check file exists
    if [[ ! -f "$file" ]]; then
        log "  WARNING: File not created: $file"
        return 1
    fi

    # Check for required sections (using flexible pattern matching)
    grep -qE "^## Current Behavior" "$file" || missing+=("Current Behavior")
    grep -qE "^## Intended Behavior" "$file" || missing+=("Intended Behavior")
    grep -qE "^## (Suggested )?Implementation" "$file" || missing+=("Implementation Steps")
    grep -qE "^## Acceptance Criteria" "$file" || missing+=("Acceptance Criteria")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log "  WARNING: $(basename "$file") missing sections: ${missing[*]}"
        return 1
    fi

    log "  Validated: $(basename "$file")"
    return 0
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

        # Optionally save to archive (append to preserve history)
        if [[ "$ARCHIVE_MODE" == true ]]; then
            mkdir -p "$ARCHIVE_DIR"
            local archive_file="${ARCHIVE_DIR}/${basename%.md}-analysis.md"
            {
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "Analysis: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "═══════════════════════════════════════════════════════════════"
                echo ""
                echo "$response"
            } >> "$archive_file"
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

        # Optionally save to archive (append to preserve history)
        if [[ "$ARCHIVE_MODE" == true ]]; then
            mkdir -p "$ARCHIVE_DIR"
            local archive_file="${ARCHIVE_DIR}/${basename%.md}-structure-review.md"
            {
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "Structure Review: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "═══════════════════════════════════════════════════════════════"
                echo ""
                echo "$response"
            } >> "$archive_file"
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
    # IMPORTANT: Analysis often uses "---" as internal separators, so we
    # must NOT stop at "---". Instead, stop at:
    # - A new top-level ## section that's NOT part of analysis
    # - End of file
    #
    # Analysis sections include sub-headings like "### Suggested Sub-Issues"
    # which we must capture. "---" separators within analysis are kept.
    #
    # Strategy: Find the LAST "## Sub-Issue Analysis" section (most recent)
    # and extract everything until a non-analysis ## section or EOF
    local section=""

    # Sections that indicate END of analysis content
    # (these are post-analysis sections, not part of the analysis itself)
    section=$(awk '
        /^## Sub-Issue Analysis/ {
            # Start capturing from this line (resets any previous section)
            capturing = 1
            buffer = ""
        }
        capturing {
            # Stop at sections that are clearly NOT part of analysis
            if (/^## (Implementation Notes|Notes|Related Documents|Acceptance Criteria|Generated Sub-Issues|Structure Review)/) {
                # End of analysis section - save what we have
                last_section = buffer
                capturing = 0
                buffer = ""
            } else {
                # Include everything else (including --- separators and ### sub-headings)
                buffer = buffer $0 "\n"
            }
        }
        END {
            # Print the last section we captured
            # Either still capturing (section runs to EOF) or last completed section
            if (capturing && buffer != "") {
                print buffer
            } else if (last_section != "") {
                print last_section
            }
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
                if (/^## (Implementation Notes|Notes|Related Documents|Acceptance Criteria|Generated Sub-Issues|Structure Review)/) {
                    last_section = buffer
                    capturing = 0
                    buffer = ""
                } else {
                    buffer = buffer $0 "\n"
                }
            }
            END {
                if (capturing && buffer != "") {
                    print buffer
                } else if (last_section != "") {
                    print last_section
                }
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
# 1. Markdown table with dependencies (preferred):
#    | 103a | parse-header | None | Description of the sub-issue |
#    | 103b | parse-body   | 103a | Another description here     |
#
# 2. Markdown table without dependencies (legacy):
#    | 103a | parse-header | Description of the sub-issue |
#    | 103b | parse-body   | Another description here     |
#
# 3. Bold list format:
#    - **103a-parse-header**: Description of the sub-issue
#    - **103b-parse-body**: Another description here
#
# 4. Header format (with Description on next line):
#    #### 103a-parse-header
#    **Description:** Description of the sub-issue
#
# Output format: id|name|dependencies|description
# Dependencies will be "None" if not specified.
#
# The ID must match pattern: {digits}{letter(s)} (e.g., 103a, 201b, 42abc)
# The name should be dash-separated lowercase words.
#
extract_recommendations() {
    local analysis="$1"
    local -a recommendations=()

    # Parse markdown table format
    # Try 4-column first: | 103a | parse-header | deps | description |
    # Fall back to 3-column: | 103a | parse-header | description |
    while IFS='|' read -r _ col1 col2 col3 col4 _; do
        col1=$(echo "$col1" | tr -d ' ')
        col2=$(echo "$col2" | tr -d ' ' | sed 's/^-//' | sed 's/-$//')
        col3=$(echo "$col3" | xargs)  # trim whitespace
        col4=$(echo "$col4" | xargs)  # trim whitespace

        if [[ "$col1" =~ ^[0-9]+[a-z]+$ ]]; then
            # Check if col3 looks like dependencies (None, or IDs like 103a, 103b)
            if [[ "$col3" =~ ^(None|[0-9]+[a-z]+(,[[:space:]]*[0-9]+[a-z]+)*)$ ]]; then
                # 4-column format: id | name | deps | description
                local deps="$col3"
                local desc="$col4"
                recommendations+=("$col1|$col2|$deps|$desc")
            else
                # 3-column format: id | name | description (no deps)
                local desc="$col3"
                recommendations+=("$col1|$col2|None|$desc")
            fi
        fi
    done <<< "$analysis"

    # Parse bold list format: - **103a-parse-header**: description
    while IFS= read -r line; do
        # Format: **103a-name**: description
        if [[ "$line" =~ \*\*([0-9]+[a-z]+)-([^*]+)\*\*:?[[:space:]]*(.+) ]]; then
            local id="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]}"
            local desc="${BASH_REMATCH[3]}"
            recommendations+=("$id|$name|None|$desc")
        fi
    done <<< "$analysis"

    # Parse header format: #### 304a-name followed by **Description:** on next line
    # This format is used when Claude creates detailed sub-issue specs with headers
    # Supports both "#### 304a-name" and "#### 304a - name" (with spaces around dash)
    local current_id=""
    local current_name=""
    while IFS= read -r line; do
        # Match header: #### 304a-lexer-core-infrastructure OR #### 308a - implement-event-registry
        # Allow optional spaces around the dash separator
        if [[ "$line" =~ ^#{1,4}[[:space:]]+([0-9]+[a-z]+)[[:space:]]*-[[:space:]]*(.+)$ ]]; then
            current_id="${BASH_REMATCH[1]}"
            current_name="${BASH_REMATCH[2]}"
            # Trim trailing whitespace from name
            current_name=$(echo "$current_name" | sed 's/[[:space:]]*$//')
        # Match description line after header: **Description:** text
        elif [[ -n "$current_id" ]] && [[ "$line" =~ ^\*\*Description:\*\*[[:space:]]*(.+) ]]; then
            local desc="${BASH_REMATCH[1]}"
            recommendations+=("$current_id|$current_name|None|$desc")
            current_id=""
            current_name=""
        # Also match "**Covers:**" or similar if Description not found
        elif [[ -n "$current_id" ]] && [[ "$line" =~ ^\*\*Covers:\*\* ]]; then
            # Use the header name as description if no explicit Description
            recommendations+=("$current_id|$current_name|None|$current_name")
            current_id=""
            current_name=""
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
            IFS='|' read -r id name deps desc <<< "$rec"
            local dep_info=""
            [[ "$deps" != "None" ]] && dep_info=" [depends: $deps]"
            echo "    - ${id}-${name}${dep_info}: ${desc:0:50}..."
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
        if [[ "$GENERATE_COMPLETE" == true ]]; then
            log "  [DRY RUN] Would use Claude to generate complete files"
        fi
        return 0
    fi

    # Build list of file paths to generate
    local -a subissue_files=()
    for rec in "${valid_recommendations[@]}"; do
        IFS='|' read -r id name deps desc <<< "$rec"
        name=$(echo "$name" | sed 's/^[- ]*//' | sed 's/[- ]*$//' | tr ' ' '-')
        subissue_files+=("${ISSUES_DIR}/${id}-${name}.md")
    done

    # Generate sub-issue files - complete or skeleton
    local created=0
    local generation_failed=false

    if [[ "$GENERATE_COMPLETE" == true ]]; then
        # Use Claude with Write tool to generate complete issue files
        if generate_complete_issues "$issue_path" "${subissue_files[@]}"; then
            # Validate generated files
            local valid_count=0
            local invalid_count=0
            for f in "${subissue_files[@]}"; do
                if validate_issue_file "$f"; then
                    ((++valid_count))
                    ((++created))
                else
                    ((++invalid_count))
                fi
            done
            log "  Validation: $valid_count valid, $invalid_count with warnings"

            # If any files are missing entirely, fall back to skeletons for those
            if [[ $invalid_count -gt 0 ]]; then
                log "  Generating skeletons for missing/invalid files..."
                for rec in "${valid_recommendations[@]}"; do
                    IFS='|' read -r id name deps desc <<< "$rec"
                    local clean_name
                    clean_name=$(echo "$name" | sed 's/^[- ]*//' | sed 's/[- ]*$//' | tr ' ' '-')
                    local filepath="${ISSUES_DIR}/${id}-${clean_name}.md"
                    if [[ ! -f "$filepath" ]]; then
                        if generate_subissue "$issue_path" "$id" "$name" "$desc" "$deps"; then
                            ((++created))
                        fi
                    fi
                done
            fi
        else
            # Generation command failed, but files may have been created via Write tool
            # before the failure. Check which files exist and validate them.
            log "  Checking for partially created files..."
            local partial_valid=0
            local partial_missing=0
            for f in "${subissue_files[@]}"; do
                if [[ -f "$f" ]]; then
                    if validate_issue_file "$f"; then
                        ((++partial_valid))
                        ((++created))
                    fi
                else
                    ((++partial_missing))
                fi
            done

            if [[ $partial_valid -gt 0 ]]; then
                log "  Found $partial_valid files created before failure"
            fi

            if [[ $partial_missing -gt 0 ]]; then
                log "  Generating skeletons for $partial_missing missing files..."
                for rec in "${valid_recommendations[@]}"; do
                    IFS='|' read -r id name deps desc <<< "$rec"
                    local clean_name
                    clean_name=$(echo "$name" | sed 's/^[- ]*//' | sed 's/[- ]*$//' | tr ' ' '-')
                    local filepath="${ISSUES_DIR}/${id}-${clean_name}.md"
                    if [[ ! -f "$filepath" ]]; then
                        if generate_subissue "$issue_path" "$id" "$name" "$desc" "$deps"; then
                            ((++created))
                        fi
                    fi
                done
            fi
        fi
    fi

    # Fallback: generate skeletons (only when GENERATE_COMPLETE=false)
    if [[ "$GENERATE_COMPLETE" != true ]]; then
        for rec in "${valid_recommendations[@]}"; do
            IFS='|' read -r id name deps desc <<< "$rec"
            if generate_subissue "$issue_path" "$id" "$name" "$desc" "$deps"; then
                ((++created))
            fi
        done
    fi

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
                IFS='|' read -r id name deps desc <<< "$rec"
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

    elif [[ "$EXECUTE_MODE" == true ]]; then
        # Execute mode: skip analysis, go straight to executing recommendations
        # (Phase 3 will run below)
        log "Skipping analysis phase (Execute mode works with existing analysis)"

    elif [[ "$AUTO_IMPLEMENT" == true ]]; then
        # Auto-implement mode: skip analysis, go straight to implementation
        # (Phase 4 will run below)
        log "Skipping analysis phase (Auto-implement mode)"

    elif [[ "$REVIEW_ONLY" == true ]]; then
        # In review-only mode, just find roots with sub-issues
        find_roots_with_subissues

    else
        # Analysis modes: Analyze, Feedback
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
