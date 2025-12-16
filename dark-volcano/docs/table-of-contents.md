# Dark Volcano - Documentation Table of Contents

## Project Structure Overview

```
dark-volcano/
├── docs/                           # Technical Documentation
├── notes/                          # Vision and Inspiration
├── issues/                         # Development Issues and Progress
├── src/                           # Source Code (Phase 1+)
├── libs/                          # Libraries (Phase 1+)
└── assets/                        # Assets (Phase 1+)
```

## Documentation Hierarchy

### Core Documentation (/docs/)

#### Game Design
- **[game-design.md](game-design.md)** - Master Game Design Document
- **[phase-1-demo-gdd.md](phase-1-demo-gdd.md)** - Phase 1 Demo Specification
- **[roadmap.md](roadmap.md)** - Development Phases and Timeline
- **[critical-convergences.md](critical-convergences.md)** - System Integration Analysis

#### Technical Systems
- **[technical-overview.md](technical-overview.md)** - High-Level Architecture
- **[unit-classes.md](unit-classes.md)** - FFTA-Inspired Unit System
- **[formation-aura-system.md](formation-aura-system.md)** - 3x3 Grid Mechanics
- **[ai-personality-dijkstra-system.md](ai-personality-dijkstra-system.md)** - AI Decision Making
- **[gpu-accelerated-rendering-system.md](gpu-accelerated-rendering-system.md)** - Multi-Core Rendering
- **[procedural-vulkan-animation-system.md](procedural-vulkan-animation-system.md)** - Real-Time Animation
- **[hybrid-networking-system.md](hybrid-networking-system.md)** - Multiplayer Architecture
- **[resource-flow-economy-system.md](resource-flow-economy-system.md)** - Economic Simulation
- **[ai-generated-music-system.md](ai-generated-music-system.md)** - Dynamic Audio System

### Vision and Inspiration (/notes/)

#### Core Vision
- **[vision](../notes/vision)** - Original Game Concept
- **[technical-overview.md](../notes/technical-overview.md)** - Technical Vision

#### Inspiration Sources (/notes/inspiration/)
- **[README.md](../notes/inspiration/README.md)** - Inspiration Overview
- **[majesty-ai](../notes/inspiration/majesty-ai)** - AI Development Framework
- **[symbeline](../notes/inspiration/symbeline)** - Core Design Philosophy
- **[symbeline-aspects](../notes/inspiration/symbeline-aspects)** - Three-Pillar System
- **[symbeline-battlefields](../notes/inspiration/symbeline-battlefields)** - Tactical Combat
- **[symbeline-choice](../notes/inspiration/symbeline-choice)** - Decision Philosophy
- **[symbeline-design-the-guild](../notes/inspiration/symbeline-design-the-guild)** - System Implementation
- **[symbeline-structures](../notes/inspiration/symbeline-structures)** - Alternative Approaches
- **[symbeline-superheros](../notes/inspiration/symbeline-superheros)** - Creative Exploration
- **[wow-server](../notes/inspiration/wow-server)** - Multiplayer Testing

#### Inspiration Analysis (/notes/inspiration/reflections/)
- **[majesty-ai-reflection.md](../notes/inspiration/reflections/majesty-ai-reflection.md)** - AI System Analysis
- **[symbeline-reflection.md](../notes/inspiration/reflections/symbeline-reflection.md)** - Core Philosophy Analysis
- **[symbeline-aspects-reflection.md](../notes/inspiration/reflections/symbeline-aspects-reflection.md)** - System Architecture Analysis
- **[symbeline-battlefields-reflection.md](../notes/inspiration/reflections/symbeline-battlefields-reflection.md)** - Combat Design Analysis
- **[symbeline-choice-reflection.md](../notes/inspiration/reflections/symbeline-choice-reflection.md)** - Decision Framework Analysis
- **[symbeline-design-the-guild-reflection.md](../notes/inspiration/reflections/symbeline-design-the-guild-reflection.md)** - Implementation Analysis
- **[symbeline-structures-reflection.md](../notes/inspiration/reflections/symbeline-structures-reflection.md)** - Alternative Design Analysis
- **[symbeline-superheros-reflection.md](../notes/inspiration/reflections/symbeline-superheros-reflection.md)** - Creative Process Analysis
- **[wow-server-reflection.md](../notes/inspiration/reflections/wow-server-reflection.md)** - Multiplayer Analysis

### Development Issues and Progress (/issues/)

#### Phase 1: Foundation & Core Systems (/issues/phase-1/)
- **[progress.md](../issues/phase-1/progress.md)** - Phase 1 Progress Tracker

##### Core System Issues
- **[001-project-setup-and-engine-selection.md](../issues/phase-1/001-project-setup-and-engine-selection.md)** - Project Foundation
- **[002-3x3-party-composition-grid.md](../issues/phase-1/002-3x3-party-composition-grid.md)** - Formation System
- **[003-basic-unit-class-system.md](../issues/phase-1/003-basic-unit-class-system.md)** - Unit Foundation
- **[004-item-gravity-mechanics.md](../issues/phase-1/004-item-gravity-mechanics.md)** - Physics System
- **[005-basic-tron-visual-style.md](../issues/phase-1/005-basic-tron-visual-style.md)** - Visual Identity
- **[006-simple-unit-movement.md](../issues/phase-1/006-simple-unit-movement.md)** - Movement System
- **[007-ai-personality-system.md](../issues/phase-1/007-ai-personality-system.md)** - AI Behavior
- **[008-tick-based-combat-system.md](../issues/phase-1/008-tick-based-combat-system.md)** - Combat Mechanics

##### GPU Architecture Issues
- **[009-gpu-rendering-architecture.md](../issues/phase-1/009-gpu-rendering-architecture.md)** - Rendering Pipeline
- **[010-procedural-animation-system.md](../issues/phase-1/010-procedural-animation-system.md)** - Animation System

## Document Categories

### By Development Phase
- **Phase 1 (Current)**: Foundation systems and core mechanics
- **Phase 2 (Planned)**: Combat and weapons systems
- **Phase 3 (Planned)**: Strategic map and buildings
- **Phase 4 (Planned)**: Economy and equipment
- **Phase 5 (Planned)**: Advanced features and polish

### By System Domain
- **Core Gameplay**: Formation, units, combat, AI
- **Technical Architecture**: GPU rendering, networking, animation
- **Economic Systems**: Resource flow, building mechanics
- **Visual Design**: Tron aesthetics, procedural effects
- **Audio Systems**: AI-generated music and effects

### By Audience
- **Developers**: Technical specifications and implementation details
- **Designers**: Game mechanics and player experience
- **Stakeholders**: Vision documents and progress tracking
- **Community**: Inspiration sources and design philosophy

## Documentation Conventions

### File Naming
- Kebab-case for all filenames
- Descriptive names indicating content and purpose
- Version numbers only for major revision tracking

### Cross-References
- Use relative paths for internal document links
- Reference specific sections with anchor links where applicable
- Maintain bidirectional references between related documents

### Update Protocol
- New documents must be added to this table of contents
- Document modifications should update relevant cross-references
- Issue completion should update progress tracking documents
- All changes should maintain the immutable issue history principle

## Quick Navigation

### Essential Reading (New Contributors)
1. [vision](../notes/vision) - Start here for project understanding
2. [game-design.md](game-design.md) - Core gameplay mechanics
3. [roadmap.md](roadmap.md) - Development timeline and phases
4. [critical-convergences.md](critical-convergences.md) - Key development challenges

### Current Development (Phase 1)
1. [progress.md](../issues/phase-1/progress.md) - Current status
2. [phase-1-demo-gdd.md](phase-1-demo-gdd.md) - Demo specifications
3. Active issues: 001-010 in [issues/phase-1/](../issues/phase-1/)

### Technical Deep-Dive
1. [technical-overview.md](technical-overview.md) - Architecture overview
2. [gpu-accelerated-rendering-system.md](gpu-accelerated-rendering-system.md) - Performance focus
3. [ai-personality-dijkstra-system.md](ai-personality-dijkstra-system.md) - AI complexity
4. [procedural-vulkan-animation-system.md](procedural-vulkan-animation-system.md) - Animation innovation

This table of contents provides comprehensive navigation for the Dark Volcano 
project documentation, maintaining the project's focus on systematic development 
and thorough documentation of design decisions and technical implementations.