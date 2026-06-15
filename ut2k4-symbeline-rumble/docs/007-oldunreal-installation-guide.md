# OldUnreal UT2004 Installation Guide for Linux

## Overview

This guide covers installing UT2004 with OldUnreal Patch 3374, which provides native Linux UCC compiler support for UnrealScript development.

## Why OldUnreal Patch 3374?

The stock UT2004 Linux release (2005) has a broken `ucc make` compiler. Ryan Gordon, Epic's Linux porter, noted it was "low priority" and never fixed it. OldUnreal Patch 3374 provides:

- **Fully functional native Linux UCC compiler** (ucc make works!)
- 64-bit support for x86-64 and ARM64/Aarch64
- Modern SDL3 backend
- Improved OpenGL rendering (AntiDrv)
- Case-insensitive file lookup fixes for Linux

## Installation Methods

### Method 1: Automated Installation Script (Recommended)

The project includes a **fully automated** installation script that requires **zero manual steps**:

**Location:** `scripts/install-ut2004.sh`

**What it does:**
- Downloads the OldUnreal installer script from GitHub
- Removes any existing UT2004 installation automatically
- Runs the OldUnreal installer in non-interactive mode
- Downloads all game files and applies OldUnreal Patch 3374
- Sets up all file permissions automatically
- Creates mod directory structure
- Copies existing mod files (if any) to the installation
- Runs comprehensive verification checks
- Reports detailed installation status

**Usage (one command):**
```bash
cd /mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble
./scripts/install-ut2004.sh
```

**That's it!** The script handles everything - no downloads, no manual steps, no user interaction required.

**Requirements:** `wget` and `bash` (standard on most Linux systems)

### Method 2: Full Game Installer (Manual)

**Download Location:** https://github.com/OldUnreal/FullGameInstallers/releases

**Steps:**
1. Download the Linux installer from the releases page
2. Run the installer script with desired installation path
3. The installer includes patch 3374 and all necessary files

### Method 3: Manual Installation from Game Files

**Prerequisites:**
- UT2004 game files (from CD/DVD or GOG using `innoextract`)
- OldUnreal patch 3374 tarball

**Steps:**

1. **Create installation directory**
   ```bash
   cd /mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble
   mkdir UT2004
   ```

2. **Copy game assets from your source** (CD/GOG extraction)

   Copy these directories ONLY (case-sensitive):
   - Animations
   - Help
   - KarmaData
   - Maps
   - Music
   - Prefabs
   - Sounds
   - Speech
   - StaticMeshes
   - Textures
   - Web

   **CRITICAL:** Do NOT copy the System directory - this will break the game!

3. **Download and extract OldUnreal patch**

   Download from: https://github.com/OldUnreal/UT2004Patches/releases

   ```bash
   cd /mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble/UT2004
   # Extract tarball here
   tar xvf /path/to/oldunreal-patch-3374.tar.gz
   ```

## Post-Installation Verification

After installation, use the automated verification script:

```bash
cd /mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble

# Run verification script
chmod +x scripts/verify-ut2004-installation.sh
./scripts/verify-ut2004-installation.sh
```

The verification script checks:
- ✓ All required directories exist (System, Maps, Textures, etc.)
- ✓ Game and compiler binaries are present and executable
- ✓ Core packages are installed (Core.u, Engine.u, XGame.u)
- ✓ UCC compiler works (not broken!)
- ✓ UCC make command is functional

**Manual Verification:**
If you prefer to verify manually:

```bash
cd /mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble/UT2004/System

# Make UCC executable
chmod +x ucc-bin-linux-amd64

# Test UCC compiler
./ucc-bin-linux-amd64 help

# Test UCC make (should not say "broken")
./ucc-bin-linux-amd64 make help
```

## File Cleanup (If Upgrading from Old Installation)

If you previously had version 3369 or earlier, delete these files from System/:
- Bonuspack.u
- Gui2K4.u
- Gameplay.u
- Ipdrv.u
- Skaarjpack.u
- StreamLineFX.u
- UT2K4Assault.u
- UT2K4AssaultFull.u
- XVoting.u
- xWebAdmin.u

## Configuration for Development

After installation, the config.sh in the project root should point to the new installation:

```bash
UT2004_DIR="/mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble/UT2004"
```

## References

- [OldUnreal Full Game Installers](https://github.com/OldUnreal/FullGameInstallers/releases)
- [OldUnreal UT2004 Patches](https://github.com/OldUnreal/UT2004Patches/releases)
- [OldUnreal Homepage](https://oldunreal.miasma.rocks/)
- [Installation Guide on Linux](https://www.gamingonlinux.com/2026/02/oldunreal-add-new-installers-for-unreal-tournament-2004-unreal-tournament-goty-and-unreal-gold/)

## Known Issues

- Online play: Patch works except on servers using AntiTCC (compatible version in development)
- Case sensitivity: Directory names must match exactly on Linux

## Automation Scripts

The project includes two helper scripts for managing UT2004:

### install-ut2004.sh
**Location:** `scripts/install-ut2004.sh`

Fully automated installation that:
- Backs up existing installations
- Extracts OldUnreal installer
- Configures permissions
- Sets up mod directories
- Copies existing mod files
- Runs verification

### verify-ut2004-installation.sh
**Location:** `scripts/verify-ut2004-installation.sh`

Comprehensive verification that checks:
- Directory structure
- Executables and permissions
- Core game packages
- UCC compiler functionality
- OldUnreal patch detection

Both scripts can be run independently or as part of the automated installation workflow.

## Next Steps

After installation is complete:
1. Run verification script to confirm setup
2. Configure UT2004.ini for mod development (if needed)
3. Proceed to Issue 102: Create mod package structure
4. Implement and compile your first mutator

See Issue 101 for development environment setup details.
