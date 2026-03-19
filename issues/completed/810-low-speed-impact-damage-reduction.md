# 1010 - Low-Speed Impact Damage Reduction

## Current Behavior

Damage from ball-to-ball collisions is calculated linearly based on closing speed:

```c
// src/007-ball.c:388-393
// Calculate damage based on closing speed (velocity along collision normal)
// Head-on collisions deal full damage, glancing blows deal little/none
// vn is negative when approaching, so use -vn for positive damage
float closing_speed = -vn;
float damage = closing_speed * DAMAGE_VELOCITY_SCALE;
ball_a->health -= damage;
```

Where `DAMAGE_VELOCITY_SCALE = 0.1f` (src/006-ball.h:48).

**Problem:** Low-speed impacts (gentle bumps, balls rolling into each other) deal damage proportional to speed. Even a 50 pixel/sec bump deals 5 damage. With balls frequently bumping at low speeds, they accumulate damage quickly from insignificant collisions.

## Intended Behavior

Low-speed impacts should deal minimal or no damage. Only significant collisions should hurt.

**Options for implementation:**

### Option A: Damage threshold
No damage below a minimum speed threshold:
```
if closing_speed < 100: damage = 0
else: damage = (closing_speed - 100) * scale
```

### Option B: Non-linear scaling (quadratic)
Low speeds deal proportionally less damage:
```
damage = closing_speed^2 * scale
```
A 50 speed collision = 2500 * scale
A 200 speed collision = 40000 * scale (16x more, not 4x)

### Option C: Soft threshold with curve
Smooth transition from no damage to full damage:
```
effective_speed = max(0, closing_speed - threshold)
damage = effective_speed * scale
```

**Recommended: Option A (threshold)** - Simplest to tune, clearest behavior.

## Suggested Implementation Steps

### Step 1: Add damage threshold constant

```c
// src/006-ball.h
#define DAMAGE_SPEED_THRESHOLD 80.0f  // No damage below this closing speed
```

### Step 2: Update damage calculation

```c
// src/007-ball.c - in ball-ball collision handling
float closing_speed = -vn;

// Only deal damage above threshold
if (closing_speed > DAMAGE_SPEED_THRESHOLD) {
    float effective_speed = closing_speed - DAMAGE_SPEED_THRESHOLD;
    float damage = effective_speed * DAMAGE_VELOCITY_SCALE;
    ball_a->health -= damage;
    ball_b->health -= damage;
}
// else: no damage from gentle bumps
```

### Step 3: Adjust scale if needed

With a threshold of 80, previous damage values change:
- 50 speed: was 5 damage, now 0 damage
- 100 speed: was 10 damage, now 2 damage
- 200 speed: was 20 damage, now 12 damage
- 400 speed: was 40 damage, now 32 damage

May want to increase DAMAGE_VELOCITY_SCALE to compensate for reduced overall damage:

```c
#define DAMAGE_VELOCITY_SCALE 0.15f  // Increased to compensate for threshold
```

### Step 4: Consider different thresholds for ball types

If player balls should be more durable than adversary balls (or vice versa):

```c
float get_damage_threshold(Ball* ball) {
    if (ball->owner == OWNER_PLAYER) {
        return 80.0f;  // Player balls more resilient
    }
    return 60.0f;  // Adversary balls slightly less resilient
}
```

### Step 5: Update particle effects (optional)

Only spawn damage particles for significant hits:

```c
if (closing_speed > DAMAGE_SPEED_THRESHOLD) {
    // Spawn damage particles
    particle_spawn_burst(...);
}
// No particles for gentle bumps
```

## Files to Modify

- `src/006-ball.h` - Add DAMAGE_SPEED_THRESHOLD constant
- `src/007-ball.c` - Update damage calculation in collision handling

## Testing

1. Balls gently bumping (~50 speed) - no damage
2. Moderate collision (~150 speed) - some damage
3. Hard collision (~300+ speed) - significant damage
4. Verify balls survive longer with normal gameplay
5. Verify balls still die from sustained high-speed collisions
6. Check that game doesn't become too easy (balls too durable)

## Balance Notes

This change should be documented in `docs/balance-updates.md` once values are finalized. The threshold and scale values may need tuning based on playtesting:

- Too high threshold: balls never die, game stalls
- Too low threshold: no noticeable change
- Sweet spot: gentle bumps harmless, hard hits matter

## Completion Notes

**Status:** Completed

**Implementation:**
1. Added `DAMAGE_SPEED_THRESHOLD` constant (80.0f) - no damage below this speed
2. Updated `DAMAGE_VELOCITY_SCALE` from 0.1f to 0.15f to compensate for threshold
3. Modified damage calculation in `ball_resolve_ball_collision()`:
   - Only applies damage when `closing_speed > DAMAGE_SPEED_THRESHOLD`
   - Uses `effective_speed = closing_speed - threshold` for damage calculation

**Damage formula after change:**
- 50 speed: 0 damage (below threshold)
- 100 speed: (100-80) * 0.15 = 3 damage
- 200 speed: (200-80) * 0.15 = 18 damage
- 400 speed: (400-80) * 0.15 = 48 damage

**Files Changed:**
- `src/006-ball.h:46-49` - Added DAMAGE_SPEED_THRESHOLD, adjusted scale
- `src/007-ball.c:384-398` - Updated damage calculation with threshold
