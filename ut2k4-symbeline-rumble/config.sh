#!/bin/bash
# UT2K4 Symbeline Rumble - Build Configuration
# This file is sourced by all build scripts
# Edit this file to configure your development environment

# Project directory (auto-detected from this file's location)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# UT2004 installation directory
# Default: Use local game installation in project directory
# This keeps the project self-contained and git-ignored
#
# Override options (in priority order):
#   1. Set UT2004_DIR environment variable before running scripts
#   2. Edit this default value below
#   3. Create config.local.sh and set UT2004_DIR there (git-ignored)
#
if [ -z "$UT2004_DIR" ]; then
    # Check for local override file first
    if [ -f "$PROJECT_DIR/config.local.sh" ]; then
        source "$PROJECT_DIR/config.local.sh"
    fi

    # If still not set, use default
    if [ -z "$UT2004_DIR" ]; then
        UT2004_DIR="$PROJECT_DIR/ut2004-install"
    fi
fi

# Package name (must match directory in UT2004 installation)
PACKAGE_NAME="SymbelineRumble"

# Main mutator class name (without package prefix)
MUTATOR_CLASS="SR_SymbelineRumbleMutator"

# Version information
VERSION="0.1.0-phase1"

# Export variables for use in scripts
export PROJECT_DIR
export UT2004_DIR
export PACKAGE_NAME
export MUTATOR_CLASS
export VERSION

# Validation function (can be called by scripts)
validate_config() {
    local errors=0

    if [ ! -d "$PROJECT_DIR" ]; then
        echo "ERROR: PROJECT_DIR does not exist: $PROJECT_DIR"
        errors=$((errors + 1))
    fi

    if [ ! -d "$UT2004_DIR" ]; then
        echo "WARNING: UT2004_DIR does not exist: $UT2004_DIR"
        echo "  This is normal before UT2004 is installed to this location"
        echo "  Scripts will create the directory structure as needed"
    fi

    return $errors
}

# Optional: Display configuration if script is run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "=== UT2K4 Symbeline Rumble Configuration ==="
    echo ""
    echo "PROJECT_DIR:    $PROJECT_DIR"
    echo "UT2004_DIR:     $UT2004_DIR"
    echo "PACKAGE_NAME:   $PACKAGE_NAME"
    echo "MUTATOR_CLASS:  $MUTATOR_CLASS"
    echo "VERSION:        $VERSION"
    echo ""
    validate_config
fi
