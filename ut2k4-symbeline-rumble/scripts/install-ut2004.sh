#!/usr/bin/env bash
# install-ut2004.sh
#
# Fully automated installation script for UT2004 with OldUnreal Patch 3374.
# First checks for a clean backup copy in assets/clean-game-install and uses
# that if available. Otherwise downloads via OldUnreal installer. After a fresh
# download, saves a backup copy to assets/clean-game-install for future use.
#
# Usage:
#   ./scripts/install-ut2004.sh          # Use backup if available, else download
#   ./scripts/install-ut2004.sh --force  # Force fresh download, update backup
#
# This script requires no user interaction - just run it and it handles everything.

set -e  # Exit on error

# Parse command line arguments
FORCE_DOWNLOAD=0
for arg in "$@"; do
    case "$arg" in
        --force)
            FORCE_DOWNLOAD=1
            ;;
    esac
done

# -- {{{ set_dir_and_load_config
DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_DIR="$DIR"

# Load common library and configuration
source "$DIR/scripts/lib-common.sh"
load_config "$DIR/config.sh"
# }}}

# -- {{{ check_dependencies
check_dependencies() {
    local deps=("wget" "bash")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing[*]}"
        print_error "Please install them and try again"
        exit 1
    fi
}
# }}}

# -- {{{ remove_existing_installation
remove_existing_installation() {
    if [ -d "$UT2004_DIR" ]; then
        print_warning "Existing UT2004 installation found at: $UT2004_DIR"
        print_info "Removing old installation..."

        rm -rf "$UT2004_DIR"
        print_info "Old installation removed"
    fi
}
# }}}

# -- {{{ check_clean_backup
check_clean_backup() {
    local backup_dir="$PROJECT_DIR/assets/clean-game-install"

    if [ $FORCE_DOWNLOAD -eq 1 ]; then
        print_info "Force download requested, will skip backup check"
        return 1
    fi

    if [ -d "$backup_dir" ]; then
        print_info "Found clean backup at: $backup_dir"

        # Check if backup looks valid
        if [ -d "$backup_dir/System" ] && [ -f "$backup_dir/System/ucc-bin-linux-amd64" ]; then
            print_info "Backup appears valid, will use it instead of downloading"
            return 0
        else
            print_warning "Backup exists but appears incomplete, will download fresh copy"
            return 1
        fi
    else
        print_info "No clean backup found at: $backup_dir"
        print_info "Will download and create backup for future use"
        return 1
    fi
}
# }}}

# -- {{{ install_from_backup
install_from_backup() {
    local backup_dir="$PROJECT_DIR/assets/clean-game-install"

    print_info "Installing from backup using rsync..."
    print_info "  Source: $backup_dir"
    print_info "  Destination: $UT2004_DIR"

    mkdir -p "$UT2004_DIR"

    # Use rsync to efficiently copy only changed files
    # -a: archive mode (preserves permissions, timestamps, etc.)
    # -v: verbose
    # --delete: remove files in dest that don't exist in source
    rsync -av --delete "$backup_dir/" "$UT2004_DIR/"

    if [ $? -eq 0 ]; then
        print_info "Installation from backup completed successfully"
        return 0
    else
        print_error "Failed to install from backup"
        return 1
    fi
}
# }}}

# -- {{{ create_clean_backup
create_clean_backup() {
    local backup_dir="$PROJECT_DIR/assets/clean-game-install"

    print_info "Creating clean backup for future installations..."
    print_info "  Source: $UT2004_DIR"
    print_info "  Destination: $backup_dir"

    mkdir -p "$(dirname "$backup_dir")"

    # Remove old backup if it exists
    if [ -d "$backup_dir" ]; then
        print_info "Removing old backup..."
        rm -rf "$backup_dir"
    fi

    # Use rsync to create the backup
    rsync -av "$UT2004_DIR/" "$backup_dir/"

    if [ $? -eq 0 ]; then
        print_info "Clean backup created successfully"
        print_info "Future installations will use this backup (much faster)"
        return 0
    else
        print_warning "Failed to create backup (non-fatal)"
        return 1
    fi
}
# }}}

# -- {{{ download_oldunreal_installer
download_oldunreal_installer() {
    local installer_url="https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-ut2004.sh"
    local installer_script="$DIR/.oldunreal-installer.sh"

    print_info "Downloading OldUnreal UT2004 installer from GitHub"
    print_info "URL: $installer_url"

    if wget -q -O "$installer_script" "$installer_url"; then
        print_info "Download successful: $(basename "$installer_script")"
        chmod +x "$installer_script"
        echo "$installer_script"
    else
        print_error "Failed to download OldUnreal installer"
        print_error "Please check your internet connection and try again"
        exit 1
    fi
}
# }}}

# -- {{{ run_oldunreal_installer
run_oldunreal_installer() {
    local installer_script="$1"

    print_info "Running OldUnreal installer"
    print_info "Installation target: $UT2004_DIR"
    print_info ""
    print_info "This may take several minutes as it downloads game files..."
    print_info ""

    # Create parent directory if needed
    mkdir -p "$(dirname "$UT2004_DIR")"

    # Run the OldUnreal installer with automated flags
    # --destination: Where to install
    # --ui-mode none: Run in non-interactive mode
    # --application-entry skip: Don't prompt for application entry
    # --desktop-shortcut skip: Don't prompt for desktop shortcut
    # --keep-installer-files: Keep downloaded files for future reinstalls
    if bash "$installer_script" \
        --destination "$UT2004_DIR" \
        --ui-mode none \
        --application-entry skip \
        --desktop-shortcut skip \
        --keep-installer-files; then
        print_info "OldUnreal installer completed successfully"
    else
        print_error "OldUnreal installer failed"
        print_error "Check the output above for details"
        return 1
    fi

    # Clean up the installer script
    rm -f "$installer_script"
}
# }}}

# -- {{{ setup_permissions
setup_permissions() {
    print_info "Setting up file permissions"

    # Make game and compiler binaries executable
    chmod +x "$UT2004_DIR/System/ut2004-bin-linux-amd64" 2>/dev/null || true
    chmod +x "$UT2004_DIR/System/ut2004-bin" 2>/dev/null || true
    chmod +x "$UT2004_DIR/System/ucc-bin-linux-amd64" 2>/dev/null || true
    chmod +x "$UT2004_DIR/System/ucc-bin" 2>/dev/null || true

    print_info "Permissions configured"
}
# }}}

# -- {{{ create_mod_directories
create_mod_directories() {
    print_info "Creating mod package directories"

    # Create source directory in UT2004 installation for our mod
    local mod_source_dir="$UT2004_DIR/$PACKAGE_NAME"
    mkdir -p "$mod_source_dir/Classes"

    print_info "Created: $mod_source_dir/Classes"
}
# }}}

# -- {{{ copy_mod_files
copy_mod_files() {
    print_info "Checking for existing mod source files"

    local src_dir="$PROJECT_DIR/src"

    if [ ! -d "$src_dir" ] || [ -z "$(ls -A "$src_dir" 2>/dev/null)" ]; then
        print_info "No mod source files found in $src_dir (this is normal for fresh installs)"
        return 0
    fi

    print_info "Copying mod source files from $src_dir to UT2004 installation"

    local mod_dest_dir="$UT2004_DIR/$PACKAGE_NAME/Classes"

    # Copy .uc files
    find "$src_dir" -name "*.uc" -exec cp -v {} "$mod_dest_dir/" \;

    print_info "Mod files copied successfully"
}
# }}}

# -- {{{ copy_compiled_packages
copy_compiled_packages() {
    print_info "Checking for compiled packages"

    local build_output="$PROJECT_DIR/tmp/build-output"

    if [ ! -d "$build_output" ]; then
        print_info "No build output directory found (this is normal for fresh installs)"
        return 0
    fi

    # Copy compiled .u, .ucl, and .int files
    for ext in u ucl int; do
        if ls "$build_output"/*."$ext" 1> /dev/null 2>&1; then
            print_info "Copying .$ext files to System directory"
            cp -v "$build_output"/*."$ext" "$UT2004_DIR/System/" 2>/dev/null || true
        fi
    done

    print_info "Compiled packages copied (if any existed)"
}
# }}}

# -- {{{ run_verification
run_verification() {
    print_info "Running installation verification"

    local verify_script="$DIR/scripts/verify-ut2004-installation.sh"

    if [ ! -f "$verify_script" ]; then
        print_warning "Verification script not found: $verify_script"
        print_warning "Skipping verification"
        return 0
    fi

    chmod +x "$verify_script"

    if bash "$verify_script"; then
        print_info "Verification passed!"
        return 0
    else
        print_error "Verification failed!"
        print_error "Please check the output above for details"
        return 1
    fi
}
# }}}

# -- {{{ main
main() {
    print_header "UT2004 OldUnreal Installation Script"

    print_info "Project Directory: $PROJECT_DIR"
    print_info "Install Target:    $UT2004_DIR"
    print_info "Package Name:      $PACKAGE_NAME"
    if [ $FORCE_DOWNLOAD -eq 1 ]; then
        print_info "Mode:              FORCE DOWNLOAD (will update backup)"
    else
        print_info "Mode:              Use backup if available"
    fi
    echo ""

    # Step 1: Check dependencies
    print_header "Step 1: Checking Dependencies"
    check_dependencies

    # Step 2: Remove existing installation
    print_header "Step 2: Remove Existing Installation"
    remove_existing_installation

    # Step 3: Check for clean backup and use if available
    print_header "Step 3: Check for Clean Backup"
    local use_backup=0
    if check_clean_backup; then
        use_backup=1
    fi

    if [ $use_backup -eq 1 ]; then
        # Install from backup
        print_header "Step 4: Install from Backup"
        install_from_backup

        # Skip to permissions
        print_header "Step 5: Configure Permissions"
        setup_permissions
    else
        # Download fresh copy
        print_header "Step 4: Download OldUnreal Installer"
        installer_script=$(download_oldunreal_installer)

        print_header "Step 5: Run OldUnreal Installer"
        run_oldunreal_installer "$installer_script"

        print_header "Step 6: Configure Permissions"
        setup_permissions

        # Create backup for future use
        print_header "Step 7: Create Clean Backup"
        create_clean_backup
    fi

    # Step N: Create mod directories
    print_header "Creating Mod Directories"
    create_mod_directories

    # Step N+1: Copy existing mod files (if any)
    print_header "Copying Mod Source Files"
    copy_mod_files

    # Step N+2: Copy compiled packages (if any)
    print_header "Copying Compiled Packages"
    copy_compiled_packages

    # Final: Run verification
    print_header "Verifying Installation"
    if run_verification; then
        print_header "Installation Complete!"
        print_info ""
        print_info "UT2004 has been successfully installed to: $UT2004_DIR"
        if [ $use_backup -eq 0 ]; then
            print_info "Clean backup saved to: $PROJECT_DIR/assets/clean-game-install"
            print_info "Future installations will be much faster!"
        fi
        print_info ""
        print_info "You can now proceed with development"
        print_info ""
        print_info "Next steps:"
        print_info "  1. Run: ./scripts/compile.sh"
        print_info "  2. Test the mutator in-game"
        print_info ""
        return 0
    else
        print_header "Installation Failed"
        print_error "Please review the errors above and try again"
        print_error "See docs/007-oldunreal-installation-guide.md for manual installation"
        return 1
    fi
}
# }}}

main "$@"
