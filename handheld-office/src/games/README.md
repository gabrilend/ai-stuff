# Games Module

This directory contains all game-related code for the Handheld Office suite.

## Structure
- `src/` - Game engine implementations
- `bin/` - Game demo executables  
- `docs/` - Game-specific documentation
- `build/` - Game build artifacts
- `notes/` - Development notes

## Available Games
- **MMO Demo**: P2P multiplayer game engine
- **Paint Demo**: Handheld painting application
- **Music Demo**: Audio synthesis and playback
- **Terminal Demo**: Terminal emulator and file browser
- **Rocketship Bacterium**: Space exploration game
- **Battleship Pong**: Classic arcade games
- **Media Demo**: Multimedia playback demo

## Building Games
```bash
# Build all games
cargo build --bins --release

# Build specific game
cargo build --bin mmo-demo --release

# Run game
./target/release/mmo-demo
```

## Development
All games are designed for Anbernic handheld devices with:
- Radial input system optimization
- Battery-conscious operation
- P2P networking integration
- Air-gapped security compliance