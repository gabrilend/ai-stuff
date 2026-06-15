#!/usr/bin/env bash
# clean.sh
#
# Cleans build artifacts from the SymbelineRumble project. Removes compiled
# packages from the UT2004 installation and clears temporary files. Safe to
# run at any time - will not remove source code.

# -- {{{ set_dir_and_load_config
DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_DIR="$DIR"

# Load common library and configuration
source "$DIR/scripts/lib-common.sh"
load_config "$DIR/config.sh"
# }}}

# -- {{{ remove_compiled_package
remove_compiled_package() {
    local package_file="$UT2004_DIR/System/$PACKAGE_NAME.u"
    local ucl_file="$UT2004_DIR/System/$PACKAGE_NAME.ucl"
    local int_file="$UT2004_DIR/System/$PACKAGE_NAME.int"

    local removed=0

    # Remove .u file (compiled package)
    if [ -f "$package_file" ]; then
        echo "Removing: $package_file"
        rm -f "$package_file"
        removed=1
    fi

    # Remove .ucl file (compiler cache)
    if [ -f "$ucl_file" ]; then
        echo "Removing: $ucl_file"
        rm -f "$ucl_file"
        removed=1
    fi

    # Remove .int file (internationalization)
    if [ -f "$int_file" ]; then
        echo "Removing: $int_file"
        rm -f "$int_file"
        removed=1
    fi

    if [ $removed -eq 0 ]; then
        echo "No compiled package files to remove"
    else
        echo "Compiled package files removed"
    fi
}
# }}}

# -- {{{ remove_temporary_files
remove_temporary_files() {
    local tmp_dir="$PROJECT_DIR/tmp"

    if [ -d "$tmp_dir" ] && [ "$(ls -A "$tmp_dir" 2>/dev/null)" ]; then
        echo "Removing temporary files from: $tmp_dir"
        rm -rf "$tmp_dir"/*
        echo "Temporary files removed"
    else
        echo "No temporary files to remove"
    fi
}
# }}}

# -- {{{ remove_log_files
remove_log_files() {
    # Remove UT2004 logs in System directory (if they exist)
    if [ -d "$UT2004_DIR/System" ]; then
        local log_count=$(find "$UT2004_DIR/System" -name "*.log" 2>/dev/null | wc -l)

        if [ $log_count -gt 0 ]; then
            echo "Removing UT2004 log files..."
            find "$UT2004_DIR/System" -name "*.log" -delete
            echo "Removed $log_count log file(s)"
        else
            echo "No log files to remove"
        fi
    fi
}
# }}}

# -- {{{ main
main() {
    print_header "SymbelineRumble Clean"

    echo "Project Directory: $PROJECT_DIR"
    echo "UT2004 Directory:  $UT2004_DIR"
    echo "Package Name:      $PACKAGE_NAME"

    # Step 1: Remove compiled package files
    print_header "Removing Compiled Packages"
    remove_compiled_package

    # Step 2: Remove temporary files
    print_header "Removing Temporary Files"
    remove_temporary_files

    # Step 3: Remove log files
    print_header "Removing Log Files"
    remove_log_files

    print_header "Clean Complete"
    echo ""
    echo "All build artifacts have been removed"
    echo "Source code in src/ is preserved"

    return 0
}
# }}}

main "$@"
