#!/bin/bash
# develop.sh
# Interactive mode for editing patched upstream source. Where build.sh
# applies-and-immediately-reverts within a single stage, develop.sh
# applies patches and leaves them applied so a developer can edit the
# patched code for hours in their editor. When done, `freeze` captures
# the new diff back into the project's patches/ files; `revert` returns
# the tree to pristine.
#
# This is the only place where upstream trees in libs/ are allowed to
# carry our modifications across a single invocation of a tool.
#
# Usage:
#   ./develop.sh gsplus              # apply gsplus.patch, stay applied
#   ./develop.sh freeze              # diff current state → patches/
#   ./develop.sh revert              # un-apply, restore pristine
#   ./develop.sh status              # show what's currently applied
#   ./develop.sh --help

# {{{ configuration
DIR="/mnt/mtwo/programming/ai-stuff/apple-IIds"
MODE=""
# }}}

# {{{ logging
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
# }}}

# {{{ show_usage
show_usage() {
    echo "Usage: develop.sh COMMAND"
    echo ""
    echo "Commands:"
    echo "  gsplus        Apply all gsplus.patch files and leave them applied"
    echo "  freeze        Capture current diff back into patches/*.gsplus.patch"
    echo "  revert        Revert any applied patches; restore pristine upstream"
    echo "  status        Show what's currently applied"
    echo ""
    echo "Note: no 'gsos' command. GS/OS modifications are byte-level"
    echo "patches against a binary disk image, with no text-editor workflow."
    echo "See docs/005-patch-conventions.md."
}
# }}}

# {{{ parse_arguments
parse_arguments() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    case "$1" in
        --help|-h) show_usage; exit 0 ;;
        gsplus|freeze|revert|status) MODE="$1" ;;
        *) log_error "unknown command: $1"; show_usage; exit 1 ;;
    esac
}
# }}}

# {{{ sentinel_path
sentinel_path() {
    echo "${DIR}/tmp/.develop-applied"
}
# }}}

# {{{ cmd_status
cmd_status() {
    local sentinel
    sentinel="$(sentinel_path)"
    if [ ! -s "$sentinel" ]; then
        log_info "no patches currently applied; upstream is pristine"
        return 0
    fi
    log_info "currently applied:"
    cat "$sentinel"
}
# }}}

# {{{ cmd_gsplus
cmd_gsplus() {
    local tree="${DIR}/libs/gsplus"
    local sentinel
    sentinel="$(sentinel_path)"
    if [ -s "$sentinel" ]; then
        log_error "patches already applied; run 'develop.sh revert' first"
        cat "$sentinel"
        exit 1
    fi
    if [ ! -d "$tree" ]; then
        log_error "GSplus not present; run scripts/build-deps.sh first"
        exit 1
    fi
    shopt -s nullglob
    local patches=( "${DIR}"/patches/*.gsplus.patch )
    shopt -u nullglob
    if [ "${#patches[@]}" -eq 0 ]; then
        log_info "no gsplus patches yet; tree stays pristine"
        log_info "edit ${tree} freely and 'develop.sh freeze' to capture"
        echo "gsplus:${tree}" > "$sentinel"
        return 0
    fi
    for p in "${patches[@]}"; do
        log_info "applying $(basename "$p")"
        patch -d "$tree" -p1 --silent < "$p"
    done
    echo "gsplus:${tree}" > "$sentinel"
    log_info "patches applied; tree at ${tree} is editable"
    log_info "when done: 'develop.sh freeze' or 'develop.sh revert'"
}
# }}}

# {{{ cmd_revert
cmd_revert() {
    local sentinel
    sentinel="$(sentinel_path)"
    if [ ! -s "$sentinel" ]; then
        log_info "nothing applied; nothing to revert"
        return 0
    fi
    while IFS=: read -r layer tree; do
        case "$layer" in
            gsplus)
                shopt -s nullglob
                local patches=( "${DIR}"/patches/*.gsplus.patch )
                shopt -u nullglob
                local i
                for ((i=${#patches[@]}-1; i>=0; i--)); do
                    log_info "reverting $(basename "${patches[$i]}")"
                    patch -d "$tree" -p1 -R --silent < "${patches[$i]}" || \
                        log_warn "  unclean revert; inspect $tree"
                done
                ;;
            *) log_warn "unknown layer in sentinel: $layer" ;;
        esac
    done < "$sentinel"
    : > "$sentinel"
    log_info "upstream restored to pristine"
}
# }}}

# {{{ cmd_freeze
# Captures the current state of patched upstream back into patches/.
# Strategy: stash our current patches/ aside, revert to pristine,
# diff pristine vs current state via a second checkout we maintain
# in tmp/, then write the new diff back.
#
# Simpler interim approach (until the strategy above is needed): the
# user invoked 'develop.sh gsplus' which left the tree dirty. We diff
# the dirty tree against the pristine state recorded by git in
# libs/gsplus/.git. Then we write a single combined patch — the user
# decides afterward how to split it into numbered patch files.
cmd_freeze() {
    local sentinel
    sentinel="$(sentinel_path)"
    if [ ! -s "$sentinel" ]; then
        log_error "nothing to freeze; no patches currently applied"
        exit 1
    fi
    while IFS=: read -r layer tree; do
        case "$layer" in
            gsplus)
                local out="${DIR}/tmp/freeze-${layer}-$(date +%Y%m%d-%H%M%S).patch"
                log_info "freezing $layer state → ${out}"
                git -C "$tree" diff > "$out"
                log_info "review ${out}, then move it into patches/ with the"
                log_info "naming convention NNN-feature-name.${layer}.patch"
                log_info "(see docs/005-patch-conventions.md)"
                ;;
            *) log_warn "freeze: unknown layer $layer" ;;
        esac
    done < "$sentinel"
}
# }}}

# {{{ main
main() {
    parse_arguments "$@"
    mkdir -p "${DIR}/tmp"

    case "$MODE" in
        status) cmd_status ;;
        gsplus) cmd_gsplus ;;
        revert) cmd_revert ;;
        freeze) cmd_freeze ;;
    esac
}
# }}}

main "$@"
