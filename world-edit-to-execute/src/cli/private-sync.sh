#!/usr/bin/env bash
# private-sync.sh - Sync X01 private materials to local bare git repository
#
# Creates and maintains a separate private git repository for materials that
# should never touch the public remote. Designed to be called from backup
# scripts or cron jobs.
#
# Usage:
#   ./private-sync.sh              # Sync to default location
#   ./private-sync.sh --init       # Initialize private repo (first time)
#   ./private-sync.sh --status     # Show sync status
#   ./private-sync.sh --remote /path/to/bare.git  # Use custom location

# {{{ Configuration
set -euo pipefail

# Project directory (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default private repo location (separate from public repo)
DEFAULT_PRIVATE_REMOTE="${HOME}/.local/share/wc3-engine-private/x01-hots-mod.git"

# Materials to sync (relative to PROJECT_DIR)
# ONLY X01 HotS-to-WC3 mod generator and resume materials
PRIVATE_DIRS=(
    "assets/generated-mods"           # Output .w3x mod files
    "assets/video-clips"              # HotS gameplay footage
    "assets/analysis-data"            # Behavior analysis results
    "assets/source-data"              # Web scrape caches
    "assets/blizzard-inquiry"         # Resume and gift package
)

# Also sync the X01 issue file itself and related source code when it exists
PRIVATE_FILES=(
    "issues/X01-hots-behavior-analysis-mod-generator.md"
    "src/mods/hots"                   # Future: HotS mod generator source
)

# Staging directory for private repo working tree
STAGING_DIR="${PROJECT_DIR}/tmp/private-staging"
# }}}

# {{{ Helper functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log "Created directory: $dir"
    fi
}
# }}}

# {{{ init_private_repo
init_private_repo() {
    local remote="$1"

    log "Initializing private bare repository at: $remote"

    # Create parent directory
    ensure_dir "$(dirname "$remote")"

    # Initialize bare repo
    if [[ -d "$remote" ]]; then
        log "Repository already exists at $remote"
        return 0
    fi

    git init --bare "$remote"
    log "Bare repository initialized"

    # Create initial structure in staging
    ensure_dir "$STAGING_DIR"
    cd "$STAGING_DIR"

    if [[ ! -d ".git" ]]; then
        git init
        git remote add origin "$remote"
    fi

    # Create README for private repo
    cat > README.md << 'EOF'
# X01: HotS Behavior Analysis - Private Repository

This repository contains private materials for the HotS-to-WC3 mod generation
project that should NOT be pushed to public remotes.

## Contents

- `generated-mods/` - Output .w3x files from the pipeline
- `video-clips/` - Downloaded gameplay footage (gitignored in main repo)
- `analysis-data/` - Extracted behavior models and statistics
- `source-data/` - Web scrape caches
- `blizzard-inquiry/` - Resume and gift package materials

## Sync

This repo is automatically synced by `src/cli/private-sync.sh` in the main
project. Run it manually or hook it into your backup scripts.

## Gift License

See `blizzard-inquiry/LICENSE-GIFT.md` for terms of the open source gift
to Blizzard Entertainment, Inc.
EOF

    # Create directory structure
    mkdir -p generated-mods video-clips analysis-data source-data blizzard-inquiry

    # Create placeholder files so directories are tracked
    for dir in generated-mods video-clips analysis-data source-data; do
        echo "# Placeholder - real content synced from main project" > "$dir/.gitkeep"
    done

    # Create gift license template
    cat > blizzard-inquiry/LICENSE-GIFT.md << 'EOF'
# Open Source Gift License

## Grant

This work is provided as an unconditional gift to:

1. **The Original Author** (creator of this repository)
2. **Blizzard Entertainment, Inc.**

## Terms

Blizzard Entertainment, Inc. is granted full, perpetual, irrevocable rights to:

- Use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of this Software
- Permit persons to whom the Software is furnished to do so
- Ignore, discard, or never acknowledge receipt of this work
- Reverse engineer any portion of this work
- Incorporate ideas or code into commercial products without attribution

## No Warranty

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.

## No Expectation

The author retains no expectation of:
- Response or acknowledgment
- Employment consideration
- Compensation of any kind
- Credit or attribution

This gift is offered in the spirit of sharing knowledge and demonstrating
capability, with no strings attached.
EOF

    git add -A
    git commit -m "Initial private repository structure"
    git push -u origin master

    log "Private repository initialized and populated"
    cd "$PROJECT_DIR"
}
# }}}

# {{{ sync_to_private
sync_to_private() {
    local remote="$1"
    local has_changes=false

    log "Syncing private materials to: $remote"

    # Ensure staging directory exists
    ensure_dir "$STAGING_DIR"
    cd "$STAGING_DIR"

    # Ensure git is set up
    if [[ ! -d ".git" ]]; then
        git init
        git remote add origin "$remote"
        git fetch origin
        git checkout -b master origin/master 2>/dev/null || git checkout -b master
    fi

    # Pull latest
    git pull origin master 2>/dev/null || true

    # Sync each private directory
    for dir in "${PRIVATE_DIRS[@]}"; do
        local src="${PROJECT_DIR}/${dir}"
        local dest_name=$(basename "$dir")
        local dest="${STAGING_DIR}/${dest_name}"

        if [[ -d "$src" ]]; then
            log "Syncing dir: $dir -> $dest_name"
            ensure_dir "$dest"

            # Use rsync for efficient sync
            rsync -av --delete \
                --exclude='.git' \
                --exclude='*.tmp' \
                "$src/" "$dest/"

            has_changes=true
        else
            log "Skipping dir (not found): $dir"
        fi
    done

    # Sync individual private files
    for file in "${PRIVATE_FILES[@]}"; do
        local src="${PROJECT_DIR}/${file}"

        if [[ -f "$src" ]]; then
            local dest_dir="${STAGING_DIR}/$(dirname "$file")"
            ensure_dir "$dest_dir"
            log "Syncing file: $file"
            cp "$src" "${STAGING_DIR}/${file}"
            has_changes=true
        elif [[ -d "$src" ]]; then
            local dest="${STAGING_DIR}/${file}"
            ensure_dir "$(dirname "$dest")"
            log "Syncing dir: $file"
            rsync -av --delete --exclude='.git' "$src/" "$dest/"
            has_changes=true
        else
            log "Skipping file (not found): $file"
        fi
    done

    # Check for changes
    if git diff --quiet && git diff --cached --quiet; then
        # Check for untracked files
        if [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
            log "No changes to sync"
            cd "$PROJECT_DIR"
            return 0
        fi
    fi

    # Stage and commit
    git add -A

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local commit_msg="Sync private materials: $timestamp"

    # Add summary of changes
    local changed_files=$(git diff --cached --name-only | head -10)
    if [[ -n "$changed_files" ]]; then
        commit_msg="$commit_msg

Changed files:
$changed_files"
    fi

    git commit -m "$commit_msg"
    git push origin master

    log "Sync complete - changes pushed to private remote"
    cd "$PROJECT_DIR"
}
# }}}

# {{{ show_status
show_status() {
    local remote="$1"

    echo "=== Private Sync Status ==="
    echo ""
    echo "Project:        $PROJECT_DIR"
    echo "Private Remote: $remote"
    echo "Staging:        $STAGING_DIR"
    echo ""

    # Check if remote exists
    if [[ -d "$remote" ]]; then
        echo "Remote Status:  EXISTS"
        echo "Remote Refs:"
        git --git-dir="$remote" show-ref --head | head -5
    else
        echo "Remote Status:  NOT INITIALIZED (run --init)"
    fi

    echo ""
    echo "Private Directories:"
    for dir in "${PRIVATE_DIRS[@]}"; do
        local src="${PROJECT_DIR}/${dir}"
        if [[ -d "$src" ]]; then
            local count=$(find "$src" -type f 2>/dev/null | wc -l)
            echo "  [EXISTS] $dir ($count files)"
        else
            echo "  [EMPTY]  $dir"
        fi
    done

    echo ""
    echo "Private Files:"
    for file in "${PRIVATE_FILES[@]}"; do
        local src="${PROJECT_DIR}/${file}"
        if [[ -f "$src" ]]; then
            local size=$(du -h "$src" 2>/dev/null | cut -f1)
            echo "  [EXISTS] $file ($size)"
        elif [[ -d "$src" ]]; then
            local count=$(find "$src" -type f 2>/dev/null | wc -l)
            echo "  [EXISTS] $file/ ($count files)"
        else
            echo "  [EMPTY]  $file"
        fi
    done

    echo ""

    # Check staging status
    if [[ -d "$STAGING_DIR/.git" ]]; then
        echo "Staging Status:"
        cd "$STAGING_DIR"
        git status --short
        echo ""
        echo "Last Sync:"
        git log -1 --format="  %ci - %s" 2>/dev/null || echo "  No commits yet"
        cd "$PROJECT_DIR"
    fi
}
# }}}

# {{{ main
main() {
    local action="sync"
    local remote="$DEFAULT_PRIVATE_REMOTE"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --init)
                action="init"
                shift
                ;;
            --status)
                action="status"
                shift
                ;;
            --remote)
                remote="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --init              Initialize private bare repository"
                echo "  --status            Show sync status"
                echo "  --remote PATH       Use custom remote location"
                echo "  --help              Show this help"
                echo ""
                echo "Default remote: $DEFAULT_PRIVATE_REMOTE"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done

    case "$action" in
        init)
            init_private_repo "$remote"
            ;;
        status)
            show_status "$remote"
            ;;
        sync)
            if [[ ! -d "$remote" ]]; then
                error "Private remote not found: $remote (run --init first)"
            fi
            sync_to_private "$remote"
            ;;
    esac
}

main "$@"
# }}}
