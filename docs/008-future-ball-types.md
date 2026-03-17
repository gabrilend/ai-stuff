# 008 - Future Ball Types

## Overview

This document outlines potential special ball types for the upgrade system.
Each ball type would be purchasable with points and spawn periodically or
on-demand alongside regular balls.

## Design Principles

1. **Clear Visual Identity** - Each ball type instantly recognizable
2. **Distinct Physics** - Behavior meaningfully different from standard
3. **Strategic Value** - Creates interesting player decisions
4. **Balanced Cost** - Expensive enough to be meaningful, cheap enough to use

---

## Ball Type Concepts

### Bouncy Ball (Rubber Ball)
**Visual:** Bright green with elastic texture pattern
**Physics:**
- Higher restitution (0.95 vs 0.7)
- Bounces off pegs with almost no energy loss
- Stays in play much longer
- More chaotic trajectory

**Strategic Use:**
- Reaches zones that standard balls can't
- Higher risk of escaping into adversary board
- Fun visual chaos

**Suggested Cost:** 50 points per ball

---

### Heavy Ball (Metal Ball)
**Visual:** Dark gray/silver with metallic sheen
**Physics:**
- 2x gravity multiplier
- Falls faster
- Lower restitution (0.5)
- Pushes other balls on collision

**Strategic Use:**
- More predictable drop trajectory
- Less affected by peg bounces
- Can "bulldoze" through ball clusters

**Suggested Cost:** 75 points per ball

---

### Ghost Ball (Phase Ball)
**Visual:** Semi-transparent white with glow effect
**Physics:**
- Passes through first 3 pegs without collision
- Normal collision after "materializing"
- Cannot collide with other balls

**Strategic Use:**
- Bypass top peg rows to target specific zones
- Unique scoring opportunities
- Counter for adversary ball clusters

**Suggested Cost:** 100 points per ball

---

### Split Ball (Mitosis Ball)
**Visual:** Two-tone (half orange, half yellow)
**Physics:**
- Normal physics until first peg hit
- Splits into two smaller balls on collision
- Each half-ball has half the score value

**Strategic Use:**
- Cover more zones with single spawn
- Good for probability-based scoring
- Useful when spawn rate is limited

**Suggested Cost:** 80 points per ball

---

### Magnet Ball (Attractor Ball)
**Visual:** Purple with field lines radiating
**Physics:**
- Normal gravity and collision
- Attracts nearby regular balls toward it
- Range: 60 pixels
- Force: proportional to distance

**Strategic Use:**
- Create ball clusters for zone targeting
- Pull adversary balls off course
- Chain reaction potential

**Suggested Cost:** 120 points per ball

---

### Sticky Ball (Gum Ball)
**Visual:** Pink with gooey texture
**Physics:**
- Zero restitution on first peg hit
- "Sticks" to peg for 2 seconds
- Then drops straight down
- Normal collision with other balls

**Strategic Use:**
- Precise vertical drop after stick
- Target center zones
- Timing-based play

**Suggested Cost:** 60 points per ball

---

### Explosive Ball (Bomb Ball)
**Visual:** Black with red fuse/spark
**Physics:**
- Normal physics
- Explodes on scoring zone entry
- Pushes all nearby balls outward
- Destroys self (no double scoring)

**Strategic Use:**
- Clear ball clusters
- Push adversary balls away from zones
- Risk: can push your own balls out

**Suggested Cost:** 150 points per ball

---

### Giant Ball (Mega Ball)
**Visual:** Orange with 2x radius
**Physics:**
- Double radius (16 vs 8)
- Normal mass and gravity
- Harder to navigate peg grid
- Larger collision area

**Strategic Use:**
- Blocks adversary balls
- Dominate zone entry
- Chaotic but powerful

**Suggested Cost:** 100 points per ball

---

## Implementation Notes

### Ball Type System Architecture

```
typedef enum {
    BALL_TYPE_STANDARD,
    BALL_TYPE_BOUNCY,
    BALL_TYPE_HEAVY,
    BALL_TYPE_GHOST,
    BALL_TYPE_SPLIT,
    BALL_TYPE_MAGNET,
    BALL_TYPE_STICKY,
    BALL_TYPE_EXPLOSIVE,
    BALL_TYPE_GIANT
} BallType;

// Add to Ball struct:
BallType type;
int special_state;  // Type-specific state (ghost peg count, sticky timer, etc.)
```

### Spawn Integration

- Upgrade menu shows "Next Special Ball: [TYPE]"
- Hold special key (S?) to spawn special ball instead of regular
- Consumes points immediately on spawn
- One special ball "loaded" at a time
- Or: queue system for multiple special balls

### Visual Rendering

- Each ball type has custom render function
- Could use texture atlas for ball appearances
- Particle effects match ball color/type
- Clear visual during spawn selection

### Balance Considerations

- Expensive balls should feel impactful
- Cheap balls provide incremental advantage
- No ball type should dominate
- Cost should scale with game progression
- Consider "unlock" system before purchase available

---

## Priority Order for Implementation

1. **Heavy Ball** - Simple physics change, clear visual
2. **Bouncy Ball** - Simple physics change, fun visual
3. **Giant Ball** - Simple size change, dramatic impact
4. **Ghost Ball** - Moderate complexity, unique mechanic
5. **Split Ball** - Complex (spawns new balls)
6. **Sticky Ball** - Requires timer system
7. **Magnet Ball** - Requires force field system
8. **Explosive Ball** - Requires area effect system

---

## Future Considerations

- Ball type counters (bouncy counters heavy?)
- Adversary AI could use special balls
- Rare "golden" variants with enhanced effects
- Combo system for using multiple types together
- Achievement system tied to ball type usage
