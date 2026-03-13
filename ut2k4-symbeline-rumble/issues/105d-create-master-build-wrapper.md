# Issue 105d: Create Master Build Wrapper and Documentation

## Status
- Phase: 1
- Priority: Medium
- Status: Open
- Dependencies: 105a-create-core-build-scripts, 105b-create-testing-monitoring-scripts, 105c-create-demo-runner-script
- Parent Issue: 105-create-build-and-test-scripts

## Current Behavior
Individual scripts exist but no unified entry point for common operations.

## Intended Behavior
A master build wrapper that provides a single, consistent interface to all build operations, plus comprehensive documentation of the build system.

## Suggested Implementation Steps

### 1. Create Master Build Wrapper

Create `build` in project root:
```bash
#!/bin/bash
# UT2K4 Symbeline Rumble - Master Build Script
# Unified interface to all build operations

# Load configuration
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/config.sh"

# Show usage
show_usage() {
    cat <<EOF
UT2K4 Symbeline Rumble - Build System

Usage: $0 <command> [options]

Commands:
  compile, build       Compile the mod
  clean               Remove build artifacts
  rebuild             Clean and rebuild
  test [map] [yes|no] Launch UT2004 for testing
  watch               Monitor log in real-time
  check               Analyze log for errors
  demo [N]            Run phase demonstration
  help                Show this help message

Examples:
  $0 build            # Compile the mod
  $0 test             # Test with default map
  $0 test ONS-Torlan  # Test with specific map
  $0 test "" no       # Test without mutator
  $0 watch            # Watch log live
  $0 demo             # Interactive demo selection
  $0 demo 1           # Run Phase 1 demo directly

Configuration:
  Edit config.sh to set UT2004_DIR and other options
  Or set UT2004_DIR environment variable

Current Configuration:
  Project: $PROJECT_DIR
  UT2004:  $UT2004_DIR
  Package: $PACKAGE_NAME

EOF
}

# Parse command
case "$1" in
    compile|build)
        "$DIR/scripts/compile.sh"
        ;;
    clean)
        "$DIR/scripts/clean.sh"
        ;;
    rebuild)
        "$DIR/scripts/full-rebuild.sh"
        ;;
    test|run)
        shift  # Remove 'test' from args
        "$DIR/scripts/test.sh" "" "$@"
        ;;
    watch|log)
        "$DIR/scripts/watch-log.sh"
        ;;
    check)
        "$DIR/scripts/check-log.sh"
        ;;
    demo)
        shift  # Remove 'demo' from args
        if [ -n "$1" ]; then
            # Direct phase selection
            "$DIR/demo" "$1"
        else
            # Interactive
            "$DIR/demo"
        fi
        ;;
    help|-h|--help)
        show_usage
        ;;
    "")
        echo "ERROR: No command specified"
        echo ""
        show_usage
        exit 1
        ;;
    *)
        echo "ERROR: Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac

exit $?
```

### 2. Create Comprehensive Scripts Documentation

Create `scripts/README.md`:
```markdown
# Build System Documentation

This directory contains all build, test, and development automation scripts for UT2K4 Symbeline Rumble.

## Quick Start

The easiest way to use the build system is via the master `build` script in the project root:

```bash
./build compile     # Build the mod
./build test        # Test in-game
./build clean       # Clean build artifacts
```

## Configuration

### config.sh
Central configuration file containing:
- `PROJECT_DIR` - Project root (auto-detected)
- `UT2004_DIR` - UT2004 installation location
- `PACKAGE_NAME` - Package name (SymbelineRumble)
- `MUTATOR_CLASS` - Main mutator class name

### Setting UT2004 Location

Three ways to configure UT2004 installation location (in priority order):

1. **Command-line**: Pass as first argument to scripts (advanced)
2. **Environment variable**: `export UT2004_DIR=/path/to/ut2004`
3. **config.sh**: Edit `UT2004_DIR` variable (recommended for permanent setup)

Default location: `PROJECT_DIR/ut2004-install`

## Core Build Scripts (Issue 105a)

### compile.sh
Compiles the mod by syncing source to UT2004 installation and running ucc.

**Usage:**
```bash
./scripts/compile.sh [PROJECT_DIR]
```

**What it does:**
1. Syncs `src/` to `UT2004_DIR/SymbelineRumble/Classes/`
2. Runs ucc make
3. Reports success/failure

**Output:**
- Compiled package: `UT2004_DIR/System/SymbelineRumble.u`

### clean.sh
Removes build artifacts.

**Usage:**
```bash
./scripts/clean.sh [PROJECT_DIR]
```

**What it does:**
1. Removes compiled .u file
2. Cleans tmp/ directory

### full-rebuild.sh
Performs clean followed by compile.

**Usage:**
```bash
./scripts/full-rebuild.sh [PROJECT_DIR]
```

## Testing & Monitoring Scripts (Issue 105b)

### test.sh
Launches UT2004 with the mod for testing.

**Usage:**
```bash
./scripts/test.sh [PROJECT_DIR] [MAP] [yes|no]
```

**Parameters:**
- `MAP` - Map to load (default: DM-Rankin)
- `yes|no` - Enable mutator (default: yes)

**Examples:**
```bash
./scripts/test.sh                    # Default: DM-Rankin with mutator
./scripts/test.sh "" "ONS-Torlan"    # Onslaught map with mutator
./scripts/test.sh "" "DM-Rankin" no  # Vanilla (no mutator)
```

### watch-log.sh
Monitors UT2004 log in real-time.

**Usage:**
```bash
./scripts/watch-log.sh [yes|no] [FILTER]
```

**Parameters:**
- `yes|no` - Follow mode (default: yes)
- `FILTER` - Text to filter for (default: SymbelineRumble)

**Examples:**
```bash
./scripts/watch-log.sh              # Live updates
./scripts/watch-log.sh no           # Dump existing
./scripts/watch-log.sh yes "Error"  # Watch for errors
```

**Tip:** Press Ctrl+C to stop watching

### check-log.sh
Analyzes log for errors, warnings, and load status.

**Usage:**
```bash
./scripts/check-log.sh
```

**Output:**
- Recent package messages
- Errors (if any)
- Warnings (if any)
- Load status confirmation

## Demo Runner (Issue 105c)

### run-phase-demo.sh
Interactive demo selection and execution.

**Usage:**
```bash
./scripts/run-phase-demo.sh
```

**Also available as:**
```bash
./demo       # Interactive
./demo 1     # Run Phase 1 directly
```

## Master Build Script (Issue 105d)

### build (project root)
Unified interface to all build operations.

**Usage:**
```bash
./build <command> [options]
```

**Commands:**
- `compile` or `build` - Compile the mod
- `clean` - Remove build artifacts
- `rebuild` - Clean and rebuild
- `test [map] [yes|no]` - Launch for testing
- `watch` - Monitor log
- `check` - Analyze log
- `demo [N]` - Run demonstration
- `help` - Show usage

**Examples:**
```bash
./build compile
./build test ONS-Torlan
./build watch
./build demo 1
```

## Development Workflow

### Standard Development Cycle
```bash
# 1. Make changes to src/*.uc files
vim src/SR_SymbelineRumbleMutator.uc

# 2. Compile
./build compile

# 3. Test in-game
./build test

# 4. Check logs (in another terminal)
./build watch
```

### Debugging Workflow
```bash
# Clean rebuild
./build rebuild

# Test without mutator (verify base game works)
./build test "" no

# Test with mutator
./build test

# Analyze log for errors
./build check
```

### Phase Completion Workflow
```bash
# Ensure everything works
./build rebuild
./build test

# Run phase demo to verify
./build demo N

# Commit if successful
git add .
git commit -m "Complete Phase N"
```

## Troubleshooting

### Compilation Fails
- Check `UT2004_DIR` is set correctly
- Verify ucc exists: `ls $UT2004_DIR/System/ucc*`
- Review error messages in compile output
- Try clean rebuild: `./build rebuild`

### Game Won't Launch
- Verify UT2004 binary exists
- Check file permissions: `chmod +x $UT2004_DIR/System/ut2004*`
- Try launching manually to test installation

### Mutator Doesn't Load
- Compile first: `./build compile`
- Check .u file exists: `ls $UT2004_DIR/System/SymbelineRumble.u`
- Check log: `./build check`
- Verify .int file exists (created in Issue 102)

### Log File Not Found
- Run game at least once to create log
- Verify UT2004_DIR is correct
- Check: `ls $UT2004_DIR/System/UT2004.log`

## Script Design Principles

All scripts follow these principles:

1. **Source config.sh** - Consistency across all scripts
2. **Accept PROJECT_DIR override** - Compatibility and testing
3. **Clear error messages** - Help debug issues quickly
4. **User feedback** - Echo what's happening
5. **Proper exit codes** - 0 = success, non-zero = failure
6. **Work from any directory** - Use absolute paths

## Environment Variables

- `UT2004_DIR` - Override UT2004 installation path
- `PROJECT_DIR` - Override project directory (rarely needed)

## Future Enhancements

Planned script improvements:
- Automatic version bumping
- Git integration (auto-commit on successful build)
- Parallel compilation (when multi-package)
- Packaging for distribution
- Automated testing suites
- Performance profiling tools

## Related Documentation

- `../docs/005-roadmap.md` - Phase planning
- `../issues/105*.md` - Build system issues
- `../README.md` - Project overview
```

### 3. Make Master Build Script Executable
```bash
chmod +x build
```

### 4. Test Master Build Script
Test all commands:
- `./build help`
- `./build compile` (will fail until source exists, but should show proper error)
- `./build clean`
- `./build rebuild`
- Verify error handling for invalid commands

### 5. Update Main README

Add to `README.md` in the "Development" section:
```markdown
### Building

Use the master build script:

```bash
./build compile     # Compile the mod
./build test        # Test in-game
./build clean       # Clean artifacts
./build rebuild     # Full rebuild
./build watch       # Monitor logs
./build demo        # Run phase demos
./build help        # Show all commands
```

See `scripts/README.md` for detailed documentation.
```

## Related Documents
- All Issue 105 sub-issues (105a, 105b, 105c)
- docs/005-roadmap.md

## Tools Required
- Bash shell
- All scripts from 105a, 105b, 105c

## Acceptance Criteria
- [ ] Master build script created
- [ ] Master build script is executable
- [ ] All commands work correctly
- [ ] Help text is clear and complete
- [ ] scripts/README.md is comprehensive
- [ ] Main README.md updated with build section
- [ ] Error handling is robust
- [ ] Configuration is displayed in help
- [ ] All sub-scripts are properly invoked
- [ ] Scripts tested and documented

## Notes
This is the final piece of the build system. Once complete, Issue 105 (parent) can be closed when all sub-issues (105a-d) are done.

The master build script provides a clean, unified interface that makes the build system approachable for new developers while still allowing direct access to individual scripts for advanced use.

Good documentation is critical - this build system will be used throughout the entire development process for all 12 phases.
