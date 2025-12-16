#!/bin/bash

# Git Integration Library for Progress-II
# Handles game state versioning through git with automatic commits and rollback functionality
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source required libraries
source "${DIR}/libs/state-directory.sh"

# Git configuration
GIT_GAME_STATE_DIR="${DIR}/game-state"
GIT_COMMIT_PREFIX="[PROGRESS-II]"
GIT_AUTO_COMMIT=true

# {{{ initialize_git_repository
initialize_git_repository() {
    local game_state_dir="${1:-$GIT_GAME_STATE_DIR}"
    
    echo "Initializing git repository for game state versioning..."
    
    # Check if game-state directory exists
    if [ ! -d "$game_state_dir" ]; then
        echo "Error: Game state directory does not exist: $game_state_dir" >&2
        return 1
    fi
    
    cd "$game_state_dir" || return 1
    
    # Initialize git repository if it doesn't exist
    if [ ! -d ".git" ]; then
        echo "Creating new git repository..."
        if ! git init; then
            echo "Error: Failed to initialize git repository" >&2
            return 1
        fi
    else
        echo "Git repository already exists"
    fi
    
    # Configure git settings for game use
    configure_git_settings "$game_state_dir"
    
    # Create .gitignore for temporary files
    cat > .gitignore << 'EOF'
# Temporary files
*.tmp
*.lock
*.bak

# System files
.DS_Store
Thumbs.db

# Log files that are too large
logs/debug/*.log
EOF
    
    # Initial commit if repository is empty
    if ! git log --oneline -1 >/dev/null 2>&1; then
        echo "Creating initial commit..."
        git add .
        git commit -m "${GIT_COMMIT_PREFIX} Initial game state repository

Game state versioning system initialized for Progress-II.
This repository tracks all game progress and enables time rewind mechanics.

Created: $(date '+%Y-%m-%d %H:%M:%S')" || {
            echo "Warning: Initial commit failed"
            return 1
        }
    fi
    
    echo "Git repository initialization complete"
    return 0
}
# }}}

# {{{ configure_git_settings
configure_git_settings() {
    local game_state_dir="${1:-$GIT_GAME_STATE_DIR}"
    
    cd "$game_state_dir" || return 1
    
    echo "Configuring git settings for game use..."
    
    # Set user identity for game commits
    git config user.name "Progress-II Game Engine"
    git config user.email "progress-ii@localhost"
    
    # Optimize for frequent small commits
    git config core.preloadindex true
    git config core.fscache true
    git config gc.auto 256
    
    # Set up automatic garbage collection to prevent repository bloat
    git config gc.autopacklimit 50
    git config gc.autodetach true
    
    # Configure compression for better performance
    git config core.compression 1
    git config core.loosecompression 1
    
    # Set safe directory to avoid ownership issues
    git config --global --add safe.directory "$game_state_dir"
    
    echo "Git configuration complete"
}
# }}}

# {{{ validate_git_status
validate_git_status() {
    local game_state_dir="${1:-$GIT_GAME_STATE_DIR}"
    
    cd "$game_state_dir" || return 1
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "Error: Not a git repository" >&2
        return 1
    fi
    
    # Check repository integrity
    if ! git fsck --quiet 2>/dev/null; then
        echo "Warning: Git repository integrity check failed" >&2
        return 1
    fi
    
    # Check for uncommitted changes
    if ! git diff --quiet; then
        echo "Status: Uncommitted changes detected"
        return 2
    fi
    
    echo "Git repository status: OK"
    return 0
}
# }}}

# {{{ create_save_commit
create_save_commit() {
    local commit_message="$1"
    local character_name="$2"
    local level="$3"
    local location="$4"
    local game_state_dir="${5:-$GIT_GAME_STATE_DIR}"
    
    cd "$game_state_dir" || return 1
    
    echo "Creating save commit..."
    
    # Generate automatic commit message if none provided
    if [ -z "$commit_message" ]; then
        commit_message=$(generate_commit_message "$character_name" "$level" "$location")
    fi
    
    # Stage all changes
    if ! git add .; then
        echo "Error: Failed to stage changes" >&2
        return 1
    fi
    
    # Check if there are any changes to commit
    if git diff --cached --quiet; then
        echo "No changes to commit"
        return 0
    fi
    
    # Create commit with metadata
    local full_message
    full_message=$(add_commit_metadata "$commit_message" "$character_name" "$level" "$location")
    
    if git commit -m "$full_message"; then
        echo "Save commit created successfully"
        
        # Get commit hash for reference
        local commit_hash
        commit_hash=$(git rev-parse HEAD)
        echo "Commit hash: $commit_hash"
        
        return 0
    else
        echo "Error: Failed to create commit" >&2
        return 1
    fi
}
# }}}

# {{{ generate_commit_message
generate_commit_message() {
    local character_name="$1"
    local level="$2"
    local location="$3"
    local timestamp="${4:-$(date '+%Y-%m-%d %H:%M:%S')}"
    
    echo "${GIT_COMMIT_PREFIX} Save: $character_name (Lv$level) at $location

Character progression saved at $location.
Level: $level
Timestamp: $timestamp
"
}
# }}}

# {{{ add_commit_metadata
add_commit_metadata() {
    local base_message="$1"
    local character_name="$2"
    local level="$3"
    local location="$4"
    local timestamp="${5:-$(date '+%Y-%m-%d %H:%M:%S')}"
    
    cat << EOF
$base_message

--- Game State Metadata ---
Character: $character_name
Level: $level
Location: $location
Timestamp: $timestamp
Game Version: Phase1_v0.1
Save Type: Manual

--- Technical Info ---
Repository: Progress-II Game State
Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
Files Changed: $(git diff --cached --name-only | wc -l)
Total Commits: $(($(git rev-list --count HEAD 2>/dev/null || echo 0) + 1))
EOF
}
# }}}

# {{{ list_rollback_points
list_rollback_points() {
    local game_state_dir="${1:-$GIT_GAME_STATE_DIR}"
    local limit="${2:-20}"
    
    cd "$game_state_dir" || return 1
    
    echo "Available Rollback Points:"
    echo "========================="
    
    # Get commit log with custom format
    git log --oneline --graph --decorate -n "$limit" --format="%C(yellow)%h%C(reset) %C(green)%ad%C(reset) %C(blue)%s%C(reset)" --date=short | while read -r line; do
        # Extract commit hash from the line
        local commit_hash
        commit_hash=$(echo "$line" | grep -o '[0-9a-f]\{7,\}' | head -1)
        
        echo "$line"
        
        # Try to extract metadata from commit message
        if [ -n "$commit_hash" ]; then
            local metadata
            metadata=$(git show --format="%b" -s "$commit_hash" 2>/dev/null | grep -E "^(Character|Level|Location):" | head -3)
            if [ -n "$metadata" ]; then
                echo "$metadata" | sed 's/^/    /'
                echo
            fi
        fi
    done
}
# }}}

# {{{ preview_rollback_changes
preview_rollback_changes() {
    local target_commit="$1"
    local game_state_dir="${2:-$GIT_GAME_STATE_DIR}"
    
    cd "$game_state_dir" || return 1
    
    echo "Rollback Preview: $target_commit"
    echo "================================"
    
    # Validate commit exists
    if ! git rev-parse "$target_commit" >/dev/null 2>&1; then
        echo "Error: Invalid commit: $target_commit" >&2
        return 1
    fi
    
    # Show commit information
    echo "Target Commit Information:"
    echo "-------------------------"
    git show --format="%h %ad %s%n%b" --date=short -s "$target_commit"
    echo
    
    # Show what files would change
    echo "Files that will be affected:"
    echo "---------------------------"
    git diff --name-status "$target_commit"..HEAD | while read -r status file; do
        case "$status" in
            A) echo "  [ADDED]    $file (will be removed)" ;;
            D) echo "  [DELETED]  $file (will be restored)" ;;
            M) echo "  [MODIFIED] $file (will be reverted)" ;;
            *) echo "  [CHANGED]  $file" ;;
        esac
    done
    
    echo
    echo "Summary:"
    echo "--------"
    local files_affected
    files_affected=$(git diff --name-only "$target_commit"..HEAD | wc -l)
    echo "Files affected: $files_affected"
    echo "Current commit: $(git rev-parse --short HEAD)"
    echo "Target commit:  $(git rev-parse --short "$target_commit")"
}
# }}}

# {{{ rollback_to_commit
rollback_to_commit() {
    local target_commit="$1"
    local create_backup_branch="${2:-true}"
    local game_state_dir="${3:-$GIT_GAME_STATE_DIR}"
    
    cd "$game_state_dir" || return 1
    
    echo "Initiating rollback to commit: $target_commit"
    
    # Validate commit exists
    if ! git rev-parse "$target_commit" >/dev/null 2>&1; then
        echo "Error: Invalid commit: $target_commit" >&2
        return 1
    fi
    
    # Check for uncommitted changes
    if ! git diff --quiet; then
        echo "Warning: Uncommitted changes detected"
        echo "Stashing current changes..."
        git stash push -m "Auto-stash before rollback at $(date)"
    fi
    
    # Create backup branch if requested
    if [ "$create_backup_branch" = "true" ]; then
        local backup_branch="backup-$(date '+%Y%m%d-%H%M%S')"
        echo "Creating backup branch: $backup_branch"
        git branch "$backup_branch" HEAD
    fi
    
    # Perform the rollback
    echo "Performing rollback..."
    if git reset --hard "$target_commit"; then
        echo "Rollback completed successfully"
        echo "Repository is now at commit: $(git rev-parse --short HEAD)"
        
        # Clean up untracked files that might have been created after target commit
        git clean -fd
        
        return 0
    else
        echo "Error: Rollback failed" >&2
        
        # Try to recover if backup branch exists
        if [ "$create_backup_branch" = "true" ] && git show-ref --verify --quiet "refs/heads/$backup_branch"; then
            echo "Attempting to restore from backup branch..."
            git reset --hard "$backup_branch"
        fi
        
        return 1
    fi
}
# }}}

# {{{ confirm_rollback_operation
confirm_rollback_operation() {
    local target_commit="$1"
    
    echo "⚠️  ROLLBACK CONFIRMATION ⚠️"
    echo "============================="
    echo
    echo "You are about to rollback to commit: $target_commit"
    echo "This will PERMANENTLY LOSE all progress after that point!"
    echo
    echo "Current game state will be backed up in a separate branch."
    echo
    read -p "Type 'CONFIRM ROLLBACK' to proceed: " confirmation
    
    if [ "$confirmation" = "CONFIRM ROLLBACK" ]; then
        echo "Rollback confirmed by user"
        return 0
    else
        echo "Rollback cancelled"
        return 1
    fi
}
# }}}

# {{{ cleanup_git_repository
cleanup_git_repository() {
    local game_state_dir="${1:-$GIT_GAME_STATE_DIR}"
    local aggressive="${2:-false}"
    
    cd "$game_state_dir" || return 1
    
    echo "Cleaning up git repository..."
    
    # Remove backup branches older than 30 days
    echo "Removing old backup branches..."
    git branch | grep "backup-" | while read -r branch; do
        # Extract date from branch name
        local branch_date
        branch_date=$(echo "$branch" | sed 's/backup-\([0-9]\{8\}\).*/\1/')
        if [ ${#branch_date} -eq 8 ]; then
            local days_old
            days_old=$(( ($(date +%s) - $(date -d "$branch_date" +%s)) / 86400 ))
            if [ "$days_old" -gt 30 ]; then
                echo "Deleting old backup branch: $branch"
                git branch -D "$branch"
            fi
        fi
    done
    
    # Run garbage collection
    echo "Running git garbage collection..."
    git gc
    
    if [ "$aggressive" = "true" ]; then
        echo "Performing aggressive cleanup..."
        git gc --aggressive --prune=now
        git repack -ad
    fi
    
    echo "Repository cleanup complete"
    local repo_size
    repo_size=$(du -sh .git | cut -f1)
    echo "Repository size: $repo_size"
}
# }}}

# {{{ get_git_status_info
get_git_status_info() {
    local game_state_dir="${1:-$GIT_GAME_STATE_DIR}"
    
    cd "$game_state_dir" || return 1
    
    echo "Git Repository Status:"
    echo "====================="
    echo "Directory: $game_state_dir"
    echo "Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
    echo "Latest commit: $(git rev-parse --short HEAD 2>/dev/null || echo "none")"
    echo "Total commits: $(git rev-list --count HEAD 2>/dev/null || echo "0")"
    echo "Repository size: $(du -sh .git 2>/dev/null | cut -f1 || echo "unknown")"
    
    # Count uncommitted changes
    local modified_files untracked_files
    modified_files=$(git diff --name-only | wc -l)
    untracked_files=$(git ls-files --others --exclude-standard | wc -l)
    
    echo "Modified files: $modified_files"
    echo "Untracked files: $untracked_files"
    
    # Show recent activity
    echo ""
    echo "Recent commits:"
    echo "--------------"
    git log --oneline -5 2>/dev/null || echo "No commits yet"
}
# }}}

# Export functions for use by other scripts
export -f initialize_git_repository
export -f configure_git_settings
export -f validate_git_status
export -f create_save_commit
export -f generate_commit_message
export -f add_commit_metadata
export -f list_rollback_points
export -f preview_rollback_changes
export -f rollback_to_commit
export -f confirm_rollback_operation
export -f cleanup_git_repository
export -f get_git_status_info