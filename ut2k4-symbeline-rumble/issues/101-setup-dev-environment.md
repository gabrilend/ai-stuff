# Issue 101: Setup UT2004 Linux Development Environment

## Status
- Phase: 1
- Priority: Critical
- Status: Open

## Current Behavior
No development environment is configured for UT2004 modding on Linux.

## Intended Behavior
A fully functional UT2004 Linux development environment that allows:
- Compilation of UnrealScript code
- Testing mods in-game
- Debugging capabilities
- Version control integration

## Suggested Implementation Steps

### 1. Locate UT2004 Installation
- Verify UT2004 Linux installation path
- Document installation directory structure
- Identify key directories:
  - System/ (for compiled packages)
  - UT2004Mod/ or similar (for mod source)
  - Maps/ (for testing)

### 2. Set Up UnrealScript Compiler
- Locate ucc (Unreal Command Compiler)
- Test compilation with: `ucc help`
- Document compiler flags and options
- Create test compilation of existing mod (if any)

### 3. Configure Make/Build System
- Determine if using ucc directly or wrapper scripts
- Set up proper paths in UT2004.ini or similar config
- Configure EditPackages entries
- Test clean build process

### 4. Establish Testing Workflow
- Document how to launch game with custom mutator
- Set up console command shortcuts
- Configure logging for debugging
- Test map loading with mod active

### 5. Create Development Scripts
- Script to compile mod: `compile.sh`
- Script to launch game for testing: `test.sh`
- Script to clean build artifacts: `clean.sh`
- Add error handling and user feedback

### 6. Documentation
- Document all paths and configurations
- Create quick-start guide for development
- List common compiler errors and solutions
- Document testing procedure

## Related Documents
- docs/001-architecture-overview.md
- docs/005-roadmap.md (Phase 1)

## Tools Required
- UT2004 Linux installation
- Text editor / IDE
- Bash shell
- Git (for version control)

## Acceptance Criteria
- [ ] ucc compiler is accessible and functional
- [ ] Can compile a minimal test package
- [ ] Can load compiled package in-game
- [ ] Build scripts are functional and documented
- [ ] Testing workflow is established and documented

## Notes
Target the base UT2004 Linux version for maximum compatibility. Do not rely on features from later patches unless absolutely necessary.
