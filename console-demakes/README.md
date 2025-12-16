# Ocarina of Time Console Demakes

A project to demake Ocarina of Time to earlier console generations.

## Current Implementation: Game Boy Advance

This project has been successfully translated from Game Boy Color to **Game Boy Advance** for better hardware capabilities.

### Quick Start

```bash
./run  # Builds and launches the GBA ROM in an emulator
```

### Features Implemented

- ✅ **Scrolling background system** with keyboard-responsive tilemap
- ✅ **Link sprite character** with 8-directional animation
- ✅ **Input system** supporting all GBA controls
- ✅ **World rotation** with L/R shoulder buttons
- ✅ **Palette effects** with A/B buttons

### Planned Features

- 🔄 **Orbital combat mechanics** (in development)
- 🔄 **Enemy sprite system**
- 🔄 **Companion system** (Navi)
- 🔄 **Scene transitions**
- 🔄 **Audio system**
- 🔄 **Save/load system**

### Controls

| Button | Action |
|--------|--------|
| D-pad | Move Link / Scroll world |
| L/R | Rotate world orientation |
| A | Brighten screen |
| B | Darken screen |
| Start | Pause (planned) |
| Select | Target system (planned) |

### Project Structure

```
src-gba/              # GBA implementation (main)
├── main.c           # Game loop and initialization
├── input.c/h        # 8-directional input system
├── background.c/h   # Tilemap scrolling with rotation
├── sprite.c/h       # Link character and sprite management
├── gba_hardware.h   # Hardware register definitions
├── crt0.s          # ARM7 startup code
├── gba.ld          # Linker script
└── Makefile        # Build system

tools/               # Development tools
├── setup-gba.sh    # Toolchain configuration
└── gba-toolchain/  # ARM GCC compiler

notes/               # Design documents and notes
build-gba.sh         # Build script
run                  # Launch script
archive/gbc-version/ # Archived Game Boy Color implementation
```

### Why Game Boy Advance?

The project was upgraded from Game Boy Color to Game Boy Advance because:

- **16MHz ARM7 CPU** vs 8MHz - enables real-time orbital combat
- **256KB RAM** vs 32KB - supports complex AI companions
- **Hardware sprite rotation/scaling** - perfect for orbital mechanics
- **32,000 simultaneous colors** vs 56 - much richer visuals
- **L/R shoulder buttons** - ideal for camera rotation

### Development

Built with a local ARM GCC toolchain. The ROM (`src-gba/oot_demake_gba.gba`) can be run in any GBA emulator:

- **mGBA** (recommended)
- **VBA-M** 
- **Mednafen**
- **RetroArch with mGBA core**

### Design Philosophy

This demake recreates Ocarina of Time's adventure mechanics in a classic handheld format, featuring:

- **Dragon Warrior-style exploration** with 8-directional movement
- **Real-time orbital combat** around enemies
- **AI companion system** for tactical gameplay
- **Rotating world view** for enhanced spatial awareness

The goal is to capture the essence of OOT's 3D adventure in a compelling 2D handheld experience.