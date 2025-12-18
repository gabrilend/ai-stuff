#!/usr/bin/env bash
# maintain-gitignore.sh - Gitignore maintenance and workflow integration
#
# Unified interface for gitignore management:
# - Change detection via checksums
# - Health monitoring and reporting
# - Incremental updates
# - New project detection
# - Git workflow integration
#
# Usage: ./maintain-gitignore.sh [OPTIONS] [ACTION]

set -euo pipefail

# -- {{{ Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# State files
STATE_DIR="${DIR}/delta-version/assets/gitignore-state"
CHECKSUMS_FILE="${STATE_DIR}/checksums.txt"
KNOWN_PROJECTS_FILE="${STATE_DIR}/known-projects.txt"
MAINTENANCE_LOG="${STATE_DIR}/maintenance.log"
LAST_SCAN_FILE="${STATE_DIR}/last-scan.txt"

# Configuration
GITIGNORE_FILE="${DIR}/.gitignore"
BACKUP_DIR="${STATE_DIR}/backups"

# Modes
INTERACTIVE=false
VERBOSE=false
DRY_RUN=false
AUTO_UPDATE=false
ACTION=""
# }}}

# -- {{{ Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
# }}}

# -- {{{ Logging functions
log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[INFO] $*" >&2
    fi
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_maintenance() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp - $message" >> "$MAINTENANCE_LOG"
}
# }}}

# -- {{{ init_state_dir
init_state_dir() {
    mkdir -p "$STATE_DIR"
    mkdir -p "$BACKUP_DIR"

    # Initialize files if they don't exist
    [[ -f "$CHECKSUMS_FILE" ]] || touch "$CHECKSUMS_FILE"
    [[ -f "$KNOWN_PROJECTS_FILE" ]] || touch "$KNOWN_PROJECTS_FILE"
    [[ -f "$MAINTENANCE_LOG" ]] || touch "$MAINTENANCE_LOG"
}
# }}}

# =============================================================================
# Change Detection System
# =============================================================================

# -- {{{ compute_checksum
compute_checksum() {
    local file="$1"
    if [[ -f "$file" ]]; then
        md5sum "$file" 2>/dev/null | cut -d' ' -f1
    else
        echo "MISSING"
    fi
}
# }}}

# -- {{{ scan_gitignore_files
scan_gitignore_files() {
    # Find all .gitignore files in project directories
    find "$DIR" -maxdepth 3 -name ".gitignore" -type f 2>/dev/null | \
        grep -v "node_modules\|\.git/\|vendor\|__pycache__" | \
        sort
}
# }}}

# -- {{{ generate_checksums
generate_checksums() {
    local output_file="$1"
    local temp_file
    temp_file=$(mktemp)

    while IFS= read -r gitignore_path; do
        local checksum size mtime
        checksum=$(compute_checksum "$gitignore_path")
        size=$(stat -c %s "$gitignore_path" 2>/dev/null || echo "0")
        mtime=$(stat -c %Y "$gitignore_path" 2>/dev/null || echo "0")

        echo "${gitignore_path}:${checksum}:${mtime}:${size}" >> "$temp_file"
    done < <(scan_gitignore_files)

    mv "$temp_file" "$output_file"
}
# }}}

# -- {{{ detect_changes
detect_changes() {
    echo -e "${BOLD}=== Change Detection ===${NC}"
    echo ""

    local temp_checksums
    temp_checksums=$(mktemp)
    generate_checksums "$temp_checksums"

    local added=0
    local modified=0
    local removed=0

    # Check for added and modified files
    while IFS=':' read -r path checksum mtime size; do
        [[ -z "$path" ]] && continue

        local old_entry
        old_entry=$(grep "^${path}:" "$CHECKSUMS_FILE" 2>/dev/null || echo "")

        if [[ -z "$old_entry" ]]; then
            echo -e "  ${GREEN}[NEW]${NC} $path"
            ((added++))
        else
            local old_checksum
            old_checksum=$(echo "$old_entry" | cut -d':' -f2)
            if [[ "$checksum" != "$old_checksum" ]]; then
                echo -e "  ${YELLOW}[MODIFIED]${NC} $path"
                ((modified++))
            fi
        fi
    done < "$temp_checksums"

    # Check for removed files
    while IFS=':' read -r path checksum mtime size; do
        [[ -z "$path" ]] && continue
        if ! grep -q "^${path}:" "$temp_checksums" 2>/dev/null; then
            echo -e "  ${RED}[REMOVED]${NC} $path"
            ((removed++))
        fi
    done < "$CHECKSUMS_FILE"

    rm -f "$temp_checksums"

    echo ""
    echo "Summary:"
    echo "  Added:    $added"
    echo "  Modified: $modified"
    echo "  Removed:  $removed"

    local total=$((added + modified + removed))
    if [[ $total -gt 0 ]]; then
        echo ""
        warn "Changes detected! Run --update to sync unified .gitignore"
        log_maintenance "Changes detected: $added added, $modified modified, $removed removed"
        return 1
    else
        success "No changes detected"
        return 0
    fi
}
# }}}

# -- {{{ update_checksums
update_checksums() {
    info "Updating checksum database..."
    generate_checksums "$CHECKSUMS_FILE"
    date '+%Y-%m-%d %H:%M:%S' > "$LAST_SCAN_FILE"
    success "Checksums updated"
    log_maintenance "Checksums database updated"
}
# }}}

# =============================================================================
# Health Monitoring
# =============================================================================

# -- {{{ check_health
check_health() {
    echo -e "${BOLD}=== Health Check ===${NC}"
    echo ""

    local issues=0

    # Check unified gitignore exists
    if [[ ! -f "$GITIGNORE_FILE" ]]; then
        error "Unified .gitignore not found: $GITIGNORE_FILE"
        ((issues++))
    else
        success "Unified .gitignore exists"

        # Check file size (warn if unusually small or large)
        local size
        size=$(stat -c %s "$GITIGNORE_FILE" 2>/dev/null || echo "0")
        if [[ $size -lt 100 ]]; then
            warn "Unified .gitignore is unusually small ($size bytes)"
            ((issues++))
        elif [[ $size -gt 50000 ]]; then
            warn "Unified .gitignore is very large ($size bytes)"
        else
            success "File size reasonable ($size bytes)"
        fi

        # Count patterns
        local pattern_count
        pattern_count=$(grep -v '^#' "$GITIGNORE_FILE" | grep -v '^$' | wc -l)
        info "Total patterns: $pattern_count"

        # Check for duplicate patterns
        local duplicates
        duplicates=$(grep -v '^#' "$GITIGNORE_FILE" | grep -v '^$' | sort | uniq -d | wc -l)
        if [[ $duplicates -gt 0 ]]; then
            warn "Found $duplicates duplicate patterns"
            ((issues++))
        else
            success "No duplicate patterns"
        fi
    fi

    # Check state files
    echo ""
    echo "State files:"
    if [[ -f "$CHECKSUMS_FILE" ]]; then
        local tracked
        tracked=$(wc -l < "$CHECKSUMS_FILE")
        success "Tracking $tracked .gitignore files"
    else
        warn "No checksums database (run --scan first)"
        ((issues++))
    fi

    if [[ -f "$LAST_SCAN_FILE" ]]; then
        local last_scan
        last_scan=$(cat "$LAST_SCAN_FILE")
        info "Last scan: $last_scan"
    fi

    # Run validation if available
    local validate_script="${SCRIPT_DIR}/validate-gitignore.sh"
    if [[ -x "$validate_script" ]]; then
        echo ""
        echo "Running validation..."
        if "$validate_script" --quick "$GITIGNORE_FILE" > /dev/null 2>&1; then
            success "Validation passed"
        else
            warn "Validation found issues (run validate-gitignore.sh for details)"
            ((issues++))
        fi
    fi

    echo ""
    if [[ $issues -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}Health check passed!${NC}"
        log_maintenance "Health check passed"
        return 0
    else
        echo -e "${YELLOW}${BOLD}Health check found $issues issue(s)${NC}"
        log_maintenance "Health check found $issues issues"
        return 1
    fi
}
# }}}

# =============================================================================
# New Project Detection
# =============================================================================

# -- {{{ detect_new_projects
detect_new_projects() {
    echo -e "${BOLD}=== New Project Detection ===${NC}"
    echo ""

    local projects_script="${SCRIPT_DIR}/list-projects.sh"
    if [[ ! -x "$projects_script" ]]; then
        error "Project listing script not found"
        return 1
    fi

    local -a current_projects
    mapfile -t current_projects < <("$projects_script" --names 2>/dev/null)

    local -a known_projects
    if [[ -f "$KNOWN_PROJECTS_FILE" ]]; then
        mapfile -t known_projects < "$KNOWN_PROJECTS_FILE"
    fi

    local new_count=0
    local -a new_projects

    for project in "${current_projects[@]}"; do
        local found=false
        for known in "${known_projects[@]}"; do
            if [[ "$project" == "$known" ]]; then
                found=true
                break
            fi
        done

        if [[ "$found" == false ]]; then
            new_projects+=("$project")
            ((new_count++)) || true
        fi
    done

    if [[ $new_count -gt 0 ]]; then
        echo "New projects detected:"
        for project in "${new_projects[@]}"; do
            echo -e "  ${GREEN}[NEW]${NC} $project"
        done
        echo ""
        info "$new_count new project(s) found"
        log_maintenance "Detected $new_count new projects: ${new_projects[*]}"
    else
        success "No new projects detected"
    fi

    # Update known projects list
    printf '%s\n' "${current_projects[@]}" > "$KNOWN_PROJECTS_FILE"

    return 0
}
# }}}

# =============================================================================
# Update and Regeneration
# =============================================================================

# -- {{{ create_backup
create_backup() {
    if [[ -f "$GITIGNORE_FILE" ]]; then
        local backup_name="gitignore-$(date '+%Y%m%d-%H%M%S').bak"
        cp "$GITIGNORE_FILE" "${BACKUP_DIR}/${backup_name}"
        log "Backup created: ${backup_name}"

        # Keep only last 10 backups
        ls -t "${BACKUP_DIR}"/gitignore-*.bak 2>/dev/null | tail -n +11 | xargs -r rm -f
    fi
}
# }}}

# -- {{{ trigger_regeneration
trigger_regeneration() {
    echo -e "${BOLD}=== Regenerating Unified .gitignore ===${NC}"
    echo ""

    local generate_script="${SCRIPT_DIR}/generate-unified-gitignore.sh"

    if [[ ! -x "$generate_script" ]]; then
        error "Generation script not found: $generate_script"
        return 1
    fi

    # Create backup first
    create_backup

    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN - Would run: $generate_script"
        return 0
    fi

    info "Running generation script..."
    if "$generate_script"; then
        success "Unified .gitignore regenerated"
        update_checksums
        log_maintenance "Unified .gitignore regenerated successfully"
        return 0
    else
        error "Generation failed"
        return 1
    fi
}
# }}}

# -- {{{ restore_backup
restore_backup() {
    echo -e "${BOLD}=== Emergency Restore ===${NC}"
    echo ""

    local -a backups
    mapfile -t backups < <(ls -t "${BACKUP_DIR}"/gitignore-*.bak 2>/dev/null)

    if [[ ${#backups[@]} -eq 0 ]]; then
        error "No backups available"
        return 1
    fi

    echo "Available backups:"
    local i=1
    for backup in "${backups[@]}"; do
        local basename
        basename=$(basename "$backup")
        local timestamp
        timestamp=$(stat -c %y "$backup" 2>/dev/null | cut -d'.' -f1)
        echo "  $i) $basename ($timestamp)"
        ((i++))
    done

    echo ""
    read -rp "Select backup to restore [1-${#backups[@]}]: " selection

    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt ${#backups[@]} ]]; then
        error "Invalid selection"
        return 1
    fi

    local selected_backup="${backups[$((selection-1))]}"

    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN - Would restore: $selected_backup"
        return 0
    fi

    # Backup current before restore
    create_backup

    cp "$selected_backup" "$GITIGNORE_FILE"
    success "Restored from: $(basename "$selected_backup")"
    log_maintenance "Emergency restore from $(basename "$selected_backup")"
}
# }}}

# =============================================================================
# Status Dashboard
# =============================================================================

# -- {{{ show_status
show_status() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║            GITIGNORE MAINTENANCE SYSTEM STATUS                     ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""

    # Unified file status
    echo -e "${BOLD}Unified .gitignore:${NC}"
    if [[ -f "$GITIGNORE_FILE" ]]; then
        local size pattern_count mtime
        size=$(stat -c %s "$GITIGNORE_FILE" 2>/dev/null || echo "0")
        pattern_count=$(grep -v '^#' "$GITIGNORE_FILE" | grep -v '^$' | wc -l)
        mtime=$(stat -c %y "$GITIGNORE_FILE" 2>/dev/null | cut -d'.' -f1)
        echo "  Location:  $GITIGNORE_FILE"
        echo "  Size:      $size bytes"
        echo "  Patterns:  $pattern_count"
        echo "  Modified:  $mtime"
    else
        echo -e "  ${RED}NOT FOUND${NC}"
    fi

    # Tracking status
    echo ""
    echo -e "${BOLD}Tracking:${NC}"
    if [[ -f "$CHECKSUMS_FILE" ]]; then
        local tracked
        tracked=$(wc -l < "$CHECKSUMS_FILE")
        echo "  Tracked files: $tracked"
    else
        echo "  Tracked files: (not initialized)"
    fi

    if [[ -f "$KNOWN_PROJECTS_FILE" ]]; then
        local projects
        projects=$(wc -l < "$KNOWN_PROJECTS_FILE")
        echo "  Known projects: $projects"
    fi

    if [[ -f "$LAST_SCAN_FILE" ]]; then
        echo "  Last scan: $(cat "$LAST_SCAN_FILE")"
    fi

    # Backup status
    echo ""
    echo -e "${BOLD}Backups:${NC}"
    local backup_count=0
    if ls "${BACKUP_DIR}"/gitignore-*.bak >/dev/null 2>&1; then
        backup_count=$(ls "${BACKUP_DIR}"/gitignore-*.bak 2>/dev/null | wc -l)
    fi
    echo "  Available: $backup_count"
    if [[ $backup_count -gt 0 ]]; then
        local latest
        latest=$(ls -t "${BACKUP_DIR}"/gitignore-*.bak 2>/dev/null | head -1)
        echo "  Latest: $(basename "$latest")"
    fi

    # Recent maintenance log
    echo ""
    echo -e "${BOLD}Recent Activity:${NC}"
    if [[ -f "$MAINTENANCE_LOG" ]]; then
        tail -5 "$MAINTENANCE_LOG" | sed 's/^/  /'
    else
        echo "  (no activity logged)"
    fi

    echo ""
}
# }}}

# =============================================================================
# Interactive Mode
# =============================================================================

# -- {{{ interactive_mode
interactive_mode() {
    while true; do
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════╗"
        echo "║            GITIGNORE MAINTENANCE SYSTEM                            ║"
        echo "╚════════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "  1) Check for changes in project .gitignore files"
        echo "  2) Detect new projects"
        echo "  3) Run health check"
        echo "  4) Regenerate unified .gitignore"
        echo "  5) View system status"
        echo "  6) Update checksum database"
        echo "  7) Emergency restore from backup"
        echo "  8) View maintenance log"
        echo "  q) Quit"
        echo ""

        read -rp "Select option [1-8, q]: " choice

        case "$choice" in
            1)
                detect_changes || true
                ;;
            2)
                detect_new_projects
                ;;
            3)
                check_health || true
                ;;
            4)
                trigger_regeneration
                ;;
            5)
                show_status
                ;;
            6)
                update_checksums
                ;;
            7)
                restore_backup
                ;;
            8)
                echo ""
                echo -e "${BOLD}Maintenance Log:${NC}"
                if [[ -f "$MAINTENANCE_LOG" ]]; then
                    tail -20 "$MAINTENANCE_LOG"
                else
                    echo "(no log entries)"
                fi
                ;;
            q|Q)
                echo "Exiting..."
                return 0
                ;;
            *)
                error "Invalid option"
                ;;
        esac

        echo ""
        echo "Press Enter to continue..."
        read -r
    done
}
# }}}

# =============================================================================
# Git Hook Support
# =============================================================================

# -- {{{ install_hooks
install_hooks() {
    echo -e "${BOLD}=== Installing Git Hooks ===${NC}"
    echo ""

    local hooks_dir="${DIR}/.git/hooks"

    if [[ ! -d "$hooks_dir" ]]; then
        error "Git hooks directory not found: $hooks_dir"
        return 1
    fi

    # Pre-commit hook
    local pre_commit="${hooks_dir}/pre-commit"
    local hook_marker="# maintain-gitignore integration"

    if [[ -f "$pre_commit" ]] && grep -q "$hook_marker" "$pre_commit"; then
        info "Pre-commit hook already installed"
    else
        if [[ "$DRY_RUN" == true ]]; then
            info "DRY RUN - Would install pre-commit hook"
        else
            cat >> "$pre_commit" <<EOF

$hook_marker
if git diff --cached --name-only | grep -q '\.gitignore$'; then
    echo "Detected .gitignore changes, running maintenance check..."
    "${SCRIPT_DIR}/maintain-gitignore.sh" --check --quiet || true
fi
EOF
            chmod +x "$pre_commit"
            success "Pre-commit hook installed"
        fi
    fi

    log_maintenance "Git hooks installation completed"
}
# }}}

# =============================================================================
# CLI Interface
# =============================================================================

# -- {{{ show_help
show_help() {
    cat <<'EOF'
Usage: maintain-gitignore.sh [OPTIONS] [ACTION]

Unified gitignore maintenance and workflow integration.

Actions:
    --check              Check for changes in project .gitignore files
    --health             Run health check on unified .gitignore
    --scan               Update checksum database
    --new-projects       Detect new projects
    --regenerate         Regenerate unified .gitignore
    --status             Show system status dashboard
    --restore            Emergency restore from backup
    --install-hooks      Install git workflow hooks

Options:
    -I, --interactive    Interactive mode with menu
    -v, --verbose        Verbose output
    -n, --dry-run        Show what would be done
    --auto-update        Auto-regenerate if changes detected
    --quiet              Minimal output (for hooks)
    -h, --help           Show this help

Examples:
    # Interactive mode
    maintain-gitignore.sh -I

    # Check for changes
    maintain-gitignore.sh --check

    # Auto-update on changes
    maintain-gitignore.sh --check --auto-update

    # Full health check
    maintain-gitignore.sh --health

    # View status
    maintain-gitignore.sh --status

Workflow Integration:
    This script integrates with git hooks to automatically detect
    when project .gitignore files change and prompt for updates.

    Run --install-hooks to enable automatic integration.

EOF
}
# }}}

# -- {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                ACTION="check"
                shift
                ;;
            --health)
                ACTION="health"
                shift
                ;;
            --scan)
                ACTION="scan"
                shift
                ;;
            --new-projects)
                ACTION="new_projects"
                shift
                ;;
            --regenerate)
                ACTION="regenerate"
                shift
                ;;
            --status)
                ACTION="status"
                shift
                ;;
            --restore)
                ACTION="restore"
                shift
                ;;
            --install-hooks)
                ACTION="install_hooks"
                shift
                ;;
            -I|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --auto-update)
                AUTO_UPDATE=true
                shift
                ;;
            --quiet)
                VERBOSE=false
                exec > /dev/null 2>&1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                shift
                ;;
        esac
    done
}
# }}}

# -- {{{ main
main() {
    parse_args "$@"
    init_state_dir

    if [[ "$INTERACTIVE" == true ]]; then
        interactive_mode
        exit 0
    fi

    case "$ACTION" in
        check)
            if ! detect_changes && [[ "$AUTO_UPDATE" == true ]]; then
                echo ""
                trigger_regeneration
            fi
            ;;
        health)
            check_health
            ;;
        scan)
            update_checksums
            ;;
        new_projects)
            detect_new_projects
            ;;
        regenerate)
            trigger_regeneration
            ;;
        status)
            show_status
            ;;
        restore)
            restore_backup
            ;;
        install_hooks)
            install_hooks
            ;;
        "")
            # Default: show status
            show_status
            ;;
        *)
            error "Unknown action: $ACTION"
            exit 1
            ;;
    esac
}
# }}}

main "$@"
