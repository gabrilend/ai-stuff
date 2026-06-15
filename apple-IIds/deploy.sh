#!/bin/bash
# deploy.sh
# Copies tmp/build/ to the Anbernic RG DS handheld over ssh. The actual
# ssh target lives in tmp/device.conf (not committed; it's per-user and
# changes when the device's network address changes). A --dry-run mode
# prints the rsync plan without copying so we can verify the bundle
# before sending it.
#
# Until the RG DS is in hand, --dry-run is the only useful mode.
#
# Usage:
#   ./deploy.sh                  # copy tmp/build/ to the device
#   ./deploy.sh --dry-run        # print what would be copied
#   ./deploy.sh /custom/dir      # override project DIR
#   ./deploy.sh --help

# {{{ configuration
DIR="/mnt/mtwo/programming/ai-stuff/apple-IIds"
DRY_RUN=0
# }}}

# {{{ logging
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
# }}}

# {{{ show_usage
show_usage() {
    echo "Usage: deploy.sh [OPTIONS] [DIRECTORY]"
    echo ""
    echo "Options:"
    echo "  --dry-run     Print the rsync plan without copying"
    echo "  --help        Show this help"
    echo ""
    echo "Arguments:"
    echo "  DIRECTORY     Project directory (default: $DIR)"
    echo ""
    echo "Configuration:"
    echo "  Create tmp/device.conf with two shell variables:"
    echo "    DEVICE_HOST=user@10.0.0.42"
    echo "    DEVICE_PATH=/home/user/apple-IIds"
}
# }}}

# {{{ parse_arguments
parse_arguments() {
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=1 ;;
            --help|-h) show_usage; exit 0 ;;
            *) DIR="$arg" ;;
        esac
    done
}
# }}}

# {{{ load_device_conf
load_device_conf() {
    local conf="${DIR}/tmp/device.conf"
    if [ ! -f "$conf" ]; then
        log_warn "tmp/device.conf not found"
        log_warn "create it with:"
        log_warn "  DEVICE_HOST=user@10.0.0.42"
        log_warn "  DEVICE_PATH=/home/user/apple-IIds"
        if [ "$DRY_RUN" -eq 1 ]; then
            DEVICE_HOST="(unset)"
            DEVICE_PATH="(unset)"
            return 0
        fi
        exit 1
    fi
    # shellcheck disable=SC1090
    . "$conf"
    if [ -z "$DEVICE_HOST" ] || [ -z "$DEVICE_PATH" ]; then
        log_error "tmp/device.conf must set DEVICE_HOST and DEVICE_PATH"
        exit 1
    fi
}
# }}}

# {{{ check_bundle
check_bundle() {
    if [ ! -d "${DIR}/tmp/build" ]; then
        log_error "no build at ${DIR}/tmp/build; run ./build.sh first"
        exit 1
    fi
    if [ ! -f "${DIR}/tmp/build/manifest.txt" ]; then
        log_warn "no manifest.txt in tmp/build/; build may be incomplete"
    fi
}
# }}}

# {{{ do_rsync
do_rsync() {
    local src="${DIR}/tmp/build/"
    local dst="${DEVICE_HOST}:${DEVICE_PATH}/"
    log_info "rsync ${src} → ${dst}"
    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "(dry run — listing what would be sent)"
        rsync -avzn --delete "$src" "$dst" 2>&1 || true
        return 0
    fi
    rsync -avz --delete "$src" "$dst"
}
# }}}

# {{{ main
main() {
    parse_arguments "$@"

    echo "========================================"
    echo "Apple IIds deploy"
    echo "========================================"
    echo "  project dir: $DIR"
    echo "  dry run: $DRY_RUN"
    echo ""

    check_bundle
    load_device_conf

    echo "  device host: $DEVICE_HOST"
    echo "  device path: $DEVICE_PATH"
    echo ""

    do_rsync

    echo ""
    echo "========================================"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "dry run complete; nothing copied"
    else
        echo "deploy complete"
    fi
    echo "========================================"
}
# }}}

main "$@"
