#!/bin/bash
# =============================================================================
# City of Heroes Source Code Installation Script
# Downloads and extracts the CoH source code for development
#
# The CoH source is available from the Ouroboros Development community.
# This script handles downloading or extracting the source from various methods.
#
# Usage: ./install-coh-source.sh [--from-zip <path>] [--from-git]
# =============================================================================

set -euo pipefail

# {{{ Configuration
DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/city-of-chat}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${PROJECT_DIR}/src"
COH_SOURCE_DIR="${SRC_DIR}/coh-source"
DOWNLOADS_DIR="${PROJECT_DIR}/downloads"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
# }}}

# {{{ check_existing
check_existing() {
    if [[ -d "$COH_SOURCE_DIR" ]]; then
        local file_count
        file_count=$(find "$COH_SOURCE_DIR" -type f | wc -l)
        if [[ $file_count -gt 100 ]]; then
            log_info "CoH source already installed ($file_count files)"
            return 0
        fi
    fi
    return 1
}
# }}}

# {{{ install_from_zip
install_from_zip() {
    local zip_path="$1"

    if [[ ! -f "$zip_path" ]]; then
        log_error "ZIP file not found: $zip_path"
        exit 1
    fi

    log_info "Extracting CoH source from: $zip_path"

    mkdir -p "$SRC_DIR"

    # Extract to temp directory first to handle nested structure
    local temp_dir="${PROJECT_DIR}/tmp/coh-extract-$$"
    mkdir -p "$temp_dir"

    unzip -q "$zip_path" -d "$temp_dir"

    # Find the actual source directory (may be nested)
    local source_root
    if [[ -d "$temp_dir/Source" ]]; then
        source_root="$temp_dir/Source"
    elif [[ -d "$temp_dir/Source-develop" ]]; then
        source_root="$temp_dir/Source-develop"
    else
        # Find directory with most files
        source_root=$(find "$temp_dir" -maxdepth 2 -type d -name "*Source*" | head -1)
        if [[ -z "$source_root" ]]; then
            source_root="$temp_dir"
        fi
    fi

    log_info "Moving source to: $COH_SOURCE_DIR"
    rm -rf "$COH_SOURCE_DIR"
    mv "$source_root" "$COH_SOURCE_DIR"

    # Cleanup
    rm -rf "$temp_dir"

    log_info "CoH source installed successfully"
}
# }}}

# {{{ install_from_git
install_from_git() {
    log_info "Cloning CoH source from git.ourodev.com..."

    echo -e "${CYAN}"
    echo "============================================================"
    echo "  CoH Source Repository requires authentication"
    echo "============================================================"
    echo ""
    echo "  Repository: https://git.ourodev.com/CoX/Source.git"
    echo ""
    echo "  You will need credentials from the Ouroboros Development"
    echo "  community. Visit https://ourodev.com to register."
    echo ""
    echo "============================================================"
    echo -e "${NC}"

    mkdir -p "$SRC_DIR"

    if command -v git >/dev/null 2>&1; then
        git clone https://git.ourodev.com/CoX/Source.git "$COH_SOURCE_DIR"
        log_info "CoH source cloned successfully"
    else
        log_error "git is required for this installation method"
        exit 1
    fi
}
# }}}

# {{{ show_usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --from-zip <path>    Extract from a local ZIP file"
    echo "  --from-git           Clone from git.ourodev.com (requires auth)"
    echo "  --check              Check if already installed"
    echo "  --help               Show this help message"
    echo ""
    echo "If no option is specified, looks for Source-develop.zip in downloads/"
}
# }}}

# {{{ main
main() {
    local mode="auto"
    local zip_path=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from-zip)
                mode="zip"
                zip_path="$2"
                shift 2
                ;;
            --from-git)
                mode="git"
                shift
                ;;
            --check)
                if check_existing; then
                    exit 0
                else
                    log_info "CoH source not installed"
                    exit 1
                fi
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done

    # Check if already installed
    if check_existing; then
        log_info "Nothing to do"
        exit 0
    fi

    case "$mode" in
        zip)
            install_from_zip "$zip_path"
            ;;
        git)
            install_from_git
            ;;
        auto)
            # Try to find existing ZIP
            local found_zip=""
            for candidate in \
                "${PROJECT_DIR}/Source-develop.zip" \
                "${DOWNLOADS_DIR}/Source-develop.zip" \
                "${PROJECT_DIR}/downloads/Source.zip" \
                "${PROJECT_DIR}/Source.zip"; do
                if [[ -f "$candidate" ]]; then
                    found_zip="$candidate"
                    break
                fi
            done

            if [[ -n "$found_zip" ]]; then
                install_from_zip "$found_zip"
            else
                echo ""
                log_warn "No CoH source ZIP found."
                echo ""
                echo "Options:"
                echo "  1. Place Source-develop.zip in ${PROJECT_DIR}/"
                echo "  2. Run: $0 --from-zip /path/to/Source.zip"
                echo "  3. Run: $0 --from-git (requires ourodev.com account)"
                echo ""
                exit 1
            fi
            ;;
    esac

    # Verify installation
    if check_existing; then
        local file_count
        file_count=$(find "$COH_SOURCE_DIR" -type f | wc -l)
        echo ""
        log_info "Installation complete!"
        echo "  Location: $COH_SOURCE_DIR"
        echo "  Files: $file_count"
        echo ""
        echo "Next steps:"
        echo "  1. Run ./scripts/build_dependencies.sh to build libraries"
        echo "  2. Source ./scripts/setup_env.sh to configure environment"
    fi
}

main "$@"
# }}}
