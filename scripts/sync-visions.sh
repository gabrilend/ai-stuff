#!/usr/bin/env bash
# sync-visions.sh - Discover and symlink vision documents from all projects
#
# Trawls through project directories, finds vision files, and creates
# symlinks in the visions/ directory for centralized access. Supports
# multiple base directories and provides statistics on documentation coverage.

set -euo pipefail

# -- {{{ Configuration
DIR="${DIR:-/home/ritz/programming/ai-stuff}"
VISIONS_DIR="${DIR}/scripts/visions"
QUIET=false
LIST_ONLY=false
STATS_ONLY=false
VERBOSE=false
INTERACTIVE=false
CLEAR_FIRST=true

# Additional directories to search (colon-separated, like PATH)
EXTRA_DIRS="${EXTRA_DIRS:-}"
# }}}

# -- {{{ log
log() {
    if [[ "$QUIET" != true ]]; then
        echo "$@"
    fi
}
# }}}

# -- {{{ verbose_log
verbose_log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[VERBOSE] $*" >&2
    fi
}
# }}}

# -- {{{ discover_vision_files
discover_vision_files() {
    local base_dir="$1"

    verbose_log "Searching for vision files in: $base_dir"

    # Search for vision files with various patterns
    # Exclude .git directories and image files
    find "$base_dir" -maxdepth 5 -type f \( \
        -name "vision" -o \
        -name "vision.md" -o \
        -name "vision-*" \
    \) 2>/dev/null | grep -v "\.git" | grep -v "\.png$" | grep -v "\.jpg$" | sort
}
# }}}

# -- {{{ extract_project_info
extract_project_info() {
    local vision_path="$1"
    local base_dir="$2"

    # Get the path relative to base_dir
    local relative="${vision_path#$base_dir/}"

    # Extract project name (first directory component, or handle nested like games/project)
    local project_path="${relative%/notes/*}"
    project_path="${project_path%/docs/*}"
    project_path="${project_path%/src/*}"

    # Handle direct vision files at project root
    if [[ "$project_path" == *"/vision"* ]]; then
        project_path="${project_path%/vision*}"
    fi

    # Convert path separators to dashes for nested projects (games/foo -> games-foo)
    local project_name="${project_path//\//-}"

    # Handle vision file variants (vision-foo -> project-foo)
    local basename
    basename=$(basename "$vision_path")
    local suffix=""

    if [[ "$basename" == vision-* ]]; then
        suffix="-${basename#vision-}"
        suffix="${suffix%.md}"
    fi

    echo "${project_name}${suffix}"
}
# }}}

# -- {{{ create_symlink
create_symlink() {
    local vision_file="$1"
    local link_name="$2"
    local target_dir="$3"

    local link_path="${target_dir}/${link_name}"

    # Remove existing symlink if present
    if [[ -L "$link_path" ]]; then
        rm -f "$link_path"
    fi

    # Create new symlink
    ln -sf "$vision_file" "$link_path"

    verbose_log "Created: $link_name -> $vision_file"
}
# }}}

# -- {{{ get_all_projects
get_all_projects() {
    local base_dir="$1"

    # Find directories that look like projects (have src/, docs/, notes/, or issues/)
    find "$base_dir" -maxdepth 3 -type d \( \
        -name "src" -o -name "docs" -o -name "notes" -o -name "issues" \
    \) 2>/dev/null | while read -r dir; do
        dirname "$dir"
    done | sort -u
}
# }}}

# -- {{{ sync_visions
sync_visions() {
    local -a search_dirs=("$DIR")

    # Add extra directories if specified
    if [[ -n "$EXTRA_DIRS" ]]; then
        IFS=':' read -ra extra <<< "$EXTRA_DIRS"
        search_dirs+=("${extra[@]}")
    fi

    # Create visions directory
    mkdir -p "$VISIONS_DIR"

    # Clear existing symlinks if requested
    if [[ "$CLEAR_FIRST" == true ]]; then
        verbose_log "Clearing existing symlinks in: $VISIONS_DIR"
        find "$VISIONS_DIR" -type l -delete 2>/dev/null || true
    fi

    local total_count=0
    local -A linked_projects

    for base_dir in "${search_dirs[@]}"; do
        if [[ ! -d "$base_dir" ]]; then
            verbose_log "Skipping non-existent directory: $base_dir"
            continue
        fi

        verbose_log "Processing base directory: $base_dir"

        while IFS= read -r vision_file; do
            local link_name
            link_name=$(extract_project_info "$vision_file" "$base_dir")

            if [[ "$LIST_ONLY" == true ]]; then
                echo "$link_name: $vision_file"
            else
                create_symlink "$vision_file" "$link_name" "$VISIONS_DIR"
                log "  Linked: $link_name"
            fi

            linked_projects["$link_name"]=1
            ((++total_count))
        done < <(discover_vision_files "$base_dir")
    done

    if [[ "$LIST_ONLY" != true ]]; then
        echo ""
        log "=== Vision Sync Complete ==="
        log "Symlinks created: $total_count"
        log "Location: $VISIONS_DIR"
    fi

    return 0
}
# }}}

# -- {{{ show_statistics
show_statistics() {
    local -a search_dirs=("$DIR")

    if [[ -n "$EXTRA_DIRS" ]]; then
        IFS=':' read -ra extra <<< "$EXTRA_DIRS"
        search_dirs+=("${extra[@]}")
    fi

    local -A projects_with_vision
    local -A all_projects

    # Find all vision files
    for base_dir in "${search_dirs[@]}"; do
        [[ ! -d "$base_dir" ]] && continue

        while IFS= read -r vision_file; do
            local project_name
            project_name=$(extract_project_info "$vision_file" "$base_dir")
            # Strip any suffix for counting unique projects
            local base_project="${project_name%%-*}"
            [[ -z "$base_project" ]] && base_project="$project_name"
            projects_with_vision["$project_name"]=1
        done < <(discover_vision_files "$base_dir")

        # Find all projects
        while IFS= read -r project_dir; do
            local project_name
            project_name=$(basename "$project_dir")
            all_projects["$project_name"]="$project_dir"
        done < <(get_all_projects "$base_dir")
    done

    local with_vision=${#projects_with_vision[@]}
    local total_projects=${#all_projects[@]}
    local without_vision=$((total_projects - with_vision))

    echo "=== Vision Documentation Statistics ==="
    echo ""
    echo "Projects with vision docs: $with_vision"
    echo "Total projects found:      $total_projects"
    echo "Coverage:                  $(( (with_vision * 100) / (total_projects > 0 ? total_projects : 1) ))%"
    echo ""

    if [[ $without_vision -gt 0 ]]; then
        echo "Projects missing vision documentation:"
        for project_name in "${!all_projects[@]}"; do
            local has_vision=false
            for vision_project in "${!projects_with_vision[@]}"; do
                if [[ "$vision_project" == "$project_name"* ]]; then
                    has_vision=true
                    break
                fi
            done
            if [[ "$has_vision" == false ]]; then
                echo "  - $project_name"
            fi
        done | sort
    fi
    echo ""

    echo "Projects with vision documentation:"
    for project in "${!projects_with_vision[@]}"; do
        echo "  + $project"
    done | sort
}
# }}}

# -- {{{ show_help
show_help() {
    cat <<'EOF'
Usage: sync-visions.sh [OPTIONS]

Discover and symlink vision documents from all projects.

Searches through project directories for vision files and creates
symlinks in a centralized visions/ directory for easy access.

Options:
    -d, --dir DIR        Base directory to search (default: $DIR or ~/programming/ai-stuff)
    -o, --output DIR     Output directory for symlinks (default: scripts/visions/)
    -e, --extra DIRS     Additional directories to search (colon-separated)
    -l, --list           List vision files without creating symlinks
    -s, --stats          Show statistics only (no syncing)
    -q, --quiet          Suppress output except errors
    -v, --verbose        Show detailed progress
    --no-clear           Don't clear existing symlinks before syncing
    -I, --interactive    Interactive mode (future: TUI selection)
    -h, --help           Show this help message

Vision File Patterns Searched:
    notes/vision, notes/vision.md, notes/vision-*
    docs/vision, docs/vision.md
    vision, vision.md (at project root)

Symlink Naming:
    project-name           -> project/notes/vision
    nested-project         -> nested/project/notes/vision
    project-variant        -> project/notes/vision-variant

Examples:
    # Sync all vision files
    sync-visions.sh

    # List vision files without syncing
    sync-visions.sh --list

    # Show statistics on vision documentation coverage
    sync-visions.sh --stats

    # Search additional directories
    sync-visions.sh --extra "/other/projects:/more/projects"

    # Custom output location
    sync-visions.sh --output ~/visions

Environment Variables:
    DIR          Base directory (default: /home/ritz/programming/ai-stuff)
    EXTRA_DIRS   Additional search directories (colon-separated)

EOF
}
# }}}

# -- {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                DIR="$2"
                shift 2
                ;;
            -o|--output)
                VISIONS_DIR="$2"
                shift 2
                ;;
            -e|--extra)
                EXTRA_DIRS="$2"
                shift 2
                ;;
            -l|--list)
                LIST_ONLY=true
                shift
                ;;
            -s|--stats)
                STATS_ONLY=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-clear)
                CLEAR_FIRST=false
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
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
            *)
                # Positional argument - treat as base directory
                DIR="$1"
                shift
                ;;
        esac
    done
}
# }}}

# -- {{{ main
main() {
    parse_args "$@"

    if [[ "$STATS_ONLY" == true ]]; then
        show_statistics
    else
        sync_visions
    fi
}
# }}}

main "$@"
