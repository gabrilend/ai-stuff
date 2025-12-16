# Healer-TD Game Design Document

## Overview

Healer-TD is a terminal-based tower defense game designed for peer-to-peer 
networked play using Luasocket, where towers come alive and move to engage 
enemies in tactical combat. The game emphasizes resource optimization and 
strategic placement over traditional static tower defense mechanics.

## Core Concept

Players place towers on a grid battlefield. Each wave, towers animate and 
move toward enemies to engage in combat until victory is achieved. The 
objective is to survive waves using minimal gold while preventing enemies 
from "leaking" through defenses.

## Game Mechanics

### Victory Conditions
- **Win**: Survive all waves while managing resources efficiently
- **Loss**: Lives reach zero when enemies leak through defenses

### Resource Management
- **Gold**: Primary currency for purchasing towers
- **Lives**: Lost when enemies leak through defenses
- **Income**: Increased after surviving each wave
- **Bounty**: Earned by defeating enemy units

### Tower System
- Generic, modular units (customizable via mods)
- Collision-enabled movement (cannot pass through allies or enemies)
- Must navigate around obstacles to reach targets
- Stats include health, damage, speed, and special abilities

## Map Design

### Layout
- Single rectangular map
- Player forces occupy bottom 2/3 of battlefield
- Enemy forces spawn at top 1/3
- Clear sight lines for tactical planning

### Navigation
- Grid-based movement system
- Collision detection prevents unit stacking
- Pathfinding around obstacles and other units

## Control Scheme

### Tower Selection
- **Up Movement**: K, W, Up Arrow
  - Selects next closest tower on row above
  - Falls back to next available row if none found
  - Right tower prioritized when equidistant (configurable)

- **Horizontal Movement**: A, D, H, L, Left/Right Arrows
  - Selects tower left/right on same line
  - Searches alternating rows (up/down) if none on current line
  - Pattern: current line → +1 line → -1 line → +2 lines → -2 lines, etc.

### Wave Management
- Preview upcoming waves during placement phase
- Scroll through deployed towers to view stats
- Real-time combat simulation

## Multiplayer Features

### Synchronization
- Peer-to-peer networking with Luasocket
- Encrypted bytecode message protocol
- Distributed consensus for state management
- Automatic conflict detection and resolution

### Multiplayer Modes
- **Cooperative**: Leaked units assist other players
- **Competitive**: Leaked units attack other players
- **Team-based**: Mixed cooperation/competition

### Player Interaction
- Individual rectangular lanes per player
- Tab navigation between player views (Tab/Shift-Tab or Page Up/Down)
- Leak distribution to next player in rotation
- Shared "essential upgrades" every 5 turns

## Essential Upgrades

### Frequency
Every 5 turns, all players choose from same upgrade options

### Variety
Minimum 20 different upgrade types affecting:
- Unit statistics (health, damage, speed)
- Special abilities
- Economic bonuses
- Tactical advantages

### Selection
Randomly presented options ensure variety and replayability

## Customization Options

### Visual Modes
- Colorblind accessibility support
- Multiple graphics systems:
  - Sixel graphics
  - Braille characters
  - Unicode characters and emojis
  - ASCII fallback

### Configuration
- Command-line option overrides
- Persistent config file settings
- User preference persistence

### Modding Support
- Unit name customization
- Flavor text replacement
- Extensible upgrade system

## Technical Requirements

### Network Compatibility
- Works on public wifi and restrictive networks
- No port forwarding or router configuration required
- Minimal bandwidth requirements
- Terminal-agnostic display

### Performance
- Tick-based simulation
- Efficient state management
- Scalable multiplayer architecture

### Accessibility
- Screen reader compatible
- Keyboard-only navigation
- High contrast mode support

## Monetization (Future)
- Base game free
- Cosmetic mods available
- Community workshop integration
- Tournament support features

## Success Metrics
- Player retention across multiple sessions
- Average session duration
- Community mod adoption
- Multiplayer lobby fill rates

## Development Priorities
1. Core single-player mechanics
2. Terminal rendering and user interface
3. Peer-to-peer networking with Luasocket
4. Encrypted multiplayer synchronization
5. Essential upgrade system
6. Customization and accessibility features
7. Advanced multiplayer modes and features