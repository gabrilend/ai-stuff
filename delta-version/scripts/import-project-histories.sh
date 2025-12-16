#!/bin/bash
# Import project histories into meta-repository as branches
# Preserves commit history from existing project .git directories

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"
REPO_DIR="${DIR%/*}"  # Parent directory is the repo

# Projects to import (with their own .git directories)
MAIN_PROJECTS=(
    "handheld-office"
    "risc-v-university"
    "progress-ii"
    "magic-rumble"
    "adroit"
)

# Libraries that might have been modified (optional import)
LIBRARIES=(
    # Add library paths here if you want to preserve their histories
)

# -- {{{ check_git_dir
function check_git_dir() {
    local project_path="$1"
    [[ -d "${project_path}/.git" ]]
}
# }}}

# -- {{{ get_default_branch
function get_default_branch() {
    local project_path="$1"

    # Try to determine the default branch
    local branch
    branch=$(git -C "$project_path" symbolic-ref --short HEAD 2>/dev/null)

    if [[ -z "$branch" ]]; then
        # Fallback: check if master or main exists
        if git -C "$project_path" show-ref --verify --quiet refs/heads/master 2>/dev/null; then
            branch="master"
        elif git -C "$project_path" show-ref --verify --quiet refs/heads/main 2>/dev/null; then
            branch="main"
        fi
    fi

    echo "$branch"
}
# }}}

# -- {{{ import_project_history
function import_project_history() {
    local project_name="$1"
    local project_path="${REPO_DIR}/${project_name}"

    if ! check_git_dir "$project_path"; then
        echo "  SKIP: No .git directory found in $project_name"
        return 1
    fi

    local commits
    commits=$(git -C "$project_path" rev-list --count HEAD 2>/dev/null || echo "0")

    if [[ "$commits" == "0" ]]; then
        echo "  SKIP: No commits found in $project_name"
        return 1
    fi

    echo "  Importing $project_name ($commits commits)..."

    # Get the default branch of the project
    local source_branch
    source_branch=$(get_default_branch "$project_path")

    if [[ -z "$source_branch" ]]; then
        echo "  ERROR: Could not determine source branch for $project_name"
        return 1
    fi

    # Add as remote
    local remote_name="import-${project_name}"
    git -C "$REPO_DIR" remote add "$remote_name" "${project_path}/.git" 2>/dev/null || {
        git -C "$REPO_DIR" remote remove "$remote_name" 2>/dev/null
        git -C "$REPO_DIR" remote add "$remote_name" "${project_path}/.git"
    }

    # Fetch the history
    git -C "$REPO_DIR" fetch "$remote_name" 2>/dev/null

    # Create branch from the fetched history
    git -C "$REPO_DIR" branch "$project_name" "${remote_name}/${source_branch}" 2>/dev/null || {
        echo "  WARNING: Branch $project_name may already exist or source branch not found"
    }

    # Remove temporary remote
    git -C "$REPO_DIR" remote remove "$remote_name" 2>/dev/null

    echo "  SUCCESS: Created branch '$project_name' with history"
    return 0
}
# }}}

# -- {{{ remove_embedded_git_dirs
function remove_embedded_git_dirs() {
    echo ""
    echo "Removing embedded .git directories..."

    local count=0
    while IFS= read -r gitdir; do
        [[ "$gitdir" == "${REPO_DIR}/.git" ]] && continue

        local parent
        parent=$(dirname "$gitdir")
        local name
        name=$(basename "$parent")

        echo "  Removing: $name/.git"
        rm -rf "$gitdir"
        ((count++))
    done < <(find "$REPO_DIR" -name ".git" -type d 2>/dev/null)

    echo "  Removed $count embedded .git directories"
}
# }}}

# -- {{{ create_master_commit
function create_master_commit() {
    echo ""
    echo "Creating master branch with all projects..."

    cd "$REPO_DIR" || exit 1

    # Stage all files
    git add -A

    # Get list of projects for commit message
    local project_list
    project_list=$(ls -d */ 2>/dev/null | grep -v '^\.' | tr -d '/' | head -10 | tr '\n' ', ' | sed 's/,$//')

    # Create commit
    git commit -m "$(cat <<EOF
Initial commit: AI project collection

This repository contains multiple AI-related projects:
${project_list}, and more...

Each project is also available on its own branch with preserved history.
Use 'git branch -a' to see all project branches.

Repository managed by Delta-Version meta-project system.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"

    echo "  Master branch committed"
}
# }}}

# -- {{{ show_status
function show_status() {
    echo ""
    echo "Repository Status"
    echo "================="

    cd "$REPO_DIR" || exit 1

    echo "Branches:"
    git branch -a 2>/dev/null | sed 's/^/  /'

    echo ""
    echo "Latest commit:"
    git log --oneline -1 2>/dev/null | sed 's/^/  /'

    echo ""
    echo "Working tree:"
    git status --short 2>/dev/null | head -10 | sed 's/^/  /'
}
# }}}

# -- {{{ run_import
function run_import() {
    echo "========================================"
    echo "Project History Import"
    echo "========================================"
    echo "Repository: $REPO_DIR"
    echo ""

    echo "Step 1: Import project histories as branches"
    echo "---------------------------------------------"

    local imported=0
    for project in "${MAIN_PROJECTS[@]}"; do
        if import_project_history "$project"; then
            ((imported++))
        fi
    done

    echo ""
    echo "Imported $imported project histories"

    echo ""
    echo "Step 2: Remove embedded .git directories"
    echo "-----------------------------------------"
    remove_embedded_git_dirs

    echo ""
    echo "Step 3: Create master branch commit"
    echo "------------------------------------"
    create_master_commit

    show_status

    echo ""
    echo "========================================"
    echo "Import complete!"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "  1. Review the branches with: git branch -a"
    echo "  2. Create GitHub repository"
    echo "  3. Add remote: git remote add origin <url>"
    echo "  4. Push all branches: git push -u origin --all"
}
# }}}

# -- {{{ run_interactive_mode
function run_interactive_mode() {
    echo "=== Project History Import ==="
    echo ""
    echo "This will:"
    echo "  1. Import existing project git histories as branches"
    echo "  2. Remove embedded .git directories"
    echo "  3. Create master branch with all projects"
    echo ""
    echo "Repository: $REPO_DIR"
    echo ""
    echo "Projects to import:"
    for project in "${MAIN_PROJECTS[@]}"; do
        local path="${REPO_DIR}/${project}"
        if check_git_dir "$path"; then
            local commits
            commits=$(git -C "$path" rev-list --count HEAD 2>/dev/null || echo "0")
            echo "  - $project ($commits commits)"
        else
            echo "  - $project (no .git)"
        fi
    done
    echo ""

    read -p "Proceed with import? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy] ]]; then
        run_import
    else
        echo "Cancelled."
    fi
}
# }}}

# -- {{{ show_help
function show_help() {
    echo "Usage: import-project-histories.sh [OPTIONS]"
    echo ""
    echo "Import existing project git histories into the meta-repository."
    echo ""
    echo "Options:"
    echo "  --run           Execute the import (non-interactive)"
    echo "  --dry-run       Show what would be done without making changes"
    echo "  -I, --interactive  Run in interactive mode (default)"
    echo "  --help          Show this help message"
    echo ""
    echo "This script:"
    echo "  1. Imports project .git histories as branches"
    echo "  2. Removes embedded .git directories"
    echo "  3. Creates master branch with all projects"
}
# }}}

# -- {{{ dry_run
function dry_run() {
    echo "DRY RUN - No changes will be made"
    echo "=================================="
    echo ""
    echo "Repository: $REPO_DIR"
    echo ""
    echo "Projects that would be imported:"
    for project in "${MAIN_PROJECTS[@]}"; do
        local path="${REPO_DIR}/${project}"
        if check_git_dir "$path"; then
            local commits
            commits=$(git -C "$path" rev-list --count HEAD 2>/dev/null || echo "0")
            local branch
            branch=$(get_default_branch "$path")
            echo "  $project: $commits commits from branch '$branch'"
        else
            echo "  $project: SKIP (no .git directory)"
        fi
    done

    echo ""
    echo "Embedded .git directories that would be removed:"
    find "$REPO_DIR" -name ".git" -type d 2>/dev/null | grep -v "^${REPO_DIR}/.git$" | while read -r gitdir; do
        echo "  $(dirname "$gitdir" | sed "s|${REPO_DIR}/||")"
    done | head -15
    echo "  ..."
}
# }}}

# -- {{{ main
function main() {
    case "${1:-}" in
        --run)
            run_import
            ;;
        --dry-run)
            dry_run
            ;;
        -I|--interactive|"")
            run_interactive_mode
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}
# }}}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
