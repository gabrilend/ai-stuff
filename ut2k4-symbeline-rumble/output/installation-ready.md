# UT2004 Installation Ready

## Summary

I've prepared everything you need for a fully automated UT2004 installation with OldUnreal Patch 3374 (native Linux UCC compiler).

## What's Been Created

### 1. Documentation
- **docs/007-oldunreal-installation-guide.md** - Complete installation guide with three methods
- **scripts/README.md** - Documentation for all automation scripts
- **Updated Issue 101** - Includes critical decision notes and automation details

### 2. Automation Scripts

#### scripts/install-ut2004.sh
Fully automated installation script that:
- ✓ Removes existing UT2004 installation
- ✓ Downloads and runs OldUnreal installer
- ✓ Sets up file permissions
- ✓ Creates mod directory structure
- ✓ Copies existing mod files (if any)
- ✓ Copies compiled packages (if any)
- ✓ Runs verification checks
- ✓ Reports installation status

#### scripts/verify-ut2004-installation.sh
Comprehensive verification that checks:
- ✓ All required directories
- ✓ Executables and permissions
- ✓ Core game packages
- ✓ UCC compiler functionality
- ✓ Detects broken vs working compiler

## How to Install UT2004

### One Command Installation

```bash
cd /mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble
./scripts/install-ut2004.sh
```

**That's it!** No downloads, no manual steps, zero user interaction required.

The script automatically:
- Downloads the OldUnreal installer
- Downloads all game files (several GB)
- Installs UT2004 with OldUnreal Patch 3374
- Configures everything for development
- Verifies the installation

Just run the command and wait for it to complete (may take 10-30 minutes depending on your internet speed).

### Step 3: Verify Installation (Optional)

The installation script runs verification automatically, but you can re-run it anytime:

```bash
chmod +x scripts/verify-ut2004-installation.sh
./scripts/verify-ut2004-installation.sh
```

## What Happens During Installation

1. **Download** - OldUnreal installer script downloaded from GitHub
2. **Cleanup** - If UT2004/ exists, it's removed
3. **OldUnreal Install** - Runs the official OldUnreal installer in non-interactive mode
4. **Game Download** - Downloads all game files and OldUnreal Patch 3374 (several GB)
5. **Permissions** - All game and compiler binaries made executable automatically
6. **Mod Setup** - Creates SymbelineRumble/Classes/ directory structure
7. **File Copy** - Copies any existing mod files from src/ to installation
8. **Package Copy** - Copies any compiled .u/.ucl/.int files
9. **Verification** - Runs comprehensive checks to confirm everything works

## Expected Results

After successful installation, verification shows:
```
==========================================
Verification Summary
==========================================
✓ All checks passed!

Your UT2004 installation is ready for development.
You can proceed with Issue 102: Create mod package structure
```

## What's Next

Once installation is verified:
1. I'll complete Issue 101 and mark it as done
2. Move to Issue 102: Create mod package structure
3. Then Issue 105a: Create core build scripts
4. Then Issue 103: Implement minimal mutator
5. Continue through Phase 1 issues

## Troubleshooting

If verification fails:
- Check the error messages - they're specific
- Ensure you downloaded the correct Linux tarball
- Verify the tarball is in tmp/ut2004-installer/
- See docs/007-oldunreal-installation-guide.md for manual installation

## Key Decision Made

**OldUnreal Patch 3374 is required** because the stock UT2004 Linux version (2005) has a broken UCC compiler that was never fixed by Epic Games. OldUnreal provides the first and only working native Linux UnrealScript compiler for UT2004.

This decision is documented in Issue 101 with full technical justification.

## Files Modified/Created

- ✓ docs/007-oldunreal-installation-guide.md (new)
- ✓ docs/000-table-of-contents.md (updated)
- ✓ scripts/install-ut2004.sh (new)
- ✓ scripts/verify-ut2004-installation.sh (new)
- ✓ scripts/README.md (new)
- ✓ issues/101-setup-dev-environment.md (updated with OldUnreal decision)
- ✓ output/installation-ready.md (this file)

---

Ready to install! Just download the OldUnreal installer and run the script.
