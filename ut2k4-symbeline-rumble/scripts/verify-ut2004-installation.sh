#!/usr/bin/env bash
# verify-ut2004-installation.sh
#
# Verifies that UT2004 OldUnreal installation is complete and functional
# for development purposes. Checks for required directories, executables,
# and tests the UCC compiler.

# -- {{{ set_dir_and_load_config
DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_DIR="$DIR"

# Load common library and configuration
source "$DIR/scripts/lib-common.sh"
load_config "$DIR/config.sh"

# Alias print_section to print_header for this script
print_section() { print_header "$@"; }
# }}}

# -- {{{ check_directory
check_directory() {
    local dir="$1"
    local name="$2"

    if [ -d "$dir" ]; then
        echo "✓ $name exists: $dir"
        return 0
    else
        echo "✗ $name missing: $dir"
        return 1
    fi
}
# }}}

# -- {{{ check_file
check_file() {
    local file="$1"
    local name="$2"

    if [ -f "$file" ]; then
        echo "✓ $name exists: $file"
        return 0
    else
        echo "✗ $name missing: $file"
        return 1
    fi
}
# }}}

# -- {{{ check_executable
check_executable() {
    local file="$1"
    local name="$2"

    if [ -f "$file" ]; then
        if [ -x "$file" ]; then
            echo "✓ $name is executable: $file"
            return 0
        else
            echo "⚠ $name exists but not executable: $file"
            echo "  Run: chmod +x $file"
            return 1
        fi
    else
        echo "✗ $name missing: $file"
        return 1
    fi
}
# }}}

# -- {{{ test_ucc
test_ucc() {
    local ucc_path="$1"

    if [ ! -x "$ucc_path" ]; then
        echo "✗ UCC not executable, cannot test"
        return 1
    fi

    echo "Testing UCC help command..."
    cd "$(dirname "$ucc_path")"

    local output
    output=$(./$(basename "$ucc_path") help 2>&1)

    if echo "$output" | grep -q "UnrealOS execution environment"; then
        echo "✓ UCC help command works"
    else
        echo "✗ UCC help command failed"
        return 1
    fi

    echo ""
    echo "Testing UCC make command..."
    output=$(./$(basename "$ucc_path") make help 2>&1)

    if echo "$output" | grep -qi "broken"; then
        echo "✗ UCC make is BROKEN (stock Linux version detected)"
        echo "  You need OldUnreal Patch 3374 for a working compiler"
        return 1
    else
        echo "✓ UCC make command works (OldUnreal patch detected)"
    fi

    return 0
}
# }}}

# -- {{{ main
main() {
    print_section "UT2004 Installation Verification"

    echo "Project Directory: $PROJECT_DIR"
    echo "UT2004 Directory:  $UT2004_DIR"
    echo ""

    local errors=0

    # Check main installation directory
    print_section "Checking Installation Directory"
    check_directory "$UT2004_DIR" "UT2004 installation" || ((errors++))

    # Check required game directories
    print_section "Checking Game Asset Directories"
    check_directory "$UT2004_DIR/System" "System directory" || ((errors++))
    check_directory "$UT2004_DIR/Maps" "Maps directory" || ((errors++))
    check_directory "$UT2004_DIR/Textures" "Textures directory" || ((errors++))
    check_directory "$UT2004_DIR/StaticMeshes" "StaticMeshes directory" || ((errors++))
    check_directory "$UT2004_DIR/Sounds" "Sounds directory" || ((errors++))

    # Check executables
    print_section "Checking Executables"
    check_executable "$UT2004_DIR/System/ut2004-bin-linux-amd64" "UT2004 game binary" || ((errors++))
    check_executable "$UT2004_DIR/System/ucc-bin-linux-amd64" "UCC compiler" || ((errors++))

    # Check for critical .u files
    print_section "Checking Core Packages"
    check_file "$UT2004_DIR/System/Core.u" "Core.u" || ((errors++))
    check_file "$UT2004_DIR/System/Engine.u" "Engine.u" || ((errors++))
    check_file "$UT2004_DIR/System/XGame.u" "XGame.u" || ((errors++))

    # Test UCC compiler
    print_section "Testing UCC Compiler"
    test_ucc "$UT2004_DIR/System/ucc-bin-linux-amd64" || ((errors++))

    # Summary
    print_section "Verification Summary"
    if [ $errors -eq 0 ]; then
        echo "✓ All checks passed!"
        echo ""
        echo "Your UT2004 installation is ready for development."
        echo "You can proceed with Issue 102: Create mod package structure"
        return 0
    else
        echo "✗ $errors check(s) failed"
        echo ""
        echo "Please fix the issues above before proceeding."
        echo "See docs/007-oldunreal-installation-guide.md for installation instructions"
        return 1
    fi
}
# }}}

main "$@"
