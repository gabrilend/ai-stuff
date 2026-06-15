#!/usr/bin/env bash
# full-rebuild.sh
#
# Performs a full rebuild of the SymbelineRumble mod by cleaning all build
# artifacts and then compiling from scratch. This ensures a fresh build with
# no stale files.

# -- {{{ set_dir_and_load_config
DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_DIR="$DIR"

# Load common library and configuration
source "$DIR/scripts/lib-common.sh"
load_config "$DIR/config.sh"
# }}}

# -- {{{ main
main() {
    print_header "Full Rebuild - SymbelineRumble"

    echo "Project Directory: $PROJECT_DIR"
    echo "UT2004 Directory:  $UT2004_DIR"
    echo "Package Name:      $PACKAGE_NAME"

    # Step 1: Clean
    print_header "Step 1: Clean"
    "$DIR/scripts/clean.sh"

    if [ $? -ne 0 ]; then
        echo "" >&2
        echo "ERROR: Clean step failed" >&2
        exit 1
    fi

    # Step 2: Compile
    print_header "Step 2: Compile"
    "$DIR/scripts/compile.sh"

    if [ $? -ne 0 ]; then
        echo "" >&2
        echo "ERROR: Compile step failed" >&2
        exit 1
    fi

    print_header "Full Rebuild Complete"
    echo ""
    echo "Build successful!"

    return 0
}
# }}}

main "$@"
