#!/bin/bash
# =============================================================================
# Effil Installation Script
# Installs the Effil Lua multithreading library from source
#
# Effil provides native threading support for Lua with safe data exchange.
# It requires a C++14 compiler and CMake to build.
#
# Usage: ./install-effil.sh [--lua51|--lua52|--lua53|--luajit] [--local]
#
# Options:
#   --lua51, --lua52, --lua53, --luajit  Target Lua version (default: lua53)
#   --local                               Install to project-local directory
#   --system                              Install system-wide via luarocks
# =============================================================================

set -euo pipefail

# {{{ Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/libs}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBS_DIR="$(dirname "$SCRIPT_DIR")"

EFFIL_VERSION="1.2.0"
EFFIL_REPO="https://github.com/effil/effil.git"
EFFIL_TAG="v${EFFIL_VERSION}"

LUA_VERSION="lua53"
INSTALL_MODE="local"

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

# {{{ check_dependencies
check_dependencies() {
    log_info "Checking dependencies..."

    local missing=()

    if ! command -v cmake &>/dev/null; then
        missing+=("cmake")
    fi

    if ! command -v git &>/dev/null; then
        missing+=("git")
    fi

    if ! command -v g++ &>/dev/null && ! command -v clang++ &>/dev/null; then
        missing+=("g++ or clang++")
    fi

    # Check for Lua
    case "$LUA_VERSION" in
        lua51)
            if ! command -v lua5.1 &>/dev/null && ! command -v lua &>/dev/null; then
                missing+=("lua5.1")
            fi
            ;;
        lua52)
            if ! command -v lua5.2 &>/dev/null && ! command -v lua &>/dev/null; then
                missing+=("lua5.2")
            fi
            ;;
        lua53)
            if ! command -v lua5.3 &>/dev/null && ! command -v lua &>/dev/null; then
                missing+=("lua5.3")
            fi
            ;;
        luajit)
            if ! command -v luajit &>/dev/null; then
                missing+=("luajit")
            fi
            ;;
    esac

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install on Debian/Ubuntu:"
        echo "  sudo apt-get install cmake git g++ liblua5.3-dev"
        echo ""
        echo "Install on Arch:"
        echo "  sudo pacman -S cmake git gcc lua"
        echo ""
        exit 1
    fi

    log_info "All dependencies found"
}
# }}}

# {{{ install_from_source
install_from_source() {
    local target_dir="$1"
    local build_dir="${target_dir}/build"

    log_info "Installing Effil from source to: $target_dir"

    # Clone if not exists
    if [[ ! -d "$target_dir/.git" ]]; then
        log_info "Cloning Effil repository..."
        rm -rf "$target_dir"
        git clone --depth 1 --branch "$EFFIL_TAG" "$EFFIL_REPO" "$target_dir"
    else
        log_info "Effil source already exists, updating..."
        cd "$target_dir"
        git fetch --tags
        git checkout "$EFFIL_TAG"
    fi

    # Build
    log_info "Building Effil (this may take a minute)..."

    mkdir -p "$build_dir"
    cd "$build_dir"

    # Determine Lua paths based on version
    local lua_cmd lua_include lua_lib
    case "$LUA_VERSION" in
        lua51)
            lua_cmd="lua5.1"
            lua_include="/usr/include/lua5.1"
            lua_lib="/usr/lib/x86_64-linux-gnu/liblua5.1.so"
            ;;
        lua52)
            lua_cmd="lua5.2"
            lua_include="/usr/include/lua5.2"
            lua_lib="/usr/lib/x86_64-linux-gnu/liblua5.2.so"
            ;;
        lua53)
            lua_cmd="lua5.3"
            lua_include="/usr/include/lua5.3"
            lua_lib="/usr/lib/x86_64-linux-gnu/liblua5.3.so"
            ;;
        luajit)
            lua_cmd="luajit"
            lua_include="/usr/include/luajit-2.1"
            lua_lib="/usr/lib/x86_64-linux-gnu/libluajit-5.1.so"
            ;;
    esac

    # Fallback paths
    [[ ! -d "$lua_include" ]] && lua_include="/usr/include/lua"
    [[ ! -f "$lua_lib" ]] && lua_lib=""

    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DLUA_INCLUDE_DIR="$lua_include" \
        ${lua_lib:+-DLUA_LIBRARIES="$lua_lib"}

    make -j"$(nproc)"

    log_info "Effil built successfully"

    # Copy the .so file to a standard location
    if [[ -f "effil.so" ]]; then
        cp effil.so "${target_dir}/effil.so"
        log_info "Library copied to: ${target_dir}/effil.so"
    fi
}
# }}}

# {{{ install_via_luarocks
install_via_luarocks() {
    log_info "Installing Effil via luarocks..."

    if ! command -v luarocks &>/dev/null; then
        log_error "luarocks not found"
        echo "Install with: sudo apt-get install luarocks"
        exit 1
    fi

    # Install git fetcher dependency
    luarocks install luarocks-fetch-gitrec --local 2>/dev/null || true

    # Install effil
    luarocks install effil --local

    log_info "Effil installed via luarocks"
}
# }}}

# {{{ show_usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --lua51          Build for Lua 5.1"
    echo "  --lua52          Build for Lua 5.2"
    echo "  --lua53          Build for Lua 5.3 (default)"
    echo "  --luajit         Build for LuaJIT"
    echo "  --local          Install to libs/lua/effil (default)"
    echo "  --system         Install system-wide via luarocks"
    echo "  --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --lua53 --local    # Build for Lua 5.3, install locally"
    echo "  $0 --luajit --system  # Install LuaJIT version via luarocks"
}
# }}}

# {{{ main
main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lua51) LUA_VERSION="lua51"; shift ;;
            --lua52) LUA_VERSION="lua52"; shift ;;
            --lua53) LUA_VERSION="lua53"; shift ;;
            --luajit) LUA_VERSION="luajit"; shift ;;
            --local) INSTALL_MODE="local"; shift ;;
            --system) INSTALL_MODE="system"; shift ;;
            --help|-h) show_usage; exit 0 ;;
            *) shift ;;
        esac
    done

    echo ""
    echo -e "${CYAN}=== Effil Installation Script ===${NC}"
    echo "  Lua version: $LUA_VERSION"
    echo "  Install mode: $INSTALL_MODE"
    echo ""

    check_dependencies

    case "$INSTALL_MODE" in
        local)
            local target
            if [[ "$LUA_VERSION" == "luajit" ]]; then
                target="${LIBS_DIR}/lua/effil-jit"
            else
                target="${LIBS_DIR}/lua/effil"
            fi
            install_from_source "$target"
            ;;
        system)
            install_via_luarocks
            ;;
    esac

    echo ""
    log_info "Installation complete!"
    echo ""
    echo "To use Effil in your Lua code:"
    echo "  local effil = require('effil')"
    echo ""
}

main "$@"
# }}}
