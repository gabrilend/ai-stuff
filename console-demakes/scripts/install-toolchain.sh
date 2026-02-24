#!/bin/bash
# =============================================================================
# GBA/GBC Development Toolchain Installation Script
# Downloads and installs ARM GCC toolchain and RGBDS for Game Boy development
#
# This script downloads:
#   - gcc-arm-none-eabi: ARM cross-compiler for GBA development
#   - RGBDS: Assembler and tools for Game Boy / Game Boy Color
#
# Usage: ./install-toolchain.sh [--arm-only] [--rgbds-only] [--clean]
# =============================================================================

set -euo pipefail

# {{{ Configuration
DIR="${1:-/mnt/mtwo/programming/ai-stuff/console-demakes}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${PROJECT_DIR}/tools"
DOWNLOADS_DIR="${PROJECT_DIR}/downloads"

# Versions
ARM_GCC_VERSION="10.3-2021.10"
ARM_GCC_TARBALL="gcc-arm-none-eabi-${ARM_GCC_VERSION}-x86_64-linux.tar.bz2"
ARM_GCC_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/${ARM_GCC_VERSION}/${ARM_GCC_TARBALL}"
ARM_GCC_DIR="gcc-arm-none-eabi-${ARM_GCC_VERSION}"

RGBDS_VERSION="0.8.0"
RGBDS_TARBALL="rgbds-${RGBDS_VERSION}.tar.gz"
RGBDS_URL="https://github.com/gbdev/rgbds/releases/download/v${RGBDS_VERSION}/${RGBDS_TARBALL}"

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

# {{{ download_file
download_file() {
    local url="$1"
    local filename="$2"
    local filepath="${DOWNLOADS_DIR}/${filename}"

    if [[ -f "$filepath" ]]; then
        log_info "Using cached: $filename"
        return 0
    fi

    log_info "Downloading: $filename"

    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$filepath" "$url" --progress-bar
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$filepath" "$url"
    else
        log_error "Neither curl nor wget found"
        exit 1
    fi
}
# }}}

# {{{ install_arm_gcc
install_arm_gcc() {
    local install_dir="${TOOLS_DIR}/gba-toolchain"

    # Check if already installed
    if [[ -x "${install_dir}/${ARM_GCC_DIR}/bin/arm-none-eabi-gcc" ]]; then
        local version
        version=$("${install_dir}/${ARM_GCC_DIR}/bin/arm-none-eabi-gcc" --version | head -1)
        log_info "ARM GCC already installed: $version"
        return 0
    fi

    log_info "Installing ARM GCC toolchain..."

    mkdir -p "$DOWNLOADS_DIR" "$install_dir"

    # Download
    download_file "$ARM_GCC_URL" "$ARM_GCC_TARBALL"

    # Extract
    log_info "Extracting ARM GCC (this may take a moment)..."
    tar -xf "${DOWNLOADS_DIR}/${ARM_GCC_TARBALL}" -C "$install_dir"

    # Verify
    if [[ -x "${install_dir}/${ARM_GCC_DIR}/bin/arm-none-eabi-gcc" ]]; then
        local version
        version=$("${install_dir}/${ARM_GCC_DIR}/bin/arm-none-eabi-gcc" --version | head -1)
        log_info "ARM GCC installed successfully: $version"
    else
        log_error "ARM GCC installation failed"
        exit 1
    fi
}
# }}}

# {{{ install_rgbds
install_rgbds() {
    local install_dir="${TOOLS_DIR}/rgbds"

    # Check if already installed
    if [[ -x "${install_dir}/rgbasm" ]]; then
        local version
        version=$("${install_dir}/rgbasm" --version 2>&1 | head -1)
        log_info "RGBDS already installed: $version"
        return 0
    fi

    log_info "Installing RGBDS (Game Boy assembler)..."

    mkdir -p "$DOWNLOADS_DIR" "$install_dir"

    # Download
    download_file "$RGBDS_URL" "$RGBDS_TARBALL"

    # Extract
    log_info "Extracting RGBDS..."
    tar -xf "${DOWNLOADS_DIR}/${RGBDS_TARBALL}" -C "$install_dir" --strip-components=1

    # Build if source distribution
    if [[ -f "${install_dir}/Makefile" ]]; then
        log_info "Building RGBDS from source..."
        cd "$install_dir"

        # Check for dependencies
        if ! command -v bison >/dev/null 2>&1; then
            log_warn "bison not found - needed for RGBDS build"
            log_info "Install with: sudo apt-get install bison flex libpng-dev"
        fi

        make -j"$(nproc)" || {
            log_warn "RGBDS build failed - trying pre-built binaries"
            # Try Linux pre-built binaries instead
            local prebuilt_url="https://github.com/gbdev/rgbds/releases/download/v${RGBDS_VERSION}/rgbds-${RGBDS_VERSION}-linux-x86_64.tar.xz"
            local prebuilt_file="rgbds-${RGBDS_VERSION}-linux-x86_64.tar.xz"
            download_file "$prebuilt_url" "$prebuilt_file"
            rm -rf "$install_dir"/*
            tar -xf "${DOWNLOADS_DIR}/${prebuilt_file}" -C "$install_dir"
        }

        cd "$PROJECT_DIR"
    fi

    # Verify
    if [[ -x "${install_dir}/rgbasm" ]]; then
        local version
        version=$("${install_dir}/rgbasm" --version 2>&1 | head -1 || echo "installed")
        log_info "RGBDS installed successfully: $version"
    else
        log_error "RGBDS installation failed"
        exit 1
    fi
}
# }}}

# {{{ create_env_script
create_env_script() {
    local env_script="${PROJECT_DIR}/tools/setup-env.sh"

    log_info "Creating environment setup script..."

    cat > "$env_script" << 'EOF'
#!/bin/bash
# {{{ setup-env
# GBA/GBC Development Environment Setup
# Source this file to configure your environment for development

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ARM GCC Toolchain
export ARM_TOOLCHAIN_PATH="${SCRIPT_DIR}/gba-toolchain/gcc-arm-none-eabi-10.3-2021.10"
export PATH="${ARM_TOOLCHAIN_PATH}/bin:${PATH}"

# RGBDS (Game Boy assembler)
export RGBDS_PATH="${SCRIPT_DIR}/rgbds"
export PATH="${RGBDS_PATH}:${PATH}"

# Convenience aliases
alias arm-gcc='arm-none-eabi-gcc'
alias arm-objcopy='arm-none-eabi-objcopy'
alias arm-objdump='arm-none-eabi-objdump'

echo "GBA/GBC development environment configured!"
echo ""
echo "Tools available:"
command -v arm-none-eabi-gcc >/dev/null && echo "  - arm-none-eabi-gcc: $(arm-none-eabi-gcc --version | head -1)"
command -v rgbasm >/dev/null && echo "  - rgbasm: $(rgbasm --version 2>&1 | head -1)"
echo ""
# }}}
EOF

    chmod +x "$env_script"
    log_info "Environment script created: $env_script"
}
# }}}

# {{{ clean_downloads
clean_downloads() {
    log_info "Cleaning downloaded archives..."
    rm -rf "$DOWNLOADS_DIR"
    log_info "Downloads cleaned"
}
# }}}

# {{{ show_usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --arm-only     Install only ARM GCC toolchain (for GBA)"
    echo "  --rgbds-only   Install only RGBDS (for Game Boy/GBC)"
    echo "  --clean        Remove downloaded archives after installation"
    echo "  --help         Show this help message"
    echo ""
    echo "Without options, installs both toolchains."
}
# }}}

# {{{ main
main() {
    local install_arm=true
    local install_rgbds=true
    local clean_after=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --arm-only)
                install_rgbds=false
                shift
                ;;
            --rgbds-only)
                install_arm=false
                shift
                ;;
            --clean)
                clean_after=true
                shift
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

    echo ""
    echo -e "${CYAN}=== GBA/GBC Development Toolchain Installer ===${NC}"
    echo ""

    mkdir -p "$TOOLS_DIR" "$DOWNLOADS_DIR"

    if $install_arm; then
        install_arm_gcc
    fi

    if $install_rgbds; then
        install_rgbds
    fi

    create_env_script

    if $clean_after; then
        clean_downloads
    fi

    echo ""
    log_info "Installation complete!"
    echo ""
    echo "To configure your environment:"
    echo "  source ${PROJECT_DIR}/tools/setup-env.sh"
    echo ""
    echo "To build a GBA ROM:"
    echo "  ./build-gba.sh"
    echo ""
}

main "$@"
# }}}
