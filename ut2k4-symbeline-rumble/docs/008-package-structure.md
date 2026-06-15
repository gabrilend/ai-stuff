# Package Structure Documentation

## Overview

The SymbelineRumble mod follows standard UT2004 package conventions with source code maintained in the git repository and synced to the UT2004 installation during compilation.

## Directory Layout

### Repository Structure
```
ut2k4-symbeline-rumble/
├── src/                                  # UnrealScript source files (version controlled)
│   ├── SR_SymbelineRumbleMutator.uc     # Main mutator class
│   ├── SymbelineRumble.int              # Localization strings
│   └── (additional classes added as development progresses)
├── scripts/                              # Build and automation scripts
│   ├── compile.sh                        # Sync and compile
│   ├── clean.sh                          # Clean artifacts
│   └── full-rebuild.sh                   # Clean + compile
└── config.sh                             # Build configuration
```

### UT2004 Installation Structure (Post-Sync)
```
UT2004/  (or ut2004-install/)
├── System/
│   ├── SymbelineRumble.u                 # Compiled package
│   ├── SymbelineRumble.ucl               # Compiler cache
│   ├── SymbelineRumble.int               # Localization (copied from src/)
│   └── ucc-bin-linux-amd64               # UCC compiler
└── SymbelineRumble/                      # Package source (synced from repo)
    └── Classes/
        ├── SR_SymbelineRumbleMutator.uc
        └── (other .uc files)
```

## Build Workflow

1. **Developer edits** source files in `src/`
2. **compile.sh** runs:
   - Syncs `src/*` to `UT2004/SymbelineRumble/Classes/`
   - Runs `ucc make`
   - Creates `SymbelineRumble.u` in `System/`
3. **Source remains** in git repository
4. **Compiled artifacts** are git-ignored

## Class Naming Convention

All classes in this package use the `SR_` prefix to avoid naming conflicts:

- **SR_** = **S**ymbeline **R**umble
- Example: `SR_SymbelineRumbleMutator`, `SR_GameRules`, `SR_PlayerController`

### Naming Rules

1. **All classes** must have `SR_` prefix
2. **File name** must match class name exactly (case-sensitive)
3. **One class** per file
4. **CamelCase** for multi-word names

Examples:
- ✓ SR_CameraController.uc
- ✓ SR_SpawnPointMarker.uc
- ✗ CameraController.uc (missing prefix)
- ✗ SR_cameracontroller.uc (wrong case)

## Package Configuration

### In UT2004.ini (or Default.ini)

The package is automatically configured by the UCC compiler when source files are present in the `UT2004/SymbelineRumble/` directory.

For manual configuration, add to `[Editor.EditorEngine]` section:
```ini
EditPackages=SymbelineRumble
```

### Package Dependencies

Minimum required packages (automatically handled):
- Engine (for Mutator, Actor, Pawn, etc.)
- Core (for Object)

Additional dependencies added as needed for:
- XGame (for specific UT2004 gametypes)
- UnrealGame (for game rules)
- Gameplay (for additional gameplay features)

## Localization

The `SymbelineRumble.int` file provides localized strings:

```
[Public]
Object=(Name=SymbelineRumble.SR_SymbelineRumbleMutator,...)

[SR_SymbelineRumbleMutator]
FriendlyName="Symbeline Rumble"
Description="..."
```

This file is:
- Maintained in `src/SymbelineRumble.int`
- Copied to `System/` during compilation
- Used by UT2004 UI to display mutator info

## Compilation Notes

### UCC Make Process

1. UCC reads package directories in UT2004 installation
2. Finds `SymbelineRumble/Classes/*.uc`
3. Compiles all classes in dependency order
4. Creates `SymbelineRumble.u` bytecode package
5. Generates `SymbelineRumble.ucl` cache for faster recompilation

### Forcing Recompilation

To force a clean recompile:
```bash
./scripts/clean.sh    # Removes .u, .ucl, .int
./scripts/compile.sh  # Recompiles from scratch
```

Or use the combined script:
```bash
./scripts/full-rebuild.sh
```

### Common Compilation Issues

**"Can't find file for package"**
- Source files not synced to UT2004 installation
- Run compile.sh to sync

**"Class already exists in package"**
- Stale .u file exists
- Run clean.sh first

**"Unrecognized member"**
- Typo in property/function name
- Check class dependencies

## Version Control

### Git Tracked
- `src/*.uc` - All UnrealScript source
- `src/*.int` - Localization files
- `scripts/*.sh` - Build scripts
- `config.sh` - Build configuration
- `docs/*.md` - Documentation

### Git Ignored (.gitignore)
- `UT2004/` - Entire game installation
- `*.u` - Compiled packages
- `*.ucl` - Compiler cache
- `*.int` (in System/) - Generated localization
- `tmp/` - Temporary files

## Testing Package Structure

After creating the package structure, verify:

1. **Source files exist** in `src/`
2. **compile.sh runs** without errors (after UT2004 installation completes)
3. **Package compiles** successfully
4. **File sync works** (src/ → UT2004/SymbelineRumble/Classes/)
5. **Mutator appears** in game UI

## Related Documents

- Issue 102: Create Mod Package Structure
- Issue 103: Implement Minimal Mutator
- Issue 105a: Create Core Build Scripts
- docs/001-architecture-overview.md
