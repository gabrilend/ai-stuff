#!/usr/bin/env bash
# batch-transcript-backup.sh - Batch LLM transcript backup with TUI selection
#
# Creates backups of LLM transcripts across all projects in the monorepo.
# Supports interactive project selection, multiple verbosity levels, and batch operations.
#
# For each chosen project it runs backup-conversations (the baseline
# transcripts), then, if any verbosity level was asked for, the exporter once
# per conversation per level.  -I picks the projects and levels from a menu;
# --since limits the run to conversations that changed since a date;
# --commit commits each project's llm-transcripts folder and nothing else.
# (Issue 009.)  --output-dir puts the level exports elsewhere, --combined
# joins the run's baseline transcripts into one file, --metadata lists each
# conversation's exports, and --parallel runs a conversation's levels at the
# same time.  (Issue 042.)

# -- {{{ Script Directory and Path Setup
DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
MONOREPO_ROOT="$(dirname "$DIR")"
DELTA_VERSION_DIR="${MONOREPO_ROOT}/delta-version"
LIBS_DIR="${DIR}/libs"
# Transcripts are recognised by their header line, not a filename suffix, so
# date-range renaming leaves this batch tool finding them unchanged.
source "${LIBS_DIR}/transcript-discovery.sh"
# The menu library is sourced here, at the top level, so its tables are
# global (sourced inside a function they would be local to it).
source "${LIBS_DIR}/lua-menu.sh"
# }}}

# -- {{{ Configuration Variables
INTERACTIVE_MODE=false
DRY_RUN=false
PROCESS_ALL=false
ALL_VERBOSITY_LEVELS=false
VERBOSITY_LEVEL=2
VERBOSITY_GIVEN=false
AUTO_COMMIT=false
VERBOSITY_RANGE=""
SINCE_DATE=""
SELECTED_PROJECTS=()
OUTPUT_DIR=""
COMBINED=false
METADATA=false
PARALLEL=1
# Baseline transcripts this run covered, "name|file", for --combined.
COMBINED_PARTS=()
# The verbosity levels to export, worked out once from the options (or the
# menu).  Empty: baseline transcripts only.
EXPORT_LEVELS=()
# Set by backup_project: how many files are in place for the project.
LAST_FILES_WRITTEN=0
FAILED_PROJECTS=()
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
    -I, --interactive       Choose projects and levels from a menu
    -a, --all               Process all projects
    -n, --dry-run           Show what would be done without executing
    -v, --verbosity LEVEL   Also export each conversation at LEVEL (0-5)
    --all-verbosity-levels  Also export each conversation at every level (v0-v5)
    --verbosity-range N-M   Also export each conversation at levels N to M (e.g., 2-4)
    --since DATE            Only conversations changed since DATE
                            (any date 'date -d' reads, e.g. 2026-10-01)
    --commit                Commit each project's llm-transcripts folder afterwards
                            (and the --output-dir folder and --combined file)
    --output-dir DIR        Write level exports to DIR/<project>/ instead of
                            <project>/llm-transcripts/ (baselines stay there)
    --combined              Also join this run's baseline transcripts into one
                            file, combined-<YYYY-MM-DD>.md, in --output-dir or
                            the monorepo's llm-transcripts/
    --metadata              Beside each conversation's level exports, write
                            <id>.exports.txt: file, bytes, when exported
    --parallel N            Export up to N levels of a conversation at once
    -h, --help              Show this help message

Without -v, --all-verbosity-levels or --verbosity-range only the baseline
transcripts are written (backup-conversations).

VERBOSITY LEVELS:
    0 (minimal)   - Code and essential content only
    1 (compact)   - Skip sentiments, show responses
    2 (standard)  - Complete conversation
    3 (verbose)   - Include context files and expansions
    4 (complete)  - Everything + LLM execution details
    5 (raw)       - ALL intermediate steps and tool results

EXAMPLES:
    # Interactive mode
    batch-transcript-backup.sh -I

    # Process all projects, with a level-4 export of each conversation
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

# -- {{{ need_value
# An option that takes a value must have one.
need_value() {
    if [[ $# -lt 2 || -z "$2" ]]; then
        error "$1 needs a value"
        exit 1
    fi
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
                need_value "$@"
                VERBOSITY_LEVEL="$2"
                VERBOSITY_GIVEN=true
                shift 2
                ;;
            --all-verbosity-levels)
                ALL_VERBOSITY_LEVELS=true
                shift
                ;;
            --verbosity-range)
                need_value "$@"
                VERBOSITY_RANGE="$2"
                ALL_VERBOSITY_LEVELS=true
                shift 2
                ;;
            --commit)
                AUTO_COMMIT=true
                shift
                ;;
            --since)
                need_value "$@"
                SINCE_DATE="$2"
                shift 2
                ;;
            --output-dir)
                need_value "$@"
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --combined)
                COMBINED=true
                shift
                ;;
            --metadata)
                METADATA=true
                shift
                ;;
            --parallel)
                need_value "$@"
                PARALLEL="$2"
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

# -- {{{ validate_options
# Checks the values, and works out EXPORT_LEVELS from them.
validate_options() {
    if [[ -n "$VERBOSITY_RANGE" ]]; then
        if ! [[ "$VERBOSITY_RANGE" =~ ^([0-5])-([0-5])$ ]] \
            || (( BASH_REMATCH[1] > BASH_REMATCH[2] )); then
            error "Invalid verbosity range: $VERBOSITY_RANGE (want N-M, 0 <= N <= M <= 5)"
            exit 1
        fi
    fi
    if $VERBOSITY_GIVEN && ! [[ "$VERBOSITY_LEVEL" =~ ^[0-5]$ ]]; then
        error "Invalid verbosity level: $VERBOSITY_LEVEL (must be 0-5)"
        exit 1
    fi
    if [[ -n "$SINCE_DATE" ]] && ! date -d "$SINCE_DATE" >/dev/null 2>&1; then
        error "Invalid --since date: $SINCE_DATE"
        exit 1
    fi
    if ! [[ "$PARALLEL" =~ ^[1-9][0-9]*$ ]]; then
        error "Invalid --parallel count: $PARALLEL (want a whole number, 1 or more)"
        exit 1
    fi
    if [[ -n "$OUTPUT_DIR" ]]; then
        if ! mkdir -p "$OUTPUT_DIR" 2>/dev/null; then
            error "Cannot make --output-dir $OUTPUT_DIR"
            exit 1
        fi
        OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
    fi

    EXPORT_LEVELS=()
    local v
    if [[ -n "$VERBOSITY_RANGE" ]]; then
        for ((v = ${VERBOSITY_RANGE%-*}; v <= ${VERBOSITY_RANGE#*-}; v++)); do
            EXPORT_LEVELS+=("$v")
        done
    elif $ALL_VERBOSITY_LEVELS; then
        EXPORT_LEVELS=(0 1 2 3 4 5)
    elif $VERBOSITY_GIVEN; then
        EXPORT_LEVELS=("$VERBOSITY_LEVEL")
    fi
}
# }}}

# -- {{{ level_name
level_name() {
    case "$1" in
        0) echo "minimal" ;;
        1) echo "compact" ;;
        2) echo "standard" ;;
        3) echo "verbose" ;;
        4) echo "complete" ;;
        5) echo "raw" ;;
    esac
}
# }}}

# -- {{{ is_level_file
# True for a level export's name: <id>-v<N>-<level name>.md.
is_level_file() {
    [[ "$(basename "$1")" =~ -v[0-5]-(minimal|compact|standard|verbose|complete|raw)\.md$ ]]
}
# }}}

# -- {{{ export_dir_for
# Where a project's level exports go: <output-dir>/<project> with
# --output-dir, else beside the baselines in <project>/llm-transcripts.
export_dir_for() {
    local project_dir="$1" name="$2"
    if [[ -n "$OUTPUT_DIR" ]]; then
        echo "$OUTPUT_DIR/$name"
    else
        echo "$project_dir/llm-transcripts"
    fi
}
# }}}

# -- {{{ combined_file_path
combined_file_path() {
    echo "${OUTPUT_DIR:-$MONOREPO_ROOT/llm-transcripts}/combined-$(date +%F).md"
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

# -- {{{ get_conversation_list
# The project's conversation logs, one path per line.  With --since, only
# the logs changed since that date.
get_conversation_list() {
    local project_dir="$1"
    local claude_dir
    claude_dir=$(get_claude_project_path "$project_dir") || return 0
    if [[ -n "$SINCE_DATE" ]]; then
        find "$claude_dir" -maxdepth 1 -name "*.jsonl" -newermt "$SINCE_DATE" 2>/dev/null | sort
    else
        find "$claude_dir" -maxdepth 1 -name "*.jsonl" 2>/dev/null | sort
    fi
}
# }}}

# -- {{{ count_conversations
# Count conversations for a project (with --since, only the changed ones)
count_conversations() {
    get_conversation_list "$1" | grep -c . || true
}
# }}}

# -- {{{ backup_project
# Backs up one project.  Sets LAST_FILES_WRITTEN to the conversations with a
# transcript plus the level files written (the count used to travel back in
# the exit status, which wraps at 256) and returns 1 if a step failed.
# Adds the baseline transcripts it covered to COMBINED_PARTS.
backup_project() {
    local project_dir="$1" name="$2"
    LAST_FILES_WRITTEN=0

    # Create llm-transcripts directory if it doesn't exist
    local transcripts_dir="${project_dir}/llm-transcripts"
    mkdir -p "$transcripts_dir"

    # Check if we have required scripts
    local backup_script="${DIR}/backup-conversations"
    local exporter="${DIR}/claude-conversation-exporter.sh"

    if [[ ! -x "$backup_script" ]]; then
        error "  backup-conversations not found at $backup_script"
        return 1
    fi

    # Step 1: Run backup-conversations to create baseline summaries.  Its
    # messages are shown when it fails, not thrown away.
    echo "  Step 1/2: Running backup-conversations..."
    local backup_output
    if ! backup_output=$("$backup_script" "$project_dir" 2>&1); then
        error "  backup-conversations failed for $project_dir; its messages:"
        printf '%s\n' "$backup_output" | sed 's/^/    /' >&2
        return 1
    fi

    # Count baseline transcript files
    local baseline_files
    baseline_files=$(transcript_list_files "$transcripts_dir" | wc -l)

    if [[ $baseline_files -eq 0 ]]; then
        warn "  No summary files created by backup-conversations"
        return 0
    fi

    # One entry per conversation: an exported level file starts with the
    # same header line as the baseline, so it is listed as a transcript too.
    local -A seen=() baseline_of=()
    local -a all_ids=()
    local summary_file conv_id
    while IFS= read -r summary_file; do
        conv_id=$(transcript_conv_id "$summary_file") || continue
        if ! is_level_file "$summary_file"; then
            baseline_of["$conv_id"]="$summary_file"
        fi
        [[ -n "${seen[$conv_id]:-}" ]] && continue
        seen["$conv_id"]=1
        all_ids+=("$conv_id")
    done < <(transcript_list_files "$transcripts_dir")

    success "  ${#all_ids[@]} conversations have a transcript"
    LAST_FILES_WRITTEN=${#all_ids[@]}

    # With --since, only conversations whose log changed since the date.
    local -a conv_ids=("${all_ids[@]}")
    if [[ -n "$SINCE_DATE" ]]; then
        local -A wanted=()
        local log_file
        while IFS= read -r log_file; do
            [[ -n "$log_file" ]] && wanted["$(basename "$log_file" .jsonl)"]=1
        done < <(get_conversation_list "$project_dir")
        conv_ids=()
        for conv_id in "${all_ids[@]}"; do
            [[ -n "${wanted[$conv_id]:-}" ]] && conv_ids+=("$conv_id")
        done
    fi
    for conv_id in "${conv_ids[@]}"; do
        [[ -n "${baseline_of[$conv_id]:-}" ]] && COMBINED_PARTS+=("${name}|${baseline_of[$conv_id]}")
    done

    # Step 2: export at each level asked for
    if [[ ${#EXPORT_LEVELS[@]} -eq 0 ]]; then
        return 0
    fi
    if [[ ! -x "$exporter" ]]; then
        warn "  Verbosity exports skipped: claude-conversation-exporter.sh not found"
        return 0
    fi

    local export_dir
    export_dir="$(export_dir_for "$project_dir" "$name")"
    mkdir -p "$export_dir"
    echo "  Step 2/2: Exporting at levels ${EXPORT_LEVELS[*]} into $export_dir..."

    # Each level's output, messages and exit status go to files of their own,
    # so levels can run side by side (--parallel) and a failure still says
    # which level it was.  Results are read back in level order.
    local work
    work="$(mktemp -d "${TMPDIR:-/tmp}/batch-backup.XXXXXX")" || return 1

    local conv_num=0 level output_file failed=0 written=0 rc
    for conv_id in "${conv_ids[@]}"; do
        conv_num=$((conv_num + 1))
        echo "    Processing $conv_num/${#conv_ids[@]}: $conv_id"
        for level in "${EXPORT_LEVELS[@]}"; do
            while (( $(jobs -rp | wc -l) >= PARALLEL )); do
                wait -n
            done
            (
                "$exporter" -v"$level" "$project_dir" "$conv_id" \
                    > "$work/$level.out" 2> "$work/$level.err"
                echo $? > "$work/$level.rc"
            ) &
        done
        wait

        local -a meta_lines=()
        for level in "${EXPORT_LEVELS[@]}"; do
            output_file="${export_dir}/${conv_id}-v${level}-$(level_name "$level").md"
            rc="$(cat "$work/$level.rc" 2>/dev/null || echo 1)"
            if [[ -s "$work/$level.err" ]]; then
                sed "s/^/      level $level: /" "$work/$level.err" >&2
            fi
            if [[ "$rc" != 0 ]]; then
                error "      level $level export of $conv_id failed (exit $rc; its messages are above)"
                failed=1
            elif [[ ! -s "$work/$level.out" ]]; then
                # Issue 009 recorded that some levels can come out empty;
                # that is the exporter's choice, not a failure of this run.
                warn "      level $level export of $conv_id was empty; no file kept"
            else
                mv -f "$work/$level.out" "$output_file"
                written=$((written + 1))
                meta_lines+=("$(basename "$output_file")	$(stat -c %s "$output_file")	$(date -Iseconds)")
            fi
            rm -f -- "${work:?}/${level:?}.out" "${work:?}/${level:?}.err" "${work:?}/${level:?}.rc"
        done

        # --metadata: written after the exports, listing only those that
        # were written, so a failed export is never listed.
        if $METADATA && [[ ${#meta_lines[@]} -gt 0 ]]; then
            printf '%s\n' "${meta_lines[@]}" > "${export_dir}/${conv_id}.exports.txt"
        fi
    done
    rmdir -- "$work" 2>/dev/null

    LAST_FILES_WRITTEN=$(( ${#all_ids[@]} + written ))
    success "  Level exports written: $written"
    return $failed
}
# }}}

# -- {{{ commit_paths
# Commits the named paths in the repository that holds <where>, and only
# them, so nothing else that happens to be staged is swept into the commit.
# commit_paths <where> <label> <message> <path...>  (paths relative to <where>)
commit_paths() {
    local where="$1" label="$2" message="$3"
    shift 3
    if ! git -C "$where" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        warn "  --commit: $where is not in a git repository; $label not committed"
        return 1
    fi
    if ! git -C "$where" add -A -- "$@"; then
        warn "  --commit: could not stage $label; not committed"
        return 1
    fi
    if git -C "$where" diff --cached --quiet -- "$@"; then
        echo "  Nothing new to commit in $label"
        return 0
    fi
    if git -C "$where" commit -q -m "$message" -- "$@"; then
        success "  Committed $label"
    else
        warn "  --commit: the commit for $label failed"
        return 1
    fi
}
# }}}

# -- {{{ commit_transcripts
# Commits one project's llm-transcripts folder, and its --output-dir folder
# when there is one.
commit_transcripts() {
    local project_dir="$1" name="$2"
    local status=0
    commit_paths "$project_dir" "$name" "Back up ${name}'s LLM transcripts" llm-transcripts || status=1
    if [[ -n "$OUTPUT_DIR" && -d "$OUTPUT_DIR/$name" ]]; then
        commit_paths "$OUTPUT_DIR/$name" "$OUTPUT_DIR/$name" "Export ${name}'s LLM transcripts" . || status=1
    fi
    return $status
}
# }}}

# -- {{{ write_combined
# Joins the run's baseline transcripts into one file, project by project.
write_combined() {
    local dest="$1" part name file last=""
    mkdir -p "$(dirname "$dest")" || return 1
    {
        echo "# Combined LLM transcripts, $(date +%F)"
        echo ""
        echo "Projects: $(printf '%s\n' "${COMBINED_PARTS[@]}" | cut -d'|' -f1 | uniq | paste -sd' ')"
        for part in "${COMBINED_PARTS[@]}"; do
            name="${part%%|*}"
            file="${part#*|}"
            if [[ "$name" != "$last" ]]; then
                echo ""
                echo "## $name"
                last="$name"
            fi
            echo ""
            echo "### $(basename "$file")"
            echo ""
            cat "$file"
        done
    } > "$dest"
}
# }}}

# -- {{{ discover_projects
# Prints name|path|count for each project with conversations.  Only those
# lines go to stdout: the caller reads every stdout line as a project.
discover_projects() {
    local -a projects=()

    # Use list-projects.sh if available
    if [[ -x "${DELTA_VERSION_DIR}/scripts/list-projects.sh" ]]; then
        log "Discovering projects..." >&2
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

    if [[ ${#projects[@]} -gt 0 ]]; then
        printf '%s\n' "${projects[@]}"
    fi
}
# }}}

# -- {{{ run_interactive_menu
# Shows the projects as checkboxes, then the export level (a radio list), dry run and
# commit choices, and a Run button (r).  Fills the array named by $1 with the
# chosen projects and sets EXPORT_LEVELS, DRY_RUN and AUTO_COMMIT.  Returns 1
# if the menu was left without running.
run_interactive_menu() {
    local -n chosen_ref="$1"
    shift
    local -a discovered=("$@")
    local entry name path count i

    menu_init
    menu_set_title "LLM Transcript Backup" "Choose projects, then Run"

    menu_add_section "projects" "multi" "Projects"
    menu_add_item "projects" "all_projects" "All projects" "checkbox" "0" \
        "Back up every project in the list"
    i=0
    for entry in "${discovered[@]}"; do
        IFS='|' read -r name path count <<< "$entry"
        i=$((i + 1))
        menu_add_item "projects" "p$i" "$name ($count conversations)" "checkbox" "0" "$path"
        menu_add_dependency "p$i" "all_projects" "1" "true" "Included: All projects is on" "yellow"
    done
    menu_set_section_max_visible "projects" 15

    # The level choice starts where the command line left it.  The menu
    # offers none, one level or all; a narrower range is the command line's.
    local level_default="baseline"
    if [[ ${#EXPORT_LEVELS[@]} -eq 6 ]]; then
        level_default="all"
    elif [[ ${#EXPORT_LEVELS[@]} -eq 1 ]]; then
        level_default="v${EXPORT_LEVELS[0]}"
    elif [[ ${#EXPORT_LEVELS[@]} -gt 1 ]]; then
        warn "The menu offers one level or all; it starts at all in place of --verbosity-range $VERBOSITY_RANGE" >&2
        level_default="all"
    fi
    # The levels are a radio list: lua-menu.sh has no way to hand a
    # multistate item its list of states.
    menu_add_section "levels" "single" "Export levels"
    local lv
    for lv in baseline v0 v1 v2 v3 v4 v5 all; do
        local lv_text
        case "$lv" in
            baseline) lv_text="Baseline only" ;;
            all) lv_text="Every level, v0-v5" ;;
            *) lv_text="Also level ${lv#v} ($(level_name "${lv#v}"))" ;;
        esac
        menu_add_item "levels" "level_$lv" "$lv_text" "checkbox" \
            "$([[ "$lv" == "$level_default" ]] && echo 1 || echo 0)" \
            "baseline: backup-conversations only; a level: the exporter too"
    done
    menu_add_section "options" "multi" "Options"
    menu_add_item "options" "dry_run" "Dry run" "checkbox" "$($DRY_RUN && echo 1 || echo 0)" \
        "Show what would be done without doing it"
    menu_add_item "options" "commit" "Commit afterwards" "checkbox" "$($AUTO_COMMIT && echo 1 || echo 0)" \
        "Commit each project's llm-transcripts folder, and nothing else"
    menu_add_item "options" "combined" "Combined file too" "checkbox" "$($COMBINED && echo 1 || echo 0)" \
        "Also join the run's baseline transcripts into one combined-<date>.md"

    menu_add_section "actions" "single" "Actions"
    menu_add_item "actions" "run" "Run Backup" "action" "" "Back up the chosen projects" "r"

    if ! menu_run; then
        return 1
    fi

    local all_on
    all_on=$(menu_get_value "all_projects")
    i=0
    for entry in "${discovered[@]}"; do
        i=$((i + 1))
        if [[ "$all_on" == "1" || "$(menu_get_value "p$i")" == "1" ]]; then
            chosen_ref+=("$entry")
        fi
    done

    local picked=baseline
    for lv in baseline v0 v1 v2 v3 v4 v5 all; do
        [[ "$(menu_get_value "level_$lv")" == "1" ]] && picked="$lv"
    done
    case "$picked" in
        all) EXPORT_LEVELS=(0 1 2 3 4 5) ;;
        v[0-5]) EXPORT_LEVELS=("${picked#v}") ;;
        *) EXPORT_LEVELS=() ;;
    esac
    [[ "$(menu_get_value "dry_run")" == "1" ]] && DRY_RUN=true || DRY_RUN=false
    [[ "$(menu_get_value "commit")" == "1" ]] && AUTO_COMMIT=true || AUTO_COMMIT=false
    [[ "$(menu_get_value "combined")" == "1" ]] && COMBINED=true || COMBINED=false
    return 0
}
# }}}

# -- {{{ Main function
main() {
    log "Batch Transcript Backup - Starting"
    echo ""

    # Parse command line arguments
    parse_arguments "$@"
    validate_options

    # Discover projects
    local -a discovered_projects=()
    mapfile -t discovered_projects < <(discover_projects)

    if [[ ${#discovered_projects[@]} -eq 0 ]]; then
        if [[ -n "$SINCE_DATE" ]]; then
            warn "No projects with conversations changed since $SINCE_DATE."
        else
            warn "No projects with conversations found."
        fi
        exit 0
    fi

    log "Found ${#discovered_projects[@]} projects with conversations"
    echo ""

    # Determine which projects to process
    local -a projects_to_process=()
    local project name path count

    if $PROCESS_ALL; then
        projects_to_process=("${discovered_projects[@]}")
    elif [[ ${#SELECTED_PROJECTS[@]} -gt 0 ]]; then
        # Filter to selected projects; a name that matches nothing is an
        # error, so a typo is not quietly skipped.
        local -a unknown=()
        local selected found
        for selected in "${SELECTED_PROJECTS[@]}"; do
            found=false
            for project in "${discovered_projects[@]}"; do
                IFS='|' read -r name path count <<< "$project"
                if [[ "$name" == "$selected" ]]; then
                    projects_to_process+=("$project")
                    found=true
                    break
                fi
            done
            $found || unknown+=("$selected")
        done
        if [[ ${#unknown[@]} -gt 0 ]]; then
            error "No conversations to back up for: ${unknown[*]} (not a project, or nothing found)"
            exit 1
        fi
    elif $INTERACTIVE_MODE; then
        if ! run_interactive_menu projects_to_process "${discovered_projects[@]}"; then
            log "Menu closed without running; nothing done."
            exit 0
        fi
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
    if [[ ${#EXPORT_LEVELS[@]} -gt 0 ]]; then
        echo -e "${BLUE}  Export levels: ${EXPORT_LEVELS[*]}${NC}"
    else
        echo -e "${BLUE}  Export levels: none (baseline transcripts only)${NC}"
    fi
    if [[ -n "$SINCE_DATE" ]]; then
        echo -e "${BLUE}  Conversations changed since: ${SINCE_DATE}${NC}"
    fi
    if $DRY_RUN; then
        echo -e "${YELLOW}  DRY RUN MODE${NC}"
    fi
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo ""

    # Process each project
    local total_conversations=0
    local total_files=0
    local project_num=0
    local num_levels=${#EXPORT_LEVELS[@]}

    for project in "${projects_to_process[@]}"; do
        IFS='|' read -r name path count <<< "$project"
        project_num=$((project_num + 1))

        log "[$project_num/${#projects_to_process[@]}] Processing: $name ($count conversations)"
        total_conversations=$((total_conversations + count))

        if $DRY_RUN; then
            echo "  Would backup to: ${path}/llm-transcripts/"
            if [[ $num_levels -gt 0 ]]; then
                echo "  Would export $(( count * num_levels )) files ($num_levels levels per conversation)"
            fi
            if [[ -n "$OUTPUT_DIR" && $num_levels -gt 0 ]]; then
                echo "  Level exports would go to: $(export_dir_for "$path" "$name")/"
            fi
            if $AUTO_COMMIT; then
                echo "  Would commit ${path}/llm-transcripts/"
            fi
            continue
        fi

        if ! backup_project "$path" "$name"; then
            FAILED_PROJECTS+=("$name")
        fi
        total_files=$((total_files + LAST_FILES_WRITTEN))

        if $AUTO_COMMIT; then
            commit_transcripts "$path" "$name" || FAILED_PROJECTS+=("$name(commit)")
        fi
        echo ""
    done

    # --combined: one file joining this run's baseline transcripts.
    if $COMBINED; then
        local combined
        combined="$(combined_file_path)"
        if $DRY_RUN; then
            echo "Would join the baseline transcripts into: $combined"
        elif [[ ${#COMBINED_PARTS[@]} -eq 0 ]]; then
            warn "No baseline transcripts to combine; no combined file written"
        elif write_combined "$combined"; then
            success "Combined ${#COMBINED_PARTS[@]} transcripts into $combined"
            if $AUTO_COMMIT; then
                commit_paths "$(dirname "$combined")" "$(basename "$combined")" \
                    "Combined LLM transcripts, $(date +%F)" "$(basename "$combined")" \
                    || FAILED_PROJECTS+=("combined(commit)")
            fi
        else
            error "Could not write $combined"
            FAILED_PROJECTS+=("combined")
        fi
    fi

    # Show summary
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Summary${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "  Projects processed: $project_num"
    echo -e "  Total conversations: $total_conversations"
    if $DRY_RUN; then
        echo -e "  Level exports that would be written: $(( total_conversations * num_levels ))"
        echo ""
        echo -e "${YELLOW}This was a dry run. Run without --dry-run to execute.${NC}"
    else
        echo -e "  Transcripts in place plus level files written: $total_files"
    fi

    echo ""
    if [[ ${#FAILED_PROJECTS[@]} -gt 0 ]]; then
        error "Finished with failures: ${FAILED_PROJECTS[*]}"
        exit 1
    fi
    success "Batch backup complete!"
}
# }}}

# Run main function
main "$@"
