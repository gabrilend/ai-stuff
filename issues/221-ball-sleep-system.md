# 1307 - Ball Sleep System and Pile Stability

## Status: Open

## Problem

When balls collect in a V-shaped bucket or pile up, they experience instability:
1. ~10-20 balls collect
2. Bottom balls get compressed (slight overlap)
3. Collision resolution adds energy trying to separate them
4. Energy accumulates, eventually causing "explosions"
5. Balls bounce chaotically instead of resting peacefully

## Current Behavior

- Balls pile up initially
- Compression visible at bottom of pile
- After accumulating ~10-20 balls, system becomes unstable
- Sudden explosive release of energy
- Balls scatter chaotically

## Intended Behavior

1. Balls pile up and come to rest naturally
2. Resting balls don't push each other or experience "weight"
3. Pile remains stable indefinitely
4. New ball landing wakes nearby balls briefly, then settles
5. Only dynamic objects (rotors, movers) can cause crushing

## Sub-Issues

| ID    | Description                           | Status |
|-------|---------------------------------------|--------|
| 1307a | Ball sleep state tracking             | Open   |
| 1307b | Sleep transition logic                | Open   |
| 1307c | Wake conditions                       | Open   |
| 1307d | Soft collision response for piles     | Open   |
| 1307e | Stress source distinction             | Open   |

## Rollback Plan

If this system makes things worse, revert to stable checkpoint:
```bash
git checkout phase12-complete-stable
```

## Technical Approach

### Core Concept

"Balls at rest don't have weight, but do have mass"

- **No weight**: Sleeping balls don't apply gravitational pressure to balls below
- **Have mass**: Fast-moving balls hitting pile still transfer momentum

### Sleep State

```c
typedef struct Ball {
    // ... existing fields ...
    int is_sleeping;
    int frames_at_rest;
    float last_significant_velocity;
} Ball;
```

### Sleep Transition

```
AWAKE → frames_at_rest > THRESHOLD → SLEEPING
SLEEPING → wake_condition → AWAKE
```

## Expected Outcomes

| Scenario | Current | Expected |
|----------|---------|----------|
| 20 balls in bucket | Explodes | Rests peacefully |
| Ball dropped on pile | Chaos | Brief disturbance, settles |
| Rotor hits pile | N/A | Balls pushed/crushed |
| Pile against wall | Pressure builds | Stable rest |

## Troubleshooting Guide

### If balls never sleep:
- Check REST_THRESHOLD - may be too low
- Check SLEEP_DELAY - may be too high
- Verify velocity calculation includes all forces

### If balls sleep too easily:
- Reduce SLEEP_DELAY
- Increase REST_THRESHOLD
- May need "settling" period before sleep eligible

### If sleeping balls still explode:
- Sleeping balls may still be colliding
- Ensure collision skip for sleep-sleep pairs
- Check gravity is disabled for sleeping balls

### If balls don't wake when hit:
- Wake radius may be too small
- Collision detection may skip sleeping balls
- Verify wake conditions trigger correctly

### If pile looks "frozen" unnaturally:
- Add slight position jitter when near-sleeping
- Add visual "settled" indicator
- Consider partial sleep (reduced physics, not zero)

### If new balls pass through pile:
- Sleeping balls must still RECEIVE collisions
- Only outgoing forces disabled, not incoming
- Check collision detection order

## Files to Modify

- `src/006-ball.h` - Add sleep state fields
- `src/007-ball.c` - Sleep logic, modified collision response
- `src/001-main.c` - Sleep update in game loop

## Notes

- This is foundational for 1305f/1306g (crushing) - only dynamic stress crushes
- May want visual indicator for sleeping balls (subtle glow dim?)
- Consider sound design - sleeping pile is quiet, wake is soft rustle
