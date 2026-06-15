#!/bin/bash
# scripts/build-deps.sh
# Fetches every external dependency the Apple IIds build needs and
# installs them as project-local artifacts under libs/. Re-runnable;
# skips dependencies already present. --clean wipes them and starts
# fresh. Everything it installs is .gitignored — the script IS the
# history of how to acquire these dependencies.
#
# Targets:
#   libs/gsplus/             — the IIgs emulator we patch (BSD)
#   libs/luajit/             — the broker's runtime (MIT)
#   libs/toolchain/aarch64/  — ARM's pre-built aarch64-none-linux-gnu
#                              cross-compiler (GPL + runtime exception;
#                              produced binaries are unencumbered)
#
# Usage:
#   ./scripts/build-deps.sh                # default DIR, idempotent fetch
#   ./scripts/build-deps.sh /custom/dir    # override project DIR
#   ./scripts/build-deps.sh --clean        # wipe libs/ deps and refetch
#   ./scripts/build-deps.sh --help

# {{{ configuration
DIR="/mnt/mtwo/programming/ai-stuff/apple-IIds"

GSPLUS_REPO="https://github.com/digarok/gsplus.git"
GSPLUS_REF="master"

LUAJIT_REPO="https://github.com/LuaJIT/LuaJIT.git"
LUAJIT_REF="v2.1"

# ARM's official aarch64-none-linux-gnu prebuilt. Targets a generic
# aarch64 Linux userland; matches the RG DS's Linux mode well enough
# for our purposes. Version pinned so re-running this script anywhere
# produces an identical compiler.
TOOLCHAIN_VERSION="13.2.rel1"
TOOLCHAIN_NAME="arm-gnu-toolchain-${TOOLCHAIN_VERSION}-x86_64-aarch64-none-linux-gnu"
TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu/${TOOLCHAIN_VERSION}/binrel/${TOOLCHAIN_NAME}.tar.xz"

CLEAN_BUILD=0
# }}}

# {{{ logging
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
# }}}

# {{{ show_usage
show_usage() {
    echo "Usage: build-deps.sh [OPTIONS] [DIRECTORY]"
    echo ""
    echo "Options:"
    echo "  --clean    Remove existing dependencies and refetch"
    echo "  --help     Show this help"
    echo ""
    echo "Arguments:"
    echo "  DIRECTORY  Project directory (default: $DIR)"
}
# }}}

# {{{ parse_arguments
parse_arguments() {
    for arg in "$@"; do
        case "$arg" in
            --clean) CLEAN_BUILD=1 ;;
            --help|-h) show_usage; exit 0 ;;
            *) DIR="$arg" ;;
        esac
    done
}
# }}}

# {{{ check_requirements
check_requirements() {
    log_info "Checking host requirements..."
    local missing=0
    for cmd in git curl tar xz make; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "missing host tool: $cmd"
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        log_error "install missing tools and re-run"
        exit 1
    fi
    log_info "host requirements satisfied"
}
# }}}

# {{{ setup_directories
setup_directories() {
    mkdir -p "${DIR}/libs"
    mkdir -p "${DIR}/libs/toolchain"
    mkdir -p "${DIR}/tmp/build"
}
# }}}

# {{{ fetch_gsplus
# GSplus is the upstream IIgs emulator. We pin to a known ref so
# re-running this script anywhere lands on the same source tree.
fetch_gsplus() {
    local target="${DIR}/libs/gsplus"
    if [ "$CLEAN_BUILD" -eq 1 ] && [ -d "$target" ]; then
        log_info "clean: removing ${target}"
        rm -rf "$target"
    fi
    if [ -d "${target}/.git" ]; then
        log_info "gsplus already present at ${target}; skipping"
        return 0
    fi
    log_info "cloning gsplus → ${target}"
    git clone "$GSPLUS_REPO" "$target"
    git -C "$target" checkout "$GSPLUS_REF"

    write_source_md "$target" "GSplus" "$GSPLUS_REPO" "$GSPLUS_REF" \
        "BSD-style (see LICENSE in the cloned tree)"
}
# }}}

# {{{ fetch_luajit
# LuaJIT is the broker's runtime. The broker is single-threaded today
# but will be multithreaded once soramech primitives are ready; LuaJIT's
# 64-bit aarch64 support is mature.
fetch_luajit() {
    local target="${DIR}/libs/luajit"
    if [ "$CLEAN_BUILD" -eq 1 ] && [ -d "$target" ]; then
        log_info "clean: removing ${target}"
        rm -rf "$target"
    fi
    if [ -d "${target}/.git" ]; then
        log_info "luajit already present at ${target}; skipping"
        return 0
    fi
    log_info "cloning luajit → ${target}"
    git clone "$LUAJIT_REPO" "$target"
    git -C "$target" checkout "$LUAJIT_REF"

    write_source_md "$target" "LuaJIT" "$LUAJIT_REPO" "$LUAJIT_REF" \
        "MIT (see COPYRIGHT in the cloned tree)"
}
# }}}

# {{{ fetch_toolchain
# Downloads ARM's official pre-built aarch64 cross-toolchain. Choosing
# the prebuilt over crosstool-ng-from-scratch is a deliberate trade:
# fastest path to a working compiler, at the cost of a dependency on
# ARM's release URL. If the URL ever rots, this function is what gets
# updated (or replaced with a source build).
fetch_toolchain() {
    local target_root="${DIR}/libs/toolchain/aarch64"
    local archive="${DIR}/tmp/${TOOLCHAIN_NAME}.tar.xz"
    if [ "$CLEAN_BUILD" -eq 1 ] && [ -d "$target_root" ]; then
        log_info "clean: removing ${target_root}"
        rm -rf "$target_root"
    fi
    if [ -d "${target_root}/bin" ]; then
        log_info "aarch64 toolchain already present at ${target_root}; skipping"
        return 0
    fi
    if [ ! -f "$archive" ]; then
        log_info "downloading aarch64 cross-toolchain (~150MB compressed)..."
        curl -L --fail --output "$archive" "$TOOLCHAIN_URL"
    else
        log_info "toolchain archive already cached at ${archive}"
    fi
    log_info "extracting toolchain → ${target_root}"
    mkdir -p "$target_root"
    tar -xJf "$archive" -C "$target_root" --strip-components=1

    write_source_md "$target_root" "aarch64 cross-toolchain" \
        "$TOOLCHAIN_URL" "$TOOLCHAIN_VERSION" \
        "GPL with runtime exception (output binaries are unencumbered)"
}
# }}}

# {{{ write_source_md
# Records the provenance of each fetched dependency. The file lives
# inside the (gitignored) dependency directory so it shows up next to
# the source when a developer looks for it.
write_source_md() {
    local dir="$1"
    local name="$2"
    local origin="$3"
    local ref="$4"
    local license="$5"
    cat > "${dir}/SOURCE.md" <<EOF
# ${name}

- origin: ${origin}
- pinned ref/version: ${ref}
- fetched by: scripts/build-deps.sh
- license: ${license}

This directory is gitignored. Re-fetch with:

    scripts/build-deps.sh --clean
EOF
}
# }}}

# {{{ verify_build
verify_build() {
    log_info "verifying installations..."
    local gcc="${DIR}/libs/toolchain/aarch64/bin/aarch64-none-linux-gnu-gcc"
    if [ ! -x "$gcc" ]; then
        log_error "aarch64 gcc not found at ${gcc}"
        exit 1
    fi
    "$gcc" --version | head -n1
    if [ ! -d "${DIR}/libs/gsplus" ]; then
        log_error "gsplus not present at ${DIR}/libs/gsplus"
        exit 1
    fi
    if [ ! -d "${DIR}/libs/luajit" ]; then
        log_error "luajit not present at ${DIR}/libs/luajit"
        exit 1
    fi
    log_info "all dependencies verified"
}
# }}}

# {{{ main
main() {
    parse_arguments "$@"

    echo "========================================"
    echo "Apple IIds dependency builder"
    echo "========================================"
    echo "  project dir: $DIR"
    echo "  clean rebuild: $CLEAN_BUILD"
    echo ""

    check_requirements
    setup_directories
    fetch_gsplus
    fetch_luajit
    fetch_toolchain
    verify_build

    echo ""
    echo "========================================"
    echo "dependencies ready"
    echo "  next: ./build.sh"
    echo "========================================"
}
# }}}

main "$@"
