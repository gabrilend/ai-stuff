# Scripts Directory

Automation scripts for UT2004 development and installation.

## Installation Scripts

### install-ut2004.sh
**Purpose:** Fully automated installation of UT2004 with OldUnreal Patch 3374

**Usage:**
```bash
# Just run it - no manual steps required!
./scripts/install-ut2004.sh
```

**What it does:**
- Downloads OldUnreal installer script from GitHub automatically
- Removes existing UT2004 installation (if present)
- Runs OldUnreal installer in non-interactive mode
- Downloads all game files (several GB) with OldUnreal Patch 3374
- Configures all file permissions automatically
- Creates mod package directory structure
- Copies existing mod source files (if any)
- Copies compiled packages (if any)
- Runs comprehensive verification to confirm installation

**Dependencies:** wget, bash

**No manual downloads required** - the script handles everything automatically!

### verify-ut2004-installation.sh
**Purpose:** Comprehensive verification of UT2004 installation

**Usage:**
```bash
chmod +x scripts/verify-ut2004-installation.sh
./scripts/verify-ut2004-installation.sh
```

**Checks performed:**
- ✓ UT2004 directory exists
- ✓ Required game asset directories present (Maps, Textures, StaticMeshes, Sounds)
- ✓ Game binary executable (ut2004-bin-linux-amd64)
- ✓ UCC compiler executable (ucc-bin-linux-amd64)
- ✓ Core packages installed (Core.u, Engine.u, XGame.u)
- ✓ UCC compiler functionality
- ✓ UCC make command works (detects OldUnreal patch vs broken stock version)

**Exit codes:**
- 0: All checks passed
- 1: One or more checks failed

## Build Scripts

### compile.sh
**Purpose:** Compile the SymbelineRumble UnrealScript package

**Usage:**
```bash
./scripts/compile.sh
```

**What it does:**
- Verifies UT2004 installation exists
- Creates package directory structure
- Syncs source files from src/ to UT2004 installation
- Runs UCC compiler
- Reports compilation results

**Requirements:** UT2004 installed, source files in src/

### clean.sh
**Purpose:** Clean all build artifacts

**Usage:**
```bash
./scripts/clean.sh
```

**What it does:**
- Removes compiled package files (.u, .ucl, .int)
- Cleans temporary files from tmp/
- Removes UT2004 log files
- Preserves all source code

**Safe to run at any time**

### full-rebuild.sh
**Purpose:** Perform complete clean rebuild

**Usage:**
```bash
./scripts/full-rebuild.sh
```

**What it does:**
- Runs clean.sh to remove all artifacts
- Runs compile.sh to build from scratch
- Ensures fresh build with no stale files

**Equivalent to:** `./scripts/clean.sh && ./scripts/compile.sh`

### Future Build Scripts

Additional scripts will be added in Issue 105b and 105c:
- test.sh - Run automated tests
- watch-log.sh - Monitor game logs
- check-log.sh - Check logs for errors
- run-phase-demo.sh - Run phase demonstration programs

See `issues/105b-create-testing-monitoring-scripts.md` and `issues/105c-create-demo-runner-script.md` for details.

## Usage Notes

All scripts follow these conventions:
- Accept optional DIR variable to override project directory
- Use vimfolds for function collapsing
- Source config.sh for centralized configuration
- Exit with meaningful error codes
- Provide detailed status output

Example:
```bash
# Override project directory
DIR=/custom/path ./scripts/verify-ut2004-installation.sh

# Use default (auto-detected from script location)
./scripts/verify-ut2004-installation.sh
```

## Related Documentation

- docs/007-oldunreal-installation-guide.md - Installation instructions
- issues/101-setup-dev-environment.md - Development environment setup
- issues/105-create-build-and-test-scripts.md - Build system overview
