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

### 1. Install OldUnreal UT2004 Patch 3374
- Remove old UT2004 installation (if present)
- Download OldUnreal Full Game Installer or patch tarball
- Install to project directory: UT2004/
- Verify directory structure created correctly

### 2. Verify UCC Compiler Functionality
- Locate ucc-bin-linux-amd64 in System/
- Make executable: `chmod +x ucc-bin-linux-amd64`
- Test UCC: `./ucc-bin-linux-amd64 help`
- Test compiler: `./ucc-bin-linux-amd64 make help` (should NOT say "broken")

### 3. Document Installation
- Record UT2004 installation path in config.sh
- Document directory structure in docs/
- Verify all required directories present:
  - System/ (executables and compiled packages)
  - Maps/ (for testing)
  - Textures/, StaticMeshes/, etc. (game assets)

### 4. Configure Development Environment
- Update config.sh with correct UT2004_DIR
- Create UT2004.ini if needed for compilation settings
- Document UCC compiler options
- Test basic UCC commands

### 5. Establish Testing Workflow
- Document how to launch game: `./ut2004-bin-linux-amd64`
- Test game launches successfully
- Document console commands for mutator loading
- Configure logging for debugging

### 6. Final Verification
- Verify all acceptance criteria met
- Document any deviations or issues
- Update phase-1-progress.md with completion status

## Related Documents
- docs/001-architecture-overview.md
- docs/005-roadmap.md (Phase 1)
- docs/007-oldunreal-installation-guide.md (Installation instructions)

## Tools Required
- UT2004 Linux installation
- Text editor / IDE
- Bash shell
- Git (for version control)

## Acceptance Criteria
- [ ] ucc compiler is accessible and functional
- [ ] Can compile a minimal test package
- [ ] Can load compiled package in-game
- [ ] Testing workflow is established and documented
- [ ] Development environment is fully configured
- [ ] Installation automation scripts created and tested
- [ ] Verification script confirms OldUnreal patch installation

Note: Build scripts are created in Issue 105 and its sub-issues.

## Automation Scripts Created

### scripts/install-ut2004.sh
Fully automated installation script that handles the complete UT2004 setup process including:
- Removal of existing installations
- Download and execution of OldUnreal installer
- Permission configuration
- Mod directory creation
- File copying (source and compiled packages)
- Installation verification

### scripts/verify-ut2004-installation.sh
Comprehensive verification script that checks:
- Directory structure completeness
- Executable permissions
- Core package presence
- UCC compiler functionality
- OldUnreal patch detection (vs broken stock version)

See scripts/README.md for usage details.

## Notes

### Critical Decision: OldUnreal Patch 3374 Required

**Problem Discovered:** Stock UT2004 Linux (2005 release, build 2005-11-23_16.22) has a **broken UCC compiler**. When running `ucc make`, it reports: "ucc make is broken on Unix/Mac right now."

**Root Cause:** Epic Games' Linux porter (Ryan Gordon) never implemented the UnrealScript compiler for Linux, stating it was "low priority." The stock Linux release only contains the game runtime, not development tools.

**Historical Workarounds (Rejected):**
- Wine + Windows UCC (violates Linux-only requirement)
- Cross-compile on Windows (not acceptable for Linux-first development)

**Solution Selected:** OldUnreal Patch 3374
- Provides fully functional native Linux UCC compiler
- First working Linux UnrealScript compiler in UT2004's history
- 64-bit support (x86-64 and ARM64)
- Modern SDL3 backend and improved rendering
- Community-maintained with Epic Games approval

**Compatibility Impact:** Patch 3374 is a modernization patch that maintains compatibility with base game content while fixing critical issues. Development will target patch 3374 as the baseline.

**Installation:** See docs/007-oldunreal-installation-guide.md for detailed installation instructions.

**References:**
- [Using UCC Under Linux (BeyondUnreal Wiki)](https://beyondunrealwiki.github.io/pages/using-ucc-under-linux.html)
- [OldUnreal UT2004 Patches](https://github.com/OldUnreal/UT2004Patches)
- [OldUnreal Full Game Installers](https://github.com/OldUnreal/FullGameInstallers/releases)
