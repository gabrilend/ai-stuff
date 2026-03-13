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
- [ ] Package directory structure created
- [ ] UT2004.ini properly configured
- [ ] Skeleton mutator class file created
- [ ] Package compiles without errors
- [ ] .u package file generated successfully
- [ ] Source code is in version control
- [ ] Sync mechanism between repo and UT2004 is working

## Notes
This issue creates the package structure and skeleton class file. The actual mutator implementation (logging, version info, lifecycle) is in Issue 103.

The separation ensures we can test the build system (Issue 105a) with a compilable package before implementing full functionality.
