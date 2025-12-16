# Ocarina of Time GBC Demake - Technical Planning Document

## Project Vision
Transform Ocarina of Time into a Game Boy Color JRPG with Dragon Warrior-style exploration and real-time orbital combat mechanics.

## Core Design Principles
- **Dragon Warrior Exploration**: 8-directional movement, top-down overworld
- **Real-time Orbital Combat**: Circle enemies with L/R, SELECT to switch targets, B to dodge, A to attack
- **AI-Generated Assets**: 8+ directional sprites for all characters/objects
- **Orthographic Backgrounds**: Rotating sprite-based environments (forest, desert, dungeons)
- **Companion System**: Real-time AI companions in combat

## Technical Constraints & Capabilities

### Game Boy Color Specs
- **CPU**: Sharp SM83 @ 8.388608 MHz (dual-speed mode)
- **RAM**: 32 KB work RAM + 16 KB VRAM
- **Graphics**: 160×144 resolution, 56 simultaneous colors from 32,768 palette
- **Palettes**: 8 background + 8 sprite palettes (4 colors each)
- **Max ROM**: 8 MB with Memory Bank Controllers

### Source Material
- **Ocarina of Time Decompilation**: Complete source available (github.com/zeldaret/oot)
- **Actor System**: All enemies, NPCs, items already documented
- **Scene/Room Data**: All environments, dungeons mapped
- **Object Data**: Models, animations, textures catalogued

## System Architecture

### 1. Core Engine
```
├── main.asm              # Entry point, initialization
├── engine/
│   ├── input.asm         # D-pad, button handling
│   ├── graphics.asm      # Sprite/background rendering
│   ├── memory.asm        # RAM management, banking
│   └── audio.asm         # Sound effects, music
```

### 2. Game Systems
```
├── world/
│   ├── overworld.asm     # Dragon Warrior style exploration
│   ├── combat.asm        # Real-time orbital combat
│   ├── companions.asm    # AI partner system
│   └── transitions.asm   # Scene loading/switching
```

### 3. Asset Pipeline
```
├── assets/
│   ├── sprites/          # 8-directional character sprites
│   ├── backgrounds/      # Orthographic environment tiles
│   ├── palettes/         # Color scheme definitions
│   └── audio/           # Compressed audio samples
```

## Combat System Details

### Orbital Mechanics
- **Movement**: Fixed radius circle around target
- **Angle**: 0-255 (8-bit precision for smooth rotation)
- **Speed**: Configurable orbital velocity
- **Collision**: Raycast between Link and target

### Control Scheme
- **Left/Right**: Orbit clockwise/counterclockwise
- **SELECT**: Cycle through nearby enemies
- **B Button**: Dodge backward (brief invincibility)
- **A Button**: Attack/use equipped item
- **Up/Down**: Move closer/farther from target

### Companion AI
```asm
companion_state:
    .db AI_FOLLOW         ; 0=follow, 1=attack, 2=defend
    .db target_priority   ; Enemy selection logic
    .db action_timer      ; Cooldown between actions
```

## Graphics Implementation

### Sprite Generation Strategy
1. **Source Analysis**: Extract 3D models from OOT decompilation
2. **AI Rendering**: Generate 8+ directional sprites per character
3. **Optimization**: Reduce to GBC color limits, compress
4. **Animation**: 2-4 frames per direction for walking/combat

### Background System
- **Tile-based**: 8x8 or 16x16 tiles for memory efficiency
- **Layered**: Foreground/background separation
- **Dynamic**: Rotate tiles for orthographic effect
- **Streaming**: Load chunks as player moves

## Memory Management

### Banking Strategy
```
Bank 0: Core engine, always loaded
Bank 1-3: Overworld data, streaming
Bank 4-7: Combat system, enemies
Bank 8-15: Audio, graphics assets
Bank 16+: Level-specific data
```

### Sprite Allocation
- **Link**: 4 sprites (16x16 composite)
- **Companions**: 2-4 sprites each
- **Enemies**: Variable based on size
- **UI Elements**: Fixed allocation

## Development Phases

### Phase 1: Core Framework
- [ ] Basic GBC development environment setup
- [ ] Input handling and 8-directional movement
- [ ] Simple sprite rendering system
- [ ] Memory banking implementation

### Phase 2: Combat Prototype
- [ ] Orbital movement mechanics
- [ ] Single enemy encounter
- [ ] Basic attack/dodge system
- [ ] Health/damage calculations

### Phase 3: World Systems
- [ ] Overworld exploration (Dragon Warrior style)
- [ ] Scene transitions
- [ ] Simple companion AI
- [ ] Asset streaming

### Phase 4: Content Generation
- [ ] AI sprite generation pipeline
- [ ] OOT asset conversion
- [ ] Audio system implementation
- [ ] Level data creation

### Phase 5: Polish & Optimization
- [ ] Performance optimization
- [ ] Audio/visual polish
- [ ] Save system
- [ ] Testing & debugging

## Audio Design - Unsettling Music System

**Core Concept**: Single long musical track that creates psychological unease through disruption
- **Continuous Play**: One extended musical piece plays throughout gameplay
- **Damage Interruption**: When Link takes damage, screen flashes and music jumps to random timestamp
- **Psychological Effect**: Creates disorientation and tension, breaking player comfort
- **Technical Implementation**: 
  - Store music as compressed samples with timestamp markers
  - Random number generator selects new playback position on damage
  - Brief audio fade/distortion effect during transition

## Key Technical Challenges

1. **Real-time Combat on 8-bit CPU**: Optimize orbital calculations
2. **Asset Conversion**: OOT 3D → GBC 2D sprite pipeline
3. **Memory Constraints**: Efficient streaming of large world
4. **AI Generation**: Automated sprite creation from 3D models
5. **Companion AI**: Simple but effective partner behavior
6. **Unsettling Audio**: Seamless music interruption system

## Success Metrics
- Smooth 60fps gameplay (accounting for GBC limitations)
- Faithful recreation of OOT's core adventure elements
- Innovative combat system that feels natural on handheld
- Demonstrable AI-assisted development pipeline

## Next Steps
1. Set up GBC development toolchain
2. Create basic movement prototype
3. Implement orbital combat mechanics
4. Design AI sprite generation system
5. Begin asset conversion pipeline

---
*This document will evolve as we prototype and discover new technical requirements.*