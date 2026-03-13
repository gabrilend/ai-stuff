# Project Roadmap

## Overview

This roadmap breaks down the UT2K4 Symbeline Rumble total conversion mod into manageable development phases. Each phase builds upon the previous, culminating in a fully playable mod.

---

## Phase 1: Foundation and Basic Infrastructure

**Goal:** Establish the development environment and create the basic mod structure

### Objectives
- Set up UT2004 Linux development environment
- Create basic mod package structure
- Implement minimal mutator that loads successfully
- Verify compatibility with base UT2004 Linux version
- Create build and testing scripts

### Deliverables
- Compilable mod package
- Basic mutator that can be loaded in-game
- Build automation scripts
- Phase 1 demo showing mod loads without crashing

### Success Criteria
- Mod appears in game's mutator list
- Can start a game with the mutator active
- No crashes or errors in game log

---

## Phase 2: Camera and View System

**Goal:** Implement the top-down camera perspective and camera controls

### Objectives
- Create custom camera controller
- Implement keyboard/joystick camera movement
- Set up camera distance and angle controls
- Create smooth camera transitions
- Implement camera bounds (prevent leaving map)

### Deliverables
- Functional top-down camera system
- Camera movement controls (WASD or arrow keys)
- Camera height/angle adjustment
- Phase 2 demo showing camera control on a test map

### Success Criteria
- Player can smoothly control camera position
- Camera stays within reasonable map bounds
- No clipping or visual glitches
- Responsive controls with good feel

---

## Phase 3: Spawn Point Visualization

**Goal:** Create the spawn point indicator system

### Objectives
- Detect and track AI waypoints
- Render spawn point orbs (green/red/gray)
- Implement spawn point highlighting on look-at
- Create proximity-based availability system
- Handle ally/foe detection

### Deliverables
- Visible spawn point indicators
- Color-coded availability system
- Selection highlighting
- Phase 3 demo showing spawn points on multiple map types

### Success Criteria
- Orbs render at appropriate locations
- Colors correctly indicate availability
- Highlighting responds to camera aiming
- Works on both Onslaught and DM maps

---

## Phase 4: Resource and Inventory System

**Goal:** Implement adrenaline, health, and weapon inventory mechanics

### Objectives
- Create adrenaline accumulation system (1 per second)
- Implement adrenaline cap (100 max)
- Create player health system (200 max)
- Implement 4-weapon inventory system
- Create weighted random weapon cycling
- Implement HUD displaying resources and inventory

### Deliverables
- Functional adrenaline system
- Weapon inventory with cycling
- Health tracking system
- Resource HUD display
- Phase 4 demo showing resource accumulation and weapon cycling

### Success Criteria
- Adrenaline accumulates at correct rate
- Weapon cycling prevents immediate repeats
- Health system tracks correctly
- HUD clearly displays all resources

---

## Phase 5: Unit Spawning System

**Goal:** Enable spawning AI bots at spawn points using resources

### Objectives
- Implement spawn action (left-click at highlighted point)
- Consume adrenaline on spawn (10 per unit)
- Transfer weapon to spawned bot
- Remove used weapon from game
- Grant new random weapon to player
- Create basic bot that spawns but doesn't act yet

### Deliverables
- Functional spawn action
- Resource consumption
- Weapon transfer and removal
- Phase 5 demo showing unit spawning and resource consumption

### Success Criteria
- Units spawn at correct locations
- Adrenaline correctly deducted
- Weapons transfer to units
- New weapons granted with correct cycling

---

## Phase 6: Basic AI Behavior

**Goal:** Implement weapon-specific AI behaviors

### Objectives
- Create base AI controller for spawned units
- Implement Lightning Gun (sniper) behavior
- Implement Flak Cannon (brawler) behavior
- Create generic behavior template for other weapons
- Implement basic target selection
- Create path-following with route memory

### Deliverables
- At least 2 distinct weapon behaviors
- Functional AI combat
- Route memory system
- Phase 6 demo showing different AI behaviors in combat

### Success Criteria
- Bots behave distinctly based on weapon
- Combat looks appropriate for each weapon type
- Bots spread naturally through map
- No looping or stuck behaviors

---

## Phase 7: Dynamic Occlusion System

**Goal:** Implement raycasting-based geometry occlusion

### Objectives
- Create raycasting system from AI waypoints to camera
- Detect occluding geometry in cone
- Implement geometry hiding/transparency
- Optimize for performance
- Handle per-player occlusion sets
- Create visual feedback system

### Deliverables
- Functional occlusion system
- Performance-optimized raycasting
- Per-player occlusion handling
- Phase 7 demo showing occlusion on complex map geometry

### Success Criteria
- Units remain visible through obstructions
- Performance remains playable (30+ FPS)
- Works correctly with multiple players
- Visually clear what is being occluded

---

## Phase 8: Pickup Integration

**Goal:** Connect map pickups to resource systems

### Objectives
- Redirect adrenaline pickups to player (+1 per pill)
- Redirect health pickups (partial to player, full to unit)
- Handle armor pickups (unit only)
- Create pickup collection for AI units
- Implement health vial vs health pack differentiation

### Deliverables
- Pickup redirection system
- Correct resource transfers
- AI pickup collection behavior
- Phase 8 demo showing pickup effects on resources

### Success Criteria
- Player gains resources when units collect pickups
- Health transfers calculated correctly
- Armor stays on units only
- AI actively seeks pickups when appropriate

---

## Phase 9: Health and Death System

**Goal:** Implement unit death consequences and player health mechanics

### Objectives
- Implement unit death detection
- Apply health penalty to player on unit death (-10 per unit)
- Implement player death at 0 health
- Create respawn mechanics
- Handle unit cleanup on death

### Deliverables
- Functional death system
- Player health penalties
- Respawn mechanics
- Phase 9 demo showing death consequences

### Success Criteria
- Player health decreases when units die
- Player dies at 0 health
- Respawn works correctly
- No orphaned units or resources

---

## Phase 10: Map Mode Support

**Goal:** Support multiple map types and objectives

### Objectives
- Implement Onslaught node mechanics
- Implement Team Deathmatch scoring
- Create objective detection system
- Implement win/loss conditions
- Handle map-specific objectives

### Deliverables
- Onslaught map support
- Team Deathmatch support
- Objective system
- Phase 10 demo showing different map modes

### Success Criteria
- Games can be won/lost appropriately
- Onslaught nodes work as spawn points
- DM waypoints work as spawn points
- Objectives are detected and completed

---

## Phase 11: All Weapon Behaviors

**Goal:** Implement AI behaviors for all UT2004 weapons

### Objectives
- Define behavior pattern for each weapon type
- Implement behaviors for all remaining weapons
- Balance weapon behaviors
- Test and refine each behavior
- Document weapon behavior patterns

### Deliverables
- Complete weapon behavior set
- Behavior documentation
- Balance testing results
- Phase 11 demo showing all weapon types in action

### Success Criteria
- All weapons have distinct behaviors
- Behaviors feel appropriate and fun
- No weapon is clearly overpowered
- All weapons are tactically viable

---

## Phase 12: Polish and Optimization

**Goal:** Refine gameplay, fix bugs, optimize performance

### Objectives
- Performance profiling and optimization
- Bug fixing pass
- Visual polish (effects, HUD improvements)
- Audio feedback implementation
- Gameplay balance tuning
- User testing and feedback incorporation

### Deliverables
- Optimized build
- Bug-free core gameplay
- Enhanced visual and audio feedback
- Final demo showcasing full game

### Success Criteria
- Smooth performance on target hardware
- No critical bugs
- Polished player experience
- Positive playtester feedback

---

## Future Enhancements (Post-MVP)

- Ground-level human player support
- Advanced AI tactics and coordination
- Player command system
- Custom map support tools
- Multiplayer support (multiple skybox players)
- Steam Workshop integration
- Custom weapon mod support
