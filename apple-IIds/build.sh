#!/bin/bash
# build.sh
# End-to-end build for Apple IIds. Orchestrates the apply / build /
# revert discipline defined in docs/005-patch-conventions.md: each
# stage applies only the patches relevant to its layer, runs that
# layer's tool, then reverts. Upstream trees in libs/ stay pristine
# between stages so a developer who opens them sees upstream code,
# never our modifications.
#
# A sentinel file at tmp/.applied lists the patches currently applied.
# A crashed build leaves the sentinel behind; the next invocation
# detects the inconsistent state and reverts before starting fresh.
#
# Usage:
#   ./build.sh                       # full build
#   ./build.sh /custom/dir           # override project DIR
#   ./build.sh --stage gsplus        # run only the GSplus stage
#   ./build.sh --stage disk-image    # run only the disk-image stage
#   ./build.sh --clean               # wipe tmp/build/ and rebuild
#   ./build.sh --help

# {{{ configuration
DIR="/mnt/mtwo/programming/ai-stuff/apple-IIds"

STAGE_REQUESTED="all"
CLEAN_BUILD=0
# }}}

# {{{ logging
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_stage() { echo ""; echo "=== $* ==="; }
# }}}

# {{{ show_usage
show_usage() {
    echo "Usage: build.sh [OPTIONS] [DIRECTORY]"
    echo ""
    echo "Options:"
    echo "  --stage NAME   Run only a single stage. NAME is one of:"
    echo "                   gsplus, gsos-addons, disk-image,"
    echo "                   broker, luajit, bundle, all (default)"
    echo "  --clean        Wipe tmp/build/ before building"
    echo "  --help         Show this help"
    echo ""
    echo "Arguments:"
    echo "  DIRECTORY      Project directory (default: $DIR)"
}
# }}}

# {{{ parse_arguments
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --stage)
                STAGE_REQUESTED="$2"
                shift 2
                ;;
            --clean)
                CLEAN_BUILD=1
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                DIR="$1"
                shift
                ;;
        esac
    done
}
# }}}

# {{{ sentinel_path
# The sentinel records which patches are currently applied to which
# upstream tree. Format: one line per applied patch, "layer:patch-file".
sentinel_path() {
    echo "${DIR}/tmp/.applied"
}
# }}}

# {{{ check_sentinel
# If a previous run crashed mid-stage, the sentinel will be non-empty.
# Reverting first is safer than trying to apply on top — apply would
# fail with "patch already applied" hunks and leave the tree in an
# even worse state.
check_sentinel() {
    local sentinel
    sentinel="$(sentinel_path)"
    if [ -s "$sentinel" ]; then
        log_warn "previous build appears interrupted; reverting stale patches"
        revert_all_from_sentinel
    fi
}
# }}}

# {{{ apply_patches
# Applies every patches/*.${suffix} to ${target_tree} and records each
# in the sentinel. Suffix examples: gsplus.patch, gsos.bin.patch.
apply_patches() {
    local suffix="$1"
    local target_tree="$2"
    local sentinel
    sentinel="$(sentinel_path)"

    shopt -s nullglob
    local patches=( "${DIR}"/patches/*."${suffix}" )
    shopt -u nullglob

    if [ "${#patches[@]}" -eq 0 ]; then
        log_info "no ${suffix} patches to apply"
        return 0
    fi

    for p in "${patches[@]}"; do
        log_info "  applying $(basename "$p")"
        patch -d "$target_tree" -p1 --silent < "$p"
        echo "${suffix}:${p}" >> "$sentinel"
    done
}
# }}}

# {{{ revert_patches
# Reverts patches in REVERSE order from the sentinel and removes their
# entries. Reverse order matters when patches touch overlapping lines.
revert_patches() {
    local suffix="$1"
    local target_tree="$2"
    local sentinel
    sentinel="$(sentinel_path)"

    if [ ! -f "$sentinel" ]; then
        return 0
    fi

    local entries
    entries="$(grep "^${suffix}:" "$sentinel" || true)"
    if [ -z "$entries" ]; then
        return 0
    fi

    local reversed
    reversed="$(echo "$entries" | tac)"

    echo "$reversed" | while IFS= read -r line; do
        local p="${line#${suffix}:}"
        log_info "  reverting $(basename "$p")"
        patch -d "$target_tree" -p1 -R --silent < "$p"
    done

    # Drop these entries from the sentinel.
    grep -v "^${suffix}:" "$sentinel" > "${sentinel}.tmp" || true
    mv "${sentinel}.tmp" "$sentinel"
}
# }}}

# {{{ revert_all_from_sentinel
# Walks the sentinel in reverse and reverts everything. Used by
# check_sentinel to recover from an interrupted build.
revert_all_from_sentinel() {
    local sentinel
    sentinel="$(sentinel_path)"

    tac "$sentinel" | while IFS= read -r line; do
        local suffix="${line%%:*}"
        local p="${line#*:}"
        local target_tree
        case "$suffix" in
            gsplus.patch) target_tree="${DIR}/libs/gsplus" ;;
            gsos.bin.patch) continue ;;  # bin patches operate on tmp/build copies, no revert needed
            tbox.patch) continue ;;
            *) log_warn "unknown sentinel entry: $line"; continue ;;
        esac
        log_info "  reverting $(basename "$p") from ${target_tree}"
        patch -d "$target_tree" -p1 -R --silent < "$p" || \
            log_warn "could not cleanly revert $p; inspect ${target_tree}"
    done
    : > "$sentinel"
}
# }}}

# {{{ stage_gsplus
# Applies GSplus patches, cross-compiles for aarch64, reverts. The
# resulting binary lands under tmp/build/gsplus.
stage_gsplus() {
    log_stage "GSplus stage"
    local tree="${DIR}/libs/gsplus"
    if [ ! -d "$tree" ]; then
        log_error "GSplus not present; run scripts/build-deps.sh first"
        exit 1
    fi

    apply_patches "gsplus.patch" "$tree"

    log_info "cross-compiling GSplus for aarch64"
    local cc="${DIR}/libs/toolchain/aarch64/bin/aarch64-none-linux-gnu-gcc"
    if [ ! -x "$cc" ]; then
        log_error "aarch64 toolchain missing; run scripts/build-deps.sh"
        revert_patches "gsplus.patch" "$tree"
        exit 1
    fi

    # GSplus uses a Makefile. The actual cross-compile invocation
    # depends on which patches are landed. For now, the GSplus stage
    # is a placeholder that just confirms the toolchain reaches the
    # tree. Real cross-compilation lands when issue 103's framebuffer
    # patch is the first .gsplus.patch.
    log_info "  (placeholder: GSplus cross-compile arrives with issue 103)"

    revert_patches "gsplus.patch" "$tree"
}
# }}}

# {{{ stage_gsos_addons
# Assembles every src/gsos-addons/*/*.s with the 65C816 cross-assembler
# into one binary per addon, staged at tmp/build/addons/.
stage_gsos_addons() {
    log_stage "GS/OS addon stage"
    mkdir -p "${DIR}/tmp/build/addons"
    shopt -s nullglob
    local addon_dirs=( "${DIR}"/src/gsos-addons/*/ )
    shopt -u nullglob
    if [ "${#addon_dirs[@]}" -eq 0 ]; then
        log_info "no addons under src/gsos-addons/; skipping"
        return 0
    fi
    log_info "  (placeholder: 65C816 cross-assembly arrives with issue 106)"
}
# }}}

# {{{ stage_disk_image
# Copies the user-supplied .2mg to tmp/build/, applies binary patches
# to the copy, injects assembled addons. Original .2mg is never
# touched.
stage_disk_image() {
    log_stage "GS/OS disk-image stage"
    local user_image="${DIR}/assets/disks/gsos-boot.2mg"
    if [ ! -f "$user_image" ]; then
        log_warn "user-supplied GS/OS .2mg not found at ${user_image}"
        log_warn "see assets/disks/SOURCE.md (issue 103) for where to obtain one"
        log_warn "skipping disk-image stage"
        return 0
    fi
    local out="${DIR}/tmp/build/gsos-boot.2mg"
    cp "$user_image" "$out"
    log_info "copied user image → tmp/build/gsos-boot.2mg"

    shopt -s nullglob
    local bin_patches=( "${DIR}"/patches/*.gsos.bin.patch )
    shopt -u nullglob
    if [ "${#bin_patches[@]}" -gt 0 ]; then
        log_info "  (placeholder: gsos.bin.patch application arrives with issue 106)"
    fi
}
# }}}

# {{{ stage_broker
# The broker is Lua source we author directly. No compilation step —
# we just stage it under tmp/build/broker/.
stage_broker() {
    log_stage "broker stage"
    local out="${DIR}/tmp/build/broker"
    mkdir -p "$out"
    if [ -d "${DIR}/src/broker" ]; then
        cp -r "${DIR}/src/broker/." "$out/"
        log_info "broker sources staged at ${out}"
    else
        log_info "no broker sources yet; skipping"
    fi
}
# }}}

# {{{ stage_luajit
# Cross-compiles LuaJIT for aarch64. LuaJIT's Makefile supports cross
# builds via HOST_CC / CROSS / TARGET_SYS. Output is staged under
# tmp/build/luajit/.
stage_luajit() {
    log_stage "LuaJIT stage"
    local tree="${DIR}/libs/luajit"
    if [ ! -d "$tree" ]; then
        log_error "LuaJIT not present; run scripts/build-deps.sh first"
        exit 1
    fi
    log_info "  (placeholder: LuaJIT aarch64 cross-build arrives next)"
    # Real invocation will look like:
    #   make -C "$tree" clean
    #   make -C "$tree" HOST_CC="gcc -m64" \
    #       CROSS="${DIR}/libs/toolchain/aarch64/bin/aarch64-none-linux-gnu-" \
    #       TARGET_SYS=Linux TARGET_CFLAGS="-mtune=cortex-a55"
}
# }}}

# {{{ stage_bundle
# Walks tmp/build/ and emits the manifest. The manifest IS the
# deliverable's table of contents.
stage_bundle() {
    log_stage "bundle stage"
    local emitter="${DIR}/src/build-tools/01-manifest-emitter.lua"
    if [ ! -f "$emitter" ]; then
        log_error "manifest emitter missing at ${emitter}"
        exit 1
    fi
    if ! command -v luajit >/dev/null 2>&1 && ! command -v lua >/dev/null 2>&1; then
        log_warn "no host lua available; skipping manifest emission"
        return 0
    fi
    local lua_cmd
    lua_cmd="$(command -v luajit || command -v lua)"
    "$lua_cmd" "$emitter" "${DIR}/tmp/build"
}
# }}}

# {{{ run_stages
run_stages() {
    case "$STAGE_REQUESTED" in
        all)
            stage_gsplus
            stage_gsos_addons
            stage_disk_image
            stage_broker
            stage_luajit
            stage_bundle
            ;;
        gsplus) stage_gsplus ;;
        gsos-addons) stage_gsos_addons ;;
        disk-image) stage_disk_image ;;
        broker) stage_broker ;;
        luajit) stage_luajit ;;
        bundle) stage_bundle ;;
        *)
            log_error "unknown stage: $STAGE_REQUESTED"
            show_usage
            exit 1
            ;;
    esac
}
# }}}

# {{{ main
main() {
    parse_arguments "$@"

    echo "========================================"
    echo "Apple IIds build"
    echo "========================================"
    echo "  project dir: $DIR"
    echo "  stage: $STAGE_REQUESTED"
    echo "  clean: $CLEAN_BUILD"

    if [ "$CLEAN_BUILD" -eq 1 ]; then
        log_info "wiping tmp/build/"
        rm -rf "${DIR}/tmp/build"
    fi
    mkdir -p "${DIR}/tmp/build"
    : > "$(sentinel_path)"

    check_sentinel
    run_stages

    echo ""
    echo "========================================"
    echo "build complete → ${DIR}/tmp/build/"
    echo "========================================"
}
# }}}

main "$@"
