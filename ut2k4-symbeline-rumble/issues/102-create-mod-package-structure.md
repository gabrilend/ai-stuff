# Issue 102: Create Basic Mod Package Structure

## Status
- Phase: 1
- Priority: Critical
- Status: Open
- Dependencies: 101-setup-dev-environment

## Current Behavior
No mod package structure exists.

## Intended Behavior
A properly structured UT2004 mod package with:
- Correct directory layout
- Package definitions
- Class hierarchy foundation
- Build configuration

## Suggested Implementation Steps

### 1. Create Package Directory Structure
```
UT2004/SymbelineRumble/
└── Classes/
    ├── SymbelineRumbleMutator.uc
    └── (additional classes as needed)
```

Note: This goes in the UT2004 installation directory, not the project repository

### 2. Configure Package in UT2004.ini
- Add SymbelineRumble to EditPackages list
- Set proper package path
- Configure any needed package dependencies
- Test that compiler recognizes the package

### 3. Create Skeleton Mutator Class File
- Create file: `SR_SymbelineRumbleMutator.uc`
- Add class declaration extending Mutator
- Add placeholder for GetDescriptionstring()
- Add placeholder for PostBeginPlay()
- Keep as minimal skeleton only

Note: Full implementation happens in Issue 103. This step just creates the file structure so the package compiles.

### 4. Set Up Class Naming Convention
- Prefix: SR_ (SymbelineRumble)
- Example: SR_GameRules, SR_PlayerController, etc.
- Document naming convention
- Ensure no conflicts with existing UT2004 classes

### 5. Create .int Localization File
- Create SymbelineRumble.int file
- Add mutator description
- Add any user-facing strings
- Place in System/ directory after compilation

### 6. Link Source to Repository
- Determine strategy for keeping source in git repo
- Options:
  - Symlink from UT2004/SymbelineRumble to repo src/
  - Copy script from repo to UT2004 installation
  - Work directly in UT2004 and sync back
- Document chosen approach
- Implement sync mechanism

### 7. Test Compilation
- Run ucc make to compile package
- Verify .u file is created in System/
- Check for compilation errors
- Verify package size is reasonable

## Related Documents
- docs/001-architecture-overview.md
- docs/005-roadmap.md (Phase 1)

## Tools Required
- UT2004 installation (from issue 101)
- Text editor
- ucc compiler

## Technical Notes

### Package Dependencies
At minimum, the package will need:
- Engine.Mutator (for base mutator)
- Engine.PlayerController (for camera system, later)
- Engine.Pawn (for bot management, later)

Start minimal, add dependencies as needed.

### UnrealScript Best Practices
- One class per file
- File name matches class name exactly
- Use proper capitalization
- Include header comments with purpose

## Acceptance Criteria
- [x] Package directory structure documented (docs/008-package-structure.md)
- [ ] UT2004.ini properly configured (automatic with OldUnreal patch)
- [x] Skeleton mutator class file created (src/SR_SymbelineRumbleMutator.uc)
- [x] Localization file created (src/SymbelineRumble.int)
- [ ] Package compiles without errors (pending UT2004 installation from Issue 101)
- [ ] .u package file generated successfully (pending compilation)
- [x] Source code is in version control (src/ directory)
- [x] Sync mechanism implemented (compile.sh uses rsync)

## Implementation Notes

### Source Files Created

**src/SR_SymbelineRumbleMutator.uc**
- Skeleton mutator class extending Mutator
- GetDescription() returns mod description
- PostBeginPlay() logs initialization
- Default properties for UI display
- Follows SR_ naming convention

**src/SymbelineRumble.int**
- Public object definition for mutator
- Localization strings for UI
- FriendlyName and Description fields

**docs/008-package-structure.md**
- Complete documentation of package structure
- Build workflow explanation
- Naming conventions
- Compilation process
- Version control strategy
- Troubleshooting guide

### Configuration Improvements

**config.sh** - Simplified from bash script to key=value format
- Cleaner, more maintainable
- Easy to parse
- Supports config.local for overrides
- PROJECT_DIR variable expansion

**scripts/lib-common.sh** - New shared library
- load_config() function parses config files
- Common print functions (print_header, print_info, print_warning, print_error)
- Reduces code duplication across scripts
- All scripts updated to use library

### Sync Mechanism

The compile.sh script uses rsync to sync source files:
- Source: `src/` (in git repository)
- Destination: `UT2004/SymbelineRumble/Classes/` (in installation)
- Preserves file permissions
- Efficient (only copies changed files)
- --delete flag removes stale files

### Testing Status

Source files created and ready for compilation. Full testing requires UT2004 installation to complete (Issue 101 in progress).

## Notes
This issue creates the package structure and skeleton class file. The actual mutator implementation (logging, version info, lifecycle) is in Issue 103.

The separation ensures we can test the build system (Issue 105a) with a compilable package before implementing full functionality.
