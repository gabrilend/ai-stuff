#!/usr/bin/env bash
# batch-transcript-backup.sh - Batch LLM transcript backup with TUI selection
#
# Creates backups of LLM transcripts across all projects in the monorepo.
# Supports interactive project selection, multiple verbosity levels, and batch operations.

# -- {{{ Script Directory and Path Setup
DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
MONOREPO_ROOT="$(dirname "$DIR")"
DELTA_VERSION_DIR="${MONOREPO_ROOT}/delta-version"
LIBS_DIR="${DIR}/libs"
# Transcripts are recognised by their header line, not a filename suffix, so
# date-range renaming leaves this batch tool finding them unchanged.
source "${LIBS_DIR}/transcript-discovery.sh"
# }}}

# -- {{{ Configuration Variables
INTERACTIVE_MODE=false
DRY_RUN=false
PROCESS_ALL=false
ALL_VERBOSITY_LEVELS=false
VERBOSITY_LEVEL=2  # Default: standard (v2)
AUTO_COMMIT=false
VERBOSITY_RANGE=""
SELECTED_PROJECTS=()
# }}}

# -- {{{ Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
# }}}

# -- {{{ Logging Functions
log() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}
# }}}

# -- {{{ show_help
show_help() {
    cat <<EOF
Usage: batch-transcript-backup.sh [OPTIONS] [PROJECT...]

Batch backup LLM transcripts for multiple projects in the monorepo.

OPTIONS:
    -I, --interactive       Interactive mode with TUI project selection
    -a, --all               Process all projects
    -n, --dry-run           Show what would be done without executing
    -v, --verbosity LEVEL   Verbosity level (0-5, default: 2)
    --all-verbosity-levels  Generate all verbosity levels (v0-v5) for each conversation
    --verbosity-range N-M   Generate specific verbosity range (e.g., 2-4)
    --commit                Git commit after backup
    --since DATE            Only backup conversations since DATE
    -h, --help              Show this help message

VERBOSITY LEVELS:
    0 (minimal)   - Code and essential content only
    1 (compact)   - Skip sentiments, show responses
    2 (standard)  - Complete conversation (default)
    3 (verbose)   - Include context files and expansions
    4 (complete)  - Everything + LLM execution details
    5 (raw)       - ALL intermediate steps and tool results

EXAMPLES:
    # Interactive mode
    batch-transcript-backup.sh -I

    # Process all projects at verbosity level 4
    batch-transcript-backup.sh --all -v 4

    # Process specific projects with all verbosity levels
    batch-transcript-backup.sh --all-verbosity-levels delta-version world-edit

    # Dry run to see what would be done
    batch-transcript-backup.sh --all --dry-run

    # Generate verbosity range 2-4 for all projects and commit
    batch-transcript-backup.sh --all --verbosity-range 2-4 --commit

EOF
}
# }}}

# -- {{{ parse_arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -I|--interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            -a|--all)
                PROCESS_ALL=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbosity)
                VERBOSITY_LEVEL="$2"
                shift 2
                ;;
            --all-verbosity-levels)
                ALL_VERBOSITY_LEVELS=true
                shift
                ;;
            --verbosity-range)
                VERBOSITY_RANGE="$2"
                ALL_VERBOSITY_LEVELS=true
                shift 2
                ;;
            --commit)
                AUTO_COMMIT=true
                shift
                ;;
            --since)
                SINCE_DATE="$2"
                shift 2
                ;;
            -*)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                SELECTED_PROJECTS+=("$1")
                shift
                ;;
        esac
    done
}
# }}}

# -- {{{ get_claude_project_path
# Encode project path for Claude's directory naming convention
get_claude_project_path() {
    local project_dir="$1"
    local abs_path
    abs_path=$(cd "$project_dir" 2>/dev/null && pwd) || return 1

    # Encode path: replace / with - (Claude's convention)
    # /mnt/mtwo/programming/ai-stuff/delta-version -> -mnt-mtwo-programming-ai-stuff-delta-version
    local encoded
    encoded=$(echo "$abs_path" | sed 's|/|-|g')

    local claude_projects_dir
    claude_projects_dir="${HOME:=/home/ritz}/.claude/projects"

    local claude_dir="${claude_projects_dir}/${encoded}"

    if [[ -d "$claude_dir" ]]; then
        echo "$claude_dir"
        return 0
    fi

    return 1
}
# }}}

# -- {{{ count_conversations
# Count conversations for a project
count_conversations() {
    local project_dir="$1"
    local count=0

    # Check Claude project directory
    local claude_dir
    if claude_dir=$(get_claude_project_path "$project_dir"); then
        count=$(find "$claude_dir" -maxdepth 1 -name "*.jsonl" 2>/dev/null | wc -l)
    fi

    echo "$count"
}
# }}}

# -- {{{ get_conversation_list
# Get list of conversation files for a project
get_conversation_list() {
    local project_dir="$1"
    local -a conversations=()

    local claude_dir
    if claude_dir=$(get_claude_project_path "$project_dir"); then
        while IFS= read -r conv_file; do
            conversations+=("$conv_file")
        done < <(find "$claude_dir" -maxdepth 1 -name "*.jsonl" 2>/dev/null | sort)
    fi

    printf '%s\n' "${conversations[@]}"
}
# }}}

# -- {{{ backup_project
# Execute backup for a single project
backup_project() {
    local project_dir="$1"
    local conv_count="$2"

    # Create llm-transcripts directory if it doesn't exist
    local transcripts_dir="${project_dir}/llm-transcripts"
    mkdir -p "$transcripts_dir"

    # Check if we have required scripts
    local backup_script="${DIR}/backup-conversations"
    local exporter="${DIR}/claude-conversation-exporter.sh"

    if [[ ! -x "$backup_script" ]]; then
        error "  backup-conversations not found at $backup_script"
        return 0
    fi

    # Step 1: Run backup-conversations to create baseline summaries
    echo "  Step 1/2: Running backup-conversations..."
    local backup_output
    backup_output=$("$backup_script" "$project_dir" 2>&1)

    # Count baseline transcript files created
    local baseline_files
    baseline_files=$(transcript_list_files "$transcripts_dir" | wc -l)

    if [[ $baseline_files -eq 0 ]]; then
        warn "  No summary files created by backup-conversations"
        return 0
    fi

    success "  Created $baseline_files baseline summary files"

    # Step 2: If multi-verbosity mode, export at different verbosity levels
    local total_files=$baseline_files

    if $ALL_VERBOSITY_LEVELS && [[ -x "$exporter" ]]; then
        echo "  Step 2/2: Generating multi-verbosity exports..."

        # Determine verbosity range
        local -a verbosity_levels=()
        if [[ -n "$VERBOSITY_RANGE" ]]; then
            IFS='-' read -r start_v end_v <<< "$VERBOSITY_RANGE"
            for ((v=start_v; v<=end_v; v++)); do
                verbosity_levels+=("$v")
            done
        else
            verbosity_levels=(0 1 2 3 4 5)
        fi

        # Export each conversation at each verbosity level
        local conv_num=0
        while IFS= read -r summary_file; do
            [[ -f "$summary_file" ]] || continue
            ((conv_num++))

            local conv_id
            conv_id=$(transcript_conv_id "$summary_file")

            echo "    Processing $conv_num/$baseline_files: $conv_id"

            for level in "${verbosity_levels[@]}"; do
                local level_name
                case "$level" in
                    0) level_name="minimal" ;;
                    1) level_name="compact" ;;
                    2) level_name="standard" ;;
                    3) level_name="verbose" ;;
                    4) level_name="complete" ;;
                    5) level_name="raw" ;;
                esac

                local output_file="${transcripts_dir}/${conv_id}-v${level}-${level_name}.md"

                # Run exporter at this verbosity level
                if "$exporter" -v"$level" "$project_dir" "$conv_id" > "$output_file" 2>/dev/null && [[ -s "$output_file" ]]; then
                    ((total_files++))
                else
                    # If export failed, remove empty file
                    rm -f "$output_file"
                fi
            done

            echo "      Generated ${#verbosity_levels[@]} verbosity variants"
        done < <(transcript_list_files "$transcripts_dir")

        success "  Total files generated: $total_files (baseline + variants)"
    else
        if $ALL_VERBOSITY_LEVELS && [[ ! -x "$exporter" ]]; then
            warn "  Multi-verbosity export skipped: claude-conversation-exporter.sh not found"
        fi
    fi

    # Return total files generated
    return $total_files
}
# }}}

# -- {{{ discover_projects
discover_projects() {
    local -a projects=()

    # Use list-projects.sh if available
    if [[ -x "${DELTA_VERSION_DIR}/scripts/list-projects.sh" ]]; then
        log "Discovering projects..."
        while IFS= read -r project_path; do
            [[ -z "$project_path" ]] && continue
            local project_name
            project_name=$(basename "$project_path")
            local conv_count
            conv_count=$(count_conversations "$project_path")

            if [[ $conv_count -gt 0 ]]; then
                projects+=("${project_name}|${project_path}|${conv_count}")
            fi
        done < <("${DELTA_VERSION_DIR}/scripts/list-projects.sh" --abs-paths 2>/dev/null)
    else
        error "list-projects.sh not found. Please install delta-version utilities."
        exit 1
    fi

    printf '%s\n' "${projects[@]}"
}
# }}}

# -- {{{ Main function
main() {
    log "Batch Transcript Backup - Starting"
    echo ""

    # Parse command line arguments
    parse_arguments "$@"

    # Validate verbosity level
    if ! $ALL_VERBOSITY_LEVELS && ! [[ "$VERBOSITY_LEVEL" =~ ^[0-5]$ ]]; then
        error "Invalid verbosity level: $VERBOSITY_LEVEL (must be 0-5)"
        exit 1
    fi

    # Discover projects
    local -a discovered_projects
    mapfile -t discovered_projects < <(discover_projects)

    if [[ ${#discovered_projects[@]} -eq 0 ]]; then
        warn "No projects with conversations found."
        exit 0
    fi

    log "Found ${#discovered_projects[@]} projects with conversations"
    echo ""

    # Determine which projects to process
    local -a projects_to_process=()

    if $PROCESS_ALL; then
        projects_to_process=("${discovered_projects[@]}")
    elif [[ ${#SELECTED_PROJECTS[@]} -gt 0 ]]; then
        # Filter to selected projects
        for selected in "${SELECTED_PROJECTS[@]}"; do
            for project in "${discovered_projects[@]}"; do
                IFS='|' read -r name path count <<< "$project"
                if [[ "$name" == "$selected" ]]; then
                    projects_to_process+=("$project")
                    break
                fi
            done
        done
    elif $INTERACTIVE_MODE; then
        warn "Interactive mode not yet implemented - using --all for now"
        projects_to_process=("${discovered_projects[@]}")
    else
        error "Must specify --all, -I, or project names"
        show_help
        exit 1
    fi

    if [[ ${#projects_to_process[@]} -eq 0 ]]; then
        warn "No projects selected for processing."
        exit 0
    fi

    # Show summary
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Projects to process: ${#projects_to_process[@]}${NC}"
    if $ALL_VERBOSITY_LEVELS; then
        if [[ -n "$VERBOSITY_RANGE" ]]; then
            echo -e "${BLUE}  Verbosity range: ${VERBOSITY_RANGE}${NC}"
        else
            echo -e "${BLUE}  Verbosity levels: 0-5 (all)${NC}"
        fi
    else
        echo -e "${BLUE}  Verbosity level: ${VERBOSITY_LEVEL}${NC}"
    fi
    if $DRY_RUN; then
        echo -e "${YELLOW}  DRY RUN MODE${NC}"
    fi
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo ""

    # Process each project
    local total_conversations=0
    local total_files_generated=0
    local project_num=0

    for project in "${projects_to_process[@]}"; do
        IFS='|' read -r name path count <<< "$project"
        ((project_num++))

        log "[$project_num/${#projects_to_process[@]}] Processing: $name ($count conversations)"

        if $DRY_RUN; then
            echo "  Would backup to: ${path}/llm-transcripts/"
            if $ALL_VERBOSITY_LEVELS; then
                if [[ -n "$VERBOSITY_RANGE" ]]; then
                    IFS='-' read -r start_v end_v <<< "$VERBOSITY_RANGE"
                    local num_levels=$(( end_v - start_v + 1 ))
                    echo "  Would generate $(( count * num_levels )) files ($num_levels verbosity levels per conversation)"
                else
                    echo "  Would generate $(( count * 6 )) files (6 verbosity levels per conversation)"
                fi
            else
                echo "  Would generate $count files (verbosity level $VERBOSITY_LEVEL)"
            fi
            total_conversations=$((total_conversations + count))
            continue
        fi

        # Execute backup
        backup_project "$path" "$count"
        local files_generated=$?
        total_files_generated=$((total_files_generated + files_generated))
        total_conversations=$((total_conversations + count))
        echo ""
    done

    # Show summary
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Summary${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "  Projects processed: $project_num"
    echo -e "  Total conversations: $total_conversations"
    if $ALL_VERBOSITY_LEVELS; then
        echo -e "  Files that would be generated: $(( total_conversations * 6 ))"
    else
        echo -e "  Files that would be generated: $total_conversations"
    fi

    if $DRY_RUN; then
        echo ""
        echo -e "${YELLOW}This was a dry run. Run without --dry-run to execute.${NC}"
    fi

    echo ""
    success "Batch backup complete!"
}
# }}}

# Run main function
main "$@"
