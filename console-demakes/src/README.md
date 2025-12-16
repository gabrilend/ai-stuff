# GBA Ocarina of Time Demake

A Game Boy Advance demake of Ocarina of Time featuring:

- 8-directional movement with camera rotation
- Keyboard-responsive tilemap backgrounds
- Real-time orbital combat system (planned)
- AI companion system (planned)

## Current Implementation

This demo implements a tilemap background system that responds to keyboard input:

- **D-Pad Up/Down**: Move forward/backward in current facing direction
- **D-Pad Left/Right**: Strafe left/right (or rotate with L/R)
- **L/R Shoulder**: Rotate camera/world view
- **A Button**: Brighten screen palette
- **B Button**: Darken screen palette

## Building

1. Ensure ARM GCC toolchain is set up (see `../tools/setup-gba.sh`)
2. Run `make` to build the ROM
3. The output `oot_demake_gba.gba` can be run in any GBA emulator

```bash
cd src-gba
make clean
make
```

## Project Structure

```
src-gba/
├── main.c          # Main entry point and game loop
├── input.c/h       # Input handling system
├── background.c/h  # Tilemap background system
├── gba_hardware.h  # Hardware register definitions
├── crt0.s          # ARM7 startup assembly
├── gba.ld          # Linker script
├── Makefile        # Build configuration
└── README.md       # This file
```

## Technical Features

### Input System
- 8-directional movement detection
- Button press/hold/release states
- Raw input access for advanced controls

### Background System
- Hardware-accelerated tile scrolling
- Visual rotation effects via tilemap changes
- Multiple tile patterns for different orientations
- Sub-pixel precision scrolling

### Graphics
- Mode 0 tile graphics (4 background layers available)
- 16-color palettes with dynamic palette effects
- 256x256 pixel tilemap with wrapping

## Future Development

This is the foundation for the full Ocarina of Time demake. Planned features:

1. **Sprite System**: Link character with 8-directional animation
2. **Combat System**: Real-time orbital combat mechanics
3. **Companion AI**: Navi and other AI companions
4. **Scene System**: Multiple areas and transitions
5. **Audio System**: Music and sound effects
6. **Save System**: Game progress saving

## Design Philosophy

The GBA version enhances the original Game Boy Color design with:

- **Hardware acceleration**: Sprite rotation/scaling for smooth orbital combat
- **Expanded memory**: 256KB RAM for complex AI and world systems
- **Better graphics**: 32,000 colors and hardware tile effects
- **Processing power**: 16MHz ARM7 CPU for real-time calculations

This maintains the "retro handheld" feel while enabling the complex systems described in the original design document.