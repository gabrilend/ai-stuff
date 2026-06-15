#!/usr/bin/env bash
# compile.sh
#
# Compiles the SymbelineRumble mod by syncing source files to the UT2004
# installation and running the UCC compiler. Uses configuration from config.sh
# and can be run from any directory.

# -- {{{ set_dir_and_load_config
DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_DIR="$DIR"

# Load common library and configuration
source "$DIR/scripts/lib-common.sh"
load_config "$DIR/config.sh"
# }}}

# -- {{{ verify_ut2004_installation
verify_ut2004_installation() {
    if [ ! -d "$UT2004_DIR/System" ]; then
        echo "ERROR: UT2004 installation not found at: $UT2004_DIR" >&2
        echo "Please run scripts/install-ut2004.sh first" >&2
        exit 1
    fi

    # Check for UCC compiler (try multiple possible names)
    local ucc_found=0
    if [ -x "$UT2004_DIR/System/UCC" ]; then
        ucc_found=1
    elif [ -x "$UT2004_DIR/System/ucc-bin-linux-amd64" ]; then
        ucc_found=1
    elif [ -x "$UT2004_DIR/System/ucc-bin" ]; then
        ucc_found=1
    elif [ -x "$UT2004_DIR/System/ucc" ]; then
        ucc_found=1
    fi

    if [ $ucc_found -eq 0 ]; then
        echo "ERROR: UCC compiler not found in $UT2004_DIR/System" >&2
        echo "Please run scripts/install-ut2004.sh first" >&2
        exit 1
    fi
}
# }}}

# -- {{{ create_package_directory
create_package_directory() {
    local pkg_dir="$UT2004_DIR/$PACKAGE_NAME/Classes"

    if [ ! -d "$pkg_dir" ]; then
        echo "Creating package directory: $pkg_dir"
        mkdir -p "$pkg_dir"
    fi
}
# }}}

# -- {{{ sync_source_files
sync_source_files() {
    local src_dir="$PROJECT_DIR/src"
    local dest_dir="$UT2004_DIR/$PACKAGE_NAME/Classes"

    if [ ! -d "$src_dir" ]; then
        echo "ERROR: Source directory not found: $src_dir" >&2
        echo "Please create source files first (see Issue 102)" >&2
        exit 1
    fi

    # Check if there are any .uc files
    if ! ls "$src_dir"/*.uc 1> /dev/null 2>&1; then
        echo "ERROR: No UnrealScript files (.uc) found in: $src_dir" >&2
        echo "Please create source files first (see Issue 102)" >&2
        exit 1
    fi

    echo "Syncing source files..."
    echo "  From: $src_dir"
    echo "  To:   $dest_dir"

    rsync -av --delete "$src_dir/" "$dest_dir/"

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to sync source files" >&2
        exit 1
    fi

    echo "Source files synced successfully"
}
# }}}

# -- {{{ run_compiler
run_compiler() {
    echo "Running UCC compiler..."
    cd "$UT2004_DIR/System"

    # Determine which UCC executable to use (check OldUnreal names first)
    local ucc_cmd=""
    if [ -x "./UCC" ]; then
        ucc_cmd="./UCC"
    elif [ -x "./ucc-bin-linux-amd64" ]; then
        ucc_cmd="./ucc-bin-linux-amd64"
    elif [ -x "./ucc-bin" ]; then
        ucc_cmd="./ucc-bin"
    elif [ -x "./ucc" ]; then
        ucc_cmd="./ucc"
    else
        echo "ERROR: UCC compiler not found" >&2
        exit 1
    fi

    echo "Using compiler: $ucc_cmd"
    echo ""

    # Run the compiler
    $ucc_cmd make

    return $?
}
# }}}

# -- {{{ check_build_results
check_build_results() {
    local compile_result=$1
    local package_file="$UT2004_DIR/System/$PACKAGE_NAME.u"

    echo ""
    if [ $compile_result -eq 0 ]; then
        echo "==========================================="
        echo "Build Successful"
        echo "==========================================="

        if [ -f "$package_file" ]; then
            echo ""
            echo "Package created:"
            ls -lh "$package_file"
        else
            echo ""
            echo "WARNING: Expected package file not found: $package_file"
            echo "Compilation succeeded but no .u file was created"
        fi

        return 0
    else
        echo "==========================================="
        echo "Build Failed"
        echo "==========================================="
        echo ""
        echo "Check the compiler output above for errors"
        return 1
    fi
}
# }}}

# -- {{{ main
main() {
    print_header "SymbelineRumble Compiler"

    echo "Project Directory: $PROJECT_DIR"
    echo "UT2004 Directory:  $UT2004_DIR"
    echo "Package Name:      $PACKAGE_NAME"
    echo "Version:           $VERSION"

    # Step 1: Verify UT2004 installation
    verify_ut2004_installation

    # Step 2: Create package directory
    create_package_directory

    # Step 3: Sync source files
    print_header "Syncing Source Files"
    sync_source_files

    # Step 4: Run compiler
    print_header "Compiling Package"
    run_compiler
    compile_result=$?

    # Step 5: Check results
    check_build_results $compile_result

    return $?
}
# }}}

main "$@"
