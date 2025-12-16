#!/bin/bash
# {{{ Dependency Sync System
# Automatically syncs external project dependencies into libs directory
# Designed for progress-ii ↔ adroit integration

# Hard-coded DIR path as per CLAUDE.md requirements
# Only use first argument as DIR if it's a valid directory path
if [[ "$1" && -d "$1" ]]; then
    DIR="$1"
    shift  # Remove DIR from arguments
else
    DIR="/home/ritz/programming/ai-stuff/progress-ii"
fi

cd "$DIR" || {
    echo "❌ Error: Cannot access progress-ii directory: $DIR"
    exit 1
}

# {{{ Configuration
# Dependency definitions - add new dependencies here
declare -A DEPENDENCIES=(
    ["adroit"]="https://github.com/gabrilend/adroit.git"
    # Add future dependencies here:
    # ["other-project"]="https://github.com/user/repo.git"
)

declare -A DEPENDENCY_BRANCHES=(
    ["adroit"]="main"
    # ["other-project"]="main"
)

# Local paths for dependencies (relative to progress-ii root)
declare -A DEPENDENCY_PATHS=(
    ["adroit"]="libs/adroit"
    # ["other-project"]="libs/other-project"
)
# }}}

# {{{ Color output for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}
# }}}

# {{{ sync_dependency
sync_dependency() {
    local dep_name="$1"
    local repo_url="${DEPENDENCIES[$dep_name]}"
    local branch="${DEPENDENCY_BRANCHES[$dep_name]}"
    local local_path="${DEPENDENCY_PATHS[$dep_name]}"
    
    if [[ -z "$repo_url" ]]; then
        log_error "Unknown dependency: $dep_name"
        return 1
    fi
    
    log_info "Syncing dependency: $dep_name"
    log_info "Repository: $repo_url"
    log_info "Branch: $branch"
    log_info "Local path: $local_path"
    
    # Check if this is HTTPS and credentials might be needed
    if [[ "$repo_url" == https://* ]]; then
        log_info "Using HTTPS authentication (may prompt for GitHub credentials)"
    fi
    
    # Create libs directory if it doesn't exist
    mkdir -p "$(dirname "$local_path")"
    
    if [[ -d "$local_path" ]]; then
        # Directory exists - check if it's a git repository
        if [[ -d "$local_path/.git" ]]; then
            log_info "Updating existing repository..."
            (
                cd "$local_path" || exit 1
                
                # Check if this is the correct repository
                local current_remote
                current_remote=$(git remote get-url origin 2>/dev/null || echo "")
                
                if [[ "$current_remote" != "$repo_url" ]]; then
                    log_warning "Remote URL mismatch. Expected: $repo_url, Found: $current_remote"
                    log_info "Removing and re-cloning..."
                    cd .. || exit 1
                    rm -rf "$(basename "$local_path")"
                    git clone -b "$branch" "$repo_url" "$(basename "$local_path")"
                else
                    # Correct repository - fetch and reset
                    log_info "Fetching latest changes..."
                    git fetch origin "$branch"
                    
                    # Hard reset to match remote (dependencies should not be modified locally)
                    log_info "Resetting to origin/$branch..."
                    git reset --hard "origin/$branch"
                    
                    # Clean any untracked files
                    git clean -fd
                fi
            )
        else
            # Directory exists but not a git repo - remove and clone
            log_warning "Directory exists but is not a git repository. Removing and re-cloning..."
            rm -rf "$local_path"
            git clone -b "$branch" "$repo_url" "$local_path"
        fi
    else
        # Directory doesn't exist - clone fresh
        log_info "Cloning fresh repository..."
        git clone -b "$branch" "$repo_url" "$local_path"
    fi
    
    # Verify clone/update was successful
    if [[ -d "$local_path/.git" ]]; then
        local commit_hash
        commit_hash=$(cd "$local_path" && git rev-parse HEAD 2>/dev/null)
        log_success "Dependency synced successfully. Commit: ${commit_hash:0:8}"
        
        # Show dependency info
        local commit_message
        commit_message=$(cd "$local_path" && git log -1 --pretty=format:"%s" 2>/dev/null)
        log_info "Latest commit: $commit_message"
        
        return 0
    else
        log_error "Failed to sync dependency: $dep_name"
        return 1
    fi
}
# }}}

# {{{ sync_all_dependencies
sync_all_dependencies() {
    local failed_deps=()
    local success_count=0
    local total_count=${#DEPENDENCIES[@]}
    
    echo ""
    echo "🔄 ═══════════════════════════════════════════════════════════════════ 🔄"
    echo "                        DEPENDENCY SYNC STARTING"
    echo "                      Syncing $total_count dependencies"
    echo "🔄 ═══════════════════════════════════════════════════════════════════ 🔄"
    echo ""
    
    for dep_name in "${!DEPENDENCIES[@]}"; do
        echo "────────────────────────────────────────────────────────────────────"
        if sync_dependency "$dep_name"; then
            ((success_count++))
        else
            failed_deps+=("$dep_name")
        fi
        echo ""
    done
    
    echo "🔄 ═══════════════════════════════════════════════════════════════════ 🔄"
    echo "                        DEPENDENCY SYNC COMPLETE"
    echo ""
    
    if [[ ${#failed_deps[@]} -eq 0 ]]; then
        log_success "All $total_count dependencies synced successfully!"
    else
        log_warning "Synced $success_count/$total_count dependencies"
        log_error "Failed dependencies: ${failed_deps[*]}"
        return 1
    fi
    
    echo "🔄 ═══════════════════════════════════════════════════════════════════ 🔄"
    echo ""
}
# }}}

# {{{ check_dependency_status
check_dependency_status() {
    echo ""
    echo "📊 Dependency Status Report:"
    echo "────────────────────────────────────────"
    
    for dep_name in "${!DEPENDENCIES[@]}"; do
        local local_path="${DEPENDENCY_PATHS[$dep_name]}"
        
        if [[ -d "$local_path/.git" ]]; then
            local commit_hash
            local commit_date
            local commit_message
            
            commit_hash=$(cd "$local_path" && git rev-parse HEAD 2>/dev/null)
            commit_date=$(cd "$local_path" && git log -1 --pretty=format:"%ci" 2>/dev/null)
            commit_message=$(cd "$local_path" && git log -1 --pretty=format:"%s" 2>/dev/null)
            
            echo "✅ $dep_name"
            echo "   Path: $local_path"
            echo "   Commit: ${commit_hash:0:8}"
            echo "   Date: $commit_date"
            echo "   Message: $commit_message"
        else
            echo "❌ $dep_name - Not synced"
            echo "   Path: $local_path"
            echo "   Status: Directory missing or not a git repository"
        fi
        echo ""
    done
}
# }}}

# {{{ clean_dependencies
clean_dependencies() {
    echo ""
    log_warning "Cleaning all dependencies..."
    
    for dep_name in "${!DEPENDENCIES[@]}"; do
        local local_path="${DEPENDENCY_PATHS[$dep_name]}"
        
        if [[ -d "$local_path" ]]; then
            log_info "Removing $dep_name ($local_path)"
            rm -rf "$local_path"
        else
            log_info "$dep_name already clean"
        fi
    done
    
    log_success "All dependencies cleaned"
}
# }}}

# {{{ build_dependency
build_dependency() {
    local dep_name="$1"
    local local_path="${DEPENDENCY_PATHS[$dep_name]}"
    
    if [[ ! -d "$local_path" ]]; then
        log_error "Dependency $dep_name not found. Run sync first."
        return 1
    fi
    
    log_info "Building dependency: $dep_name"
    
    # Check for Makefile and build
    if [[ -f "$local_path/src/Makefile" ]]; then
        (
            cd "$local_path/src" || exit 1
            log_info "Running make in $local_path/src..."
            make clean 2>/dev/null || true
            make
        )
        
        if [[ $? -eq 0 ]]; then
            log_success "Successfully built $dep_name"
        else
            log_error "Build failed for $dep_name"
            return 1
        fi
    elif [[ -f "$local_path/Makefile" ]]; then
        (
            cd "$local_path" || exit 1
            log_info "Running make in $local_path..."
            make clean 2>/dev/null || true  # Clean any existing build
            make
        )
        
        if [[ $? -eq 0 ]]; then
            log_success "Successfully built $dep_name"
        else
            log_error "Build failed for $dep_name"
            return 1
        fi
    else
        log_warning "No Makefile found for $dep_name. Skipping build."
    fi
}
# }}}

# {{{ build_all_dependencies
build_all_dependencies() {
    log_info "Building all dependencies..."
    
    for dep_name in "${!DEPENDENCIES[@]}"; do
        echo "────────────────────────────────────────────────────────────────────"
        build_dependency "$dep_name"
        echo ""
    done
}
# }}}

# {{{ Main script logic
main() {
    case "${1:-sync}" in
        "sync")
            sync_all_dependencies
            ;;
        "status")
            check_dependency_status
            ;;
        "clean")
            clean_dependencies
            ;;
        "build")
            if [[ -n "$2" ]]; then
                build_dependency "$2"
            else
                build_all_dependencies
            fi
            ;;
        "rebuild")
            sync_all_dependencies && build_all_dependencies
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [command] [dependency]"
            echo ""
            echo "Commands:"
            echo "  sync                   Sync all dependencies (default)"
            echo "  status                 Show dependency status"
            echo "  clean                  Remove all dependencies"
            echo "  build [dependency]     Build dependency (or all if no name given)"
            echo "  rebuild                Sync and build all dependencies"
            echo "  help                   Show this help"
            echo ""
            echo "Available dependencies:"
            for dep in "${!DEPENDENCIES[@]}"; do
                echo "  - $dep: ${DEPENDENCIES[$dep]}"
            done
            echo ""
            echo "Authentication:"
            echo "  Uses HTTPS authentication for GitHub repositories"
            echo "  Run './libs/setup-github-auth.sh' to configure credentials"
            echo "  First sync will prompt for GitHub username and personal access token"
            echo ""
            echo "Example usage:"
            echo "  $0 sync                # Sync all dependencies"
            echo "  $0 build adroit        # Build only adroit"
            echo "  $0 status              # Check what's currently synced"
            echo "  $0 rebuild             # Full clean sync and build"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}
# }}}

# Interactive mode support as per CLAUDE.md
if [[ "$1" = "-I" ]]; then
    echo "🔧 Interactive Dependency Management"
    echo ""
    echo "Available commands:"
    echo "1. Sync all dependencies"
    echo "2. Check dependency status"
    echo "3. Clean dependencies" 
    echo "4. Build dependencies"
    echo "5. Full rebuild (sync + build)"
    echo "6. Exit"
    echo ""
    
    while true; do
        read -p "Select option (1-6): " choice
        
        case $choice in
            1)
                sync_all_dependencies
                ;;
            2)
                check_dependency_status
                ;;
            3)
                echo "⚠️  This will remove all dependency directories. Continue? (y/N)"
                read -p "> " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    clean_dependencies
                fi
                ;;
            4)
                build_all_dependencies
                ;;
            5)
                sync_all_dependencies && build_all_dependencies
                ;;
            6)
                echo "👋 Exiting dependency management"
                exit 0
                ;;
            *)
                echo "Invalid selection. Please choose 1-6."
                ;;
        esac
        
        echo ""
        echo "Press Enter to continue..."
        read
        echo ""
    done
else
    # Run main function with all arguments
    main "$@"
fi
# }}}