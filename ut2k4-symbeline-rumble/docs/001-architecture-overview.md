# Architecture Overview

## Project Description

UT2K4 Symbeline Rumble is a total conversion mod for Unreal Tournament 2004 that implements Warcraft Rumble-style gameplay mechanics within the UT2004 engine.

## Core Components

### 1. View System
- Top-down-ish camera perspective
- Movable via joystick or keyboard
- Per-player perspective management
- Multiple simultaneous player views supported

### 2. Dynamic Occlusion Rendering Engine
- Raycasting-based geometry detection
- AI waypoint-focused occlusion (MVP scope)
- Future: Human player position detection
- Cone-based doodad and map geometry detection
- Per-player occlusion sets (different perspectives)

### 3. Unit Spawning System
- Spawn locations based on map type:
  - Onslaught maps: Node-based spawning
  - Team Deathmatch: AI waypoint spawning
- Visual spawn point indicators:
  - Green orbs: Available (near allies)
  - Red orbs: Unavailable (near foes)
  - Gray orbs: Unclaimed neutral points
- Highlight system for targeted spawn points

### 4. Resource Management
- Adrenaline system (max 100, gain 1 per second)
- Health system (200 max for player)
- Armor system for individual units
- Weapon inventory (4 guns at any time)

### 5. AI Bot System
- Weapon-specific behavior patterns
- Pathfinding with route memory
- Objective-based decision making
- Natural map spreading behavior

## Target Platform

Primary target: Linux version of UT2004
Secondary target: Most up-to-date version (feature parity)

The Linux version is considered the canonical implementation, and all development should target it first.

## Compatibility Requirements

Must not use features added in later game versions. The mod should work with the base UT2004 Linux release.
