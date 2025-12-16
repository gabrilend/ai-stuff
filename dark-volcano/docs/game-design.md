# Dark Volcano - Game Design Document

## Overview
Dark Volcano is a tower defense/strategy game that combines elements from Legion TD 2, Final Fantasy Tactics Advance (FFTA), Warcraft Rumble, with Tron-inspired aesthetics and "electric submarine" musical themes.

## In-Depth Overview
Dark Volcano represents a revolutionary fusion of tactical strategy and tower defense mechanics, built on cutting-edge technology that pushes the boundaries of real-time strategy gaming. At its core, the game revolves around the strategic creation and deployment of parties—small tactical units composed of FFTA-inspired character classes arranged in meaningful formations on a 3x3 grid. Players must master the delicate balance between three equally viable formation strategies: Circle formations that provide persistent aura benefits to elite 7-unit forces, Box formations with aura units that selectively enhance 5 out of 9 deployed units, and pure Box formations that sacrifice magical enhancement for overwhelming numerical superiority.

The game's unique identity emerges from its innovative technical foundation, featuring GPU-accelerated rendering that splits the screen across CPU cores for parallel processing, while all gamestate calculations occur on the graphics card through sophisticated arithmetic filters. This allows for unprecedented visual fidelity with Tron-inspired neon aesthetics rendered through simple triangle and quad models that come alive through procedural Vulkan-based animations. Rather than using predefined animation sequences, each unit's movement emerges from real-time physics optimization problems solved on the GPU, treating every character as a dynamic system of hinges, joints, and stabilizing inertias.

Perhaps most remarkably, Dark Volcano pioneered a completely new approach to game audio through AI-generated music that responds dynamically to gameplay events. Instead of traditional sound effects, the game converts all audio events to text descriptions that feed into an ever-evolving prompt system for AI music generation. Combat clashes, unit movements, and strategic decisions all contribute words to a continuously shifting musical vocabulary that creates unique "electric submarine" themed soundscapes, with older influences gradually fading to keep the audio experience fresh and responsive.

The strategic depth extends beyond individual battles through an interconnected web of locations reminiscent of grand strategy games like Victoria 3, where terrain-based buildings produce resources that automatically flow to units based on sophisticated priority heuristics. Magic items claimed from battlefield victories must be physically carried by units or they sink into the ground, eventually falling to the planet's core where the dark volcano itself originated—creating a constant tension between risk and reward that permeates every tactical decision.

## Core Game Loop
**Deploy parties → Build parties → Deploy parties → Build parties**

This deceptively simple loop masks profound strategic complexity. In the building phase, players craft parties by selecting unit classes, arranging them in optimal formations, and equipping them with items produced by their economic network. Each decision ripples through multiple systems: formation choice affects not just immediate combat effectiveness but also mobility, resource requirements, and long-term sustainability. The deployment phase then tests these theoretical constructs against the harsh realities of battle, where persistent aura effects, procedural animations, and AI personalities create emergent tactical situations that no amount of planning can fully anticipate. Success requires not just understanding individual systems, but mastering their intricate interconnections—how AI personality matrices influence Dijkstra pathfinding decisions, how aura effects scale with affected unit counts, how item gravity mechanics create battlefield risk assessment challenges, and how the GPU-calculated gamestate responds to player inputs with frame-perfect precision.

## Key Mechanics

### Party Building System
- **3x3 Strategic Grid**: Tactical grid where players create balanced parties
- **Three Balanced Formation Options**:
  - **Circle Formation (7 units)**: All units get persistent aura - mobile elite force
  - **Box + Aura (9 units)**: 5 units enhanced, 4 normal - flexible mixed force
  - **Box No Aura (9 units)**: Pure numbers advantage - overwhelming force
- **Power Balance**: All three formations designed to be approximately equal in effectiveness
- **Strategic Choice**: Formation selection based on tactical preference, not power level
- **FFTA Classes**: Units based on Final Fantasy Tactics Advance job classes
- **Tron Aesthetics**: Units styled as Tron-inspired characters with laser weapons
- **Party Deployment**: Complete parties deployed to adventure with nearby allies
- **Aura Persistence**: Circle formation auras persist even when units separate

### Combat System
- **Tick-Based Combat**: Damage applied as rates that slowly reduce enemy health
- **Dual Health System**: Hidden linear gradient + visible chunked "4 quarters to a heart" display
- **Laser Weapons**: Arm-length quarterstave-like weapons that explode on impact
- **Ricochet Mechanics**: Weapons explode like Minecraft blocks, hover, then reform
- **Visual Separation**: Combat calculations separate from animation effects
- **Performative Play**: Combat motivation is play-based (Toy Story-like), not bloodshed

### Strategic Map
- **Sins of Solar Empire Style**: Large zoomable map with multiple locations
- **Flat Map Design**: Locations generated by random dice rolls
- **Terrain-Based Buildings**: Available buildings determined by location type
- **Kingdom Buildings**: Player castle can have any typical kingdom structures
- **Clash of Clans Style**: Deploy army cards to conquer objectives

### Building and Economy
- **Terrain-Based Buildings**: Buildings match/determine terrain (boneyard for skeleton areas, mushroom golems for magical forests)
- **Victoria 3 Style Production**: Each location has inputs/outputs
- **Resource Management**: Materials, gems, gold flow between locations
- **Auto-Distribution**: Items automatically distributed to units via priority heuristics

### Unit Equipment
- **Hearts of Iron 4 Designer**: Complex unit customization
- **RPG Loadouts**: Character sheet-style equipment system
- **Dynamic Inventory**: Equipment drawn from building production
- **Timer-Based Gravity**: Items despawn after countdown (2 inches per 10 seconds)
- **Carrier Requirement**: Items must be actively held or they sink to the core

### Unique Mechanics
- **Item Gravity**: Items sink into ground if not held (simple countdown timer)
- **Will-Based Weight**: Items must be actively carried or they fall through the earth
- **Magic Item Storage**: Requires dedicated unit to hold items at bases
- **Battlefield Looting**: Quick collection needed or items are lost to the dark volcano
- **Hybrid Networking**: UDP packets with TCP-style confirmation system
- **Location-Priority Physics**: Physics focus on positions rather than momentum

## GPU-Accelerated Systems
- **Multi-Core Rendering**: Screen segmented by CPU core count for parallel rendering
- **GPU Gamestate**: All game calculations performed on graphics card
- **Procedural Animation**: Real-time optimization problems for model movement
- **Vulkan Computing**: Advanced GPU compute shaders for physics and animation

## AI & Personality
- **4-Color Matrix**: Red (aggressive), Blue (defensive), Green (balanced), Yellow (creative)
- **Dijkstra Mapping**: Spatial awareness combined with personality-driven decisions
- **Percentage Choices**: Each decision has personality-weighted options

## Audio Innovation
- **AI-Generated Music**: Dynamic soundtrack based on text prompts
- **Text-Based SFX**: Sound effects converted to text descriptions for AI processing
- **Evanescent Prompts**: Words fade from music prompts over time to keep it fresh

## Setting
Items that fall to the planet's core sink to where the dark volcano erupted from, creating a persistent threat and explaining the game's title.