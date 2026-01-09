#!/usr/bin/env bash
# manage-worktree.sh - Create and manage git worktrees for parallel development
#
# Provides isolated working directories for each issue, enabling multiple
# AI agents to work on the same project simultaneously. Each worktree gets
# its own branch and directory, sharing the same git repository.
#
# Usage:
#   manage-worktree.sh create <issue-number> <project>
#   manage-worktree.sh remove <issue-number> <project>
#   manage-worktree.sh list [project]
#   manage-worktree.sh status
#   manage-worktree.sh path <issue-number> <project>

set -euo pipefail

# -- {{{ Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
WORKTREE_ROOT="${WORKTREE_ROOT:-/mnt/mtwo/programming/ai-worktrees}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Valid project names (directories in the main repo)
VALID_PROJECTS=("delta-version" "neocities-modernization" "world-edit-to-execute")
# }}}

# -- {{{ log
log() {
    echo "[INFO] $*" >&2
}
# }}}

# -- {{{ error
error() {
    echo "[ERROR] $*" >&2
}
# }}}

# -- {{{ get_short_project_name
get_short_project_name() {
    # Returns shortened project name for directory/branch naming
    local project="$1"
    case "$project" in
        delta-version) echo "dv" ;;
        neocities-modernization) echo "neo" ;;
        world-edit-to-execute) echo "wete" ;;
        *) echo "$project" ;;
    esac
}
# }}}

# -- {{{ validate_project
validate_project() {
    local project="$1"
    for valid in "${VALID_PROJECTS[@]}"; do
        [[ "$project" == "$valid" ]] && return 0
    done
    error "Invalid project: $project"
    error "Valid projects: ${VALID_PROJECTS[*]}"
    return 1
}
# }}}

# -- {{{ get_worktree_path
get_worktree_path() {
    local issue_num="$1"
    local project="$2"
    local short_name
    short_name=$(get_short_project_name "$project")
    echo "$WORKTREE_ROOT/$short_name/issue-$issue_num"
}
# }}}

# -- {{{ get_branch_name
get_branch_name() {
    local issue_num="$1"
    local project="$2"
    local short_name
    short_name=$(get_short_project_name "$project")
    echo "$short_name/issue-$issue_num"
}
# }}}

# -- {{{ ensure_worktree_root
ensure_worktree_root() {
    if [[ ! -d "$WORKTREE_ROOT" ]]; then
        log "Creating worktree root: $WORKTREE_ROOT"
        mkdir -p "$WORKTREE_ROOT"
    fi
}
# }}}

# -- {{{ ensure_dev_branch
ensure_dev_branch() {
    # Ensure the project's development branch exists
    local project="$1"
    local short_name
    short_name=$(get_short_project_name "$project")
    local dev_branch="$short_name/dev"

    cd "$DIR"
    if ! git rev-parse --verify "$dev_branch" >/dev/null 2>&1; then
        log "Creating project dev branch: $dev_branch"
        git branch "$dev_branch" master
    fi
}
# }}}

# -- {{{ cmd_create
cmd_create() {
    local issue_num="${1:-}"
    local project="${2:-}"

    if [[ -z "$issue_num" ]] || [[ -z "$project" ]]; then
        error "Usage: $0 create <issue-number> <project>"
        error "Example: $0 create 017 delta-version"
        return 1
    fi

    validate_project "$project" || return 1
    ensure_worktree_root
    ensure_dev_branch "$project"

    local worktree_path
    worktree_path=$(get_worktree_path "$issue_num" "$project")
    local branch_name
    branch_name=$(get_branch_name "$issue_num" "$project")
    local short_name
    short_name=$(get_short_project_name "$project")

    # Check if worktree already exists
    if [[ -d "$worktree_path" ]]; then
        error "Worktree already exists: $worktree_path"
        error "Use 'remove' first if you want to recreate it"
        return 1
    fi

    # Create project subdirectory in worktree root
    mkdir -p "$WORKTREE_ROOT/$short_name"

    cd "$DIR"

    # Check if branch already exists
    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        log "Branch $branch_name already exists, creating worktree from it"
        git worktree add "$worktree_path" "$branch_name"
    else
        # Create new branch from project dev branch
        local dev_branch="$short_name/dev"
        log "Creating new branch $branch_name from $dev_branch"
        git worktree add -b "$branch_name" "$worktree_path" "$dev_branch"
    fi

    echo ""
    echo "=========================================="
    echo "Worktree created successfully!"
    echo "=========================================="
    echo ""
    echo "  Branch:    $branch_name"
    echo "  Directory: $worktree_path"
    echo ""
    echo "To start working:"
    echo "  cd $worktree_path/$project"
    echo ""
    echo "When finished, merge from main repo:"
    echo "  cd $DIR"
    echo "  git checkout $short_name/dev"
    echo "  git merge $branch_name"
    echo "  $0 remove $issue_num $project"
    echo ""
}
# }}}

# -- {{{ cmd_remove
cmd_remove() {
    local issue_num="${1:-}"
    local project="${2:-}"

    if [[ -z "$issue_num" ]] || [[ -z "$project" ]]; then
        error "Usage: $0 remove <issue-number> <project>"
        return 1
    fi

    validate_project "$project" || return 1

    local worktree_path
    worktree_path=$(get_worktree_path "$issue_num" "$project")
    local branch_name
    branch_name=$(get_branch_name "$issue_num" "$project")

    if [[ ! -d "$worktree_path" ]]; then
        error "Worktree does not exist: $worktree_path"
        return 1
    fi

    cd "$DIR"

    # Check for uncommitted changes
    if [[ -n "$(git -C "$worktree_path" status --porcelain 2>/dev/null)" ]]; then
        error "Worktree has uncommitted changes!"
        error "Please commit or stash changes before removing."
        git -C "$worktree_path" status --short
        return 1
    fi

    log "Removing worktree: $worktree_path"
    git worktree remove "$worktree_path"

    echo ""
    echo "Worktree removed: $worktree_path"
    echo ""
    echo "The branch '$branch_name' still exists."
    echo "To delete it: git branch -d $branch_name"
    echo ""
}
# }}}

# -- {{{ cmd_list
cmd_list() {
    local project="${1:-}"

    cd "$DIR"

    echo "Active Worktrees"
    echo "================"
    echo ""

    if [[ -n "$project" ]]; then
        validate_project "$project" || return 1
        local short_name
        short_name=$(get_short_project_name "$project")
        git worktree list | grep -E "$short_name/issue-" || echo "  (none for $project)"
    else
        git worktree list
    fi

    echo ""
}
# }}}

# -- {{{ cmd_status
cmd_status() {
    cd "$DIR"

    echo "Worktree Status"
    echo "==============="
    echo ""

    local worktrees
    worktrees=$(git worktree list --porcelain | grep "^worktree " | sed 's/^worktree //')

    for wt in $worktrees; do
        [[ "$wt" == "$DIR" ]] && continue  # Skip main worktree

        local branch
        branch=$(git -C "$wt" branch --show-current 2>/dev/null || echo "detached")
        local status
        status=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

        local status_indicator="✓"
        [[ "$status" -gt 0 ]] && status_indicator="⚠ ($status changes)"

        echo "  $branch"
        echo "    Path: $wt"
        echo "    Status: $status_indicator"
        echo ""
    done

    if [[ -z "$worktrees" ]] || [[ "$worktrees" == "$DIR" ]]; then
        echo "  (no active worktrees)"
        echo ""
    fi
}
# }}}

# -- {{{ cmd_path
cmd_path() {
    local issue_num="${1:-}"
    local project="${2:-}"

    if [[ -z "$issue_num" ]] || [[ -z "$project" ]]; then
        error "Usage: $0 path <issue-number> <project>"
        return 1
    fi

    validate_project "$project" || return 1

    local worktree_path
    worktree_path=$(get_worktree_path "$issue_num" "$project")

    if [[ -d "$worktree_path" ]]; then
        echo "$worktree_path/$project"
    else
        error "Worktree does not exist: $worktree_path"
        return 1
    fi
}
# }}}

# -- {{{ show_help
show_help() {
    cat << 'EOF'
Usage: manage-worktree.sh <command> [arguments]

Manage git worktrees for parallel multi-agent development.

Commands:
    create <issue-num> <project>   Create worktree for an issue
    remove <issue-num> <project>   Remove worktree (fails if uncommitted changes)
    list [project]                 List active worktrees
    status                         Show all worktrees with change status
    path <issue-num> <project>     Print path to worktree project directory

Projects:
    delta-version              (short: dv)
    neocities-modernization    (short: neo)
    world-edit-to-execute      (short: wete)

Examples:
    # Create worktree for issue 017 in delta-version
    manage-worktree.sh create 017 delta-version

    # Start working
    cd $(manage-worktree.sh path 017 delta-version)

    # List all worktrees
    manage-worktree.sh list

    # Show status of all worktrees
    manage-worktree.sh status

    # Remove worktree after merging
    manage-worktree.sh remove 017 delta-version

Workflow:
    1. Create worktree: manage-worktree.sh create <issue> <project>
    2. Work in worktree: cd <worktree-path>/<project>/
    3. Commit changes normally
    4. From main repo: git merge <branch> into <project>/dev
    5. Remove worktree: manage-worktree.sh remove <issue> <project>

Environment Variables:
    DIR             Main repository path (default: /mnt/mtwo/programming/ai-stuff)
    WORKTREE_ROOT   Worktree storage path (default: /mnt/mtwo/programming/ai-worktrees)
EOF
}
# }}}

# -- {{{ main
main() {
    local command="${1:-}"

    case "$command" in
        create)
            shift
            cmd_create "$@"
            ;;
        remove|rm)
            shift
            cmd_remove "$@"
            ;;
        list|ls)
            shift
            cmd_list "$@"
            ;;
        status|st)
            cmd_status
            ;;
        path)
            shift
            cmd_path "$@"
            ;;
        -h|--help|help)
            show_help
            ;;
        "")
            show_help
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}
# }}}

main "$@"
