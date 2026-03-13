# Issue 105a: Create Core Build Scripts

## Status
- Phase: 1
- Priority: High
- Status: Open
- Dependencies: 102-create-mod-package-structure
- Parent Issue: 105-create-build-and-test-scripts

## Current Behavior
No automated build scripts exist. Compilation and cleanup must be done manually.

## Intended Behavior
Core build automation scripts that handle:
- Source syncing to UT2004 installation
- Compilation via ucc
- Build artifact cleanup
- Full rebuild (clean + compile)

## Suggested Implementation Steps

### 1. Create Project Configuration File

Create `config.sh` in project root:
```bash
#!/bin/bash
# UT2K4 Symbeline Rumble - Build Configuration
# This file is sourced by all build scripts

# Project directory (auto-detected)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# UT2004 installation directory
# Default: Use local game installation in project
# Override with UT2004_DIR environment variable
if [ -z "$UT2004_DIR" ]; then
    UT2004_DIR="$PROJECT_DIR/ut2004-install"
fi

# Package name
PACKAGE_NAME="SymbelineRumble"

# Main mutator class
MUTATOR_CLASS="SR_SymbelineRumbleMutator"

# Export for use in scripts
export PROJECT_DIR
export UT2004_DIR
export PACKAGE_NAME
export MUTATOR_CLASS
```

### 2. Create compile.sh Script

```bash
#!/bin/bash
# Compile the SymbelineRumble mod

# Load configuration
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"

# Accept DIR override from command line (for compatibility)
if [ -n "$1" ]; then
    PROJECT_DIR="$1"
fi

echo "=== SymbelineRumble Compiler ==="
echo "Project dir: $PROJECT_DIR"
echo "UT2004 dir: $UT2004_DIR"
echo ""

# Verify UT2004 installation exists
if [ ! -d "$UT2004_DIR/System" ]; then
    echo "ERROR: UT2004 installation not found at: $UT2004_DIR"
    echo "Please set UT2004_DIR in config.sh or as environment variable"
    exit 1
fi

# Create package directory if it doesn't exist
mkdir -p "$UT2004_DIR/$PACKAGE_NAME/Classes"

# Sync source files to UT2004 installation
echo "Syncing source files..."
rsync -av --delete "$PROJECT_DIR/src/" "$UT2004_DIR/$PACKAGE_NAME/Classes/"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to sync source files"
    exit 1
fi

# Run compiler
echo "Compiling..."
cd "$UT2004_DIR/System"

if [ ! -x "./ucc" ] && [ ! -x "./ucc-bin" ]; then
    echo "ERROR: ucc compiler not found in $UT2004_DIR/System"
    exit 1
fi

# Try different ucc executable names
if [ -x "./ucc" ]; then
    ./ucc make
elif [ -x "./ucc-bin" ]; then
    ./ucc-bin make
fi

COMPILE_RESULT=$?

echo ""
if [ $COMPILE_RESULT -eq 0 ]; then
    echo "=== Build successful ==="
    if [ -f "$PACKAGE_NAME.u" ]; then
        ls -lh "$PACKAGE_NAME.u"
    else
        echo "WARNING: Expected package file not found: $PACKAGE_NAME.u"
    fi
else
    echo "=== Build failed ==="
    exit 1
fi
```

### 3. Create clean.sh Script

```bash
#!/bin/bash
# Clean build artifacts

# Load configuration
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"

# Accept DIR override from command line
if [ -n "$1" ]; then
    PROJECT_DIR="$1"
fi

echo "=== SymbelineRumble Clean ==="
echo "Project dir: $PROJECT_DIR"
echo "UT2004 dir: $UT2004_DIR"
echo ""

# Remove compiled package
if [ -f "$UT2004_DIR/System/$PACKAGE_NAME.u" ]; then
    rm -fv "$UT2004_DIR/System/$PACKAGE_NAME.u"
    echo "Removed compiled package"
else
    echo "No compiled package to remove"
fi

# Remove temporary files
if [ -d "$PROJECT_DIR/tmp" ]; then
    rm -rfv "$PROJECT_DIR/tmp/"*
    echo "Removed temporary files"
fi

echo ""
echo "=== Clean complete ==="
```

### 4. Create full-rebuild.sh Script

```bash
#!/bin/bash
# Clean and rebuild

# Load configuration
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"

# Accept DIR override from command line
if [ -n "$1" ]; then
    PROJECT_DIR="$1"
fi

echo "=== Full Rebuild ==="
echo ""

"$PROJECT_DIR/scripts/clean.sh" "$PROJECT_DIR"

if [ $? -eq 0 ]; then
    echo ""
    "$PROJECT_DIR/scripts/compile.sh" "$PROJECT_DIR"
else
    echo "ERROR: Clean step failed"
    exit 1
fi
```

### 5. Set Up Scripts Directory
- Create scripts/ directory: `mkdir -p scripts/`
- Move all created scripts to scripts/
- Make executable: `chmod +x scripts/*.sh`
- Move config.sh to project root
- Test each script individually

### 6. Test Scripts
- Run clean.sh (should complete without errors)
- Run compile.sh (will fail until Issue 102 complete, but should attempt compilation)
- Run full-rebuild.sh
- Verify config.sh is properly sourced
- Test with different UT2004_DIR values

## Related Documents
- docs/005-roadmap.md (Phase 1)
- issues/101-setup-dev-environment.md
- issues/102-create-mod-package-structure.md

## Tools Required
- Bash shell
- rsync
- UT2004 installation (or placeholder directory for testing)

## Technical Notes

### Configuration Priority
1. Command-line argument to script
2. UT2004_DIR environment variable
3. Default in config.sh (PROJECT_DIR/ut2004-install)

### Script Design Principles
- All scripts source config.sh for consistency
- All scripts accept optional PROJECT_DIR argument for compatibility
- Relative paths resolved against PROJECT_DIR
- Error checking and clear error messages
- User feedback via echo statements

### Directory Structure Expected
```
ut2004-install/
├── System/
│   ├── ucc (or ucc-bin)
│   └── *.u (compiled packages)
├── SymbelineRumble/
│   └── Classes/
│       └── *.uc (synced source files)
└── Maps/ (for testing)
```

## Acceptance Criteria
- [ ] config.sh created with sensible defaults
- [ ] compile.sh created and executable
- [ ] clean.sh created and executable
- [ ] full-rebuild.sh created and executable
- [ ] All scripts source config.sh properly
- [ ] Scripts handle missing UT2004_DIR gracefully
- [ ] Scripts work from any directory
- [ ] Error messages are clear and helpful
- [ ] Scripts tested and working

## Notes
These are the foundational build scripts. Testing and monitoring scripts are in Issue 105b.

The use of a local ut2004-install directory allows development without system-wide installation, and makes the project more self-contained.
