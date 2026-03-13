# Issue 105: Create Build and Testing Scripts (Parent Issue)

## Status
- Phase: 1
- Priority: High
- Status: Open
- Dependencies: 102-create-mod-package-structure

## Current Behavior
No automated build or testing scripts exist. Manual compilation and testing required.

## Intended Behavior
A complete build automation system with:
- Quick compilation
- Easy testing
- Clean build management
- Error reporting
- Log monitoring
- Phase demonstrations
- Unified interface

## Sub-Issues

This issue has been broken down into focused sub-issues:

- **105a**: Core Build Scripts (compile, clean, rebuild)
- **105b**: Testing and Monitoring Scripts (test, watch-log, check-log)
- **105c**: Demo Runner Script (run-phase-demo)
- **105d**: Master Build Wrapper and Documentation (unified interface)

## Overview of Build System

The build system consists of:

### Configuration (Issue 105a)
- `config.sh` - Central configuration file
  - Project directory (auto-detected)
  - UT2004 installation location (configurable)
  - Package and class names

### Core Build Scripts (Issue 105a)
- `scripts/compile.sh` - Sync source and compile with ucc
- `scripts/clean.sh` - Remove build artifacts
- `scripts/full-rebuild.sh` - Clean then compile

### Testing & Monitoring (Issue 105b)
- `scripts/test.sh` - Launch UT2004 with/without mutator
- `scripts/watch-log.sh` - Monitor log in real-time
- `scripts/check-log.sh` - Analyze log for errors/warnings

### Demo System (Issue 105c)
- `scripts/run-phase-demo.sh` - Interactive demo selection
- `demo` - Quick demo launcher (project root)

### Unified Interface (Issue 105d)
- `build` - Master build script (project root)
- `scripts/README.md` - Comprehensive documentation

## Usage Examples

```bash
# Via master build script (recommended)
./build compile
./build test
./build watch
./build demo

# Or directly
./scripts/compile.sh
./scripts/test.sh
```

## Related Documents
- docs/005-roadmap.md (Phase 1)
- issues/101-setup-dev-environment.md

## Tools Required
- Bash shell
- rsync
- grep
- tail

## Technical Notes

### Environment Variables
- UT2004_DIR: Override UT2004 installation path
- Default: $HOME/.ut2004

### Script Design Principles
- All scripts accept optional DIR argument
- Hard-coded default DIR at top
- Relative paths resolved against DIR
- Error checking and reporting
- User feedback (echo statements)

## Acceptance Criteria

This parent issue is complete when all sub-issues are complete:

- [ ] Issue 105a complete (core build scripts)
- [ ] Issue 105b complete (testing and monitoring)
- [ ] Issue 105c complete (demo runner)
- [ ] Issue 105d complete (master wrapper and docs)

## Key Features

### Configurable UT2004 Location
The build system supports three configuration methods:
1. Edit `config.sh` (permanent)
2. Set `UT2004_DIR` environment variable
3. Pass as argument to scripts (advanced)

Default: `PROJECT_DIR/ut2004-install` (local installation)

### Self-Contained Development
By using a local UT2004 installation in the project directory:
- No system-wide installation needed
- Multiple versions/mods can coexist
- Easier to manage and distribute
- Git-ignored to keep repo clean

### Consistent Interface
All scripts:
- Source config.sh for consistency
- Accept PROJECT_DIR override
- Provide clear error messages
- Return proper exit codes
- Work from any directory

## Related Documents
- docs/005-roadmap.md (Phase 1)
- Sub-issues: 105a, 105b, 105c, 105d

## Notes
These scripts will be used throughout all 12 phases of development. They are foundational infrastructure that should be robust, well-documented, and maintainable.

The separation into sub-issues allows focused implementation and testing of each component while maintaining a coherent overall system.
