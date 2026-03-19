# 1309 - Unified Spawner System

## Status: Complete

## Parent Phase: Phase 13

## Problem

Player and adversary spawning systems are duplicated implementations with slight variations. This violates DRY principles and makes maintenance harder. Both should use a shared "Spawner" primitive with configurable behavior.

## Current Behavior

**Player spawning (src/001-main.c + src/007-ball.c):**
- `SPAWN_RATE = 1.7f` base rate
- Credits stored in `ball_manager->spawn_credits`
- Upgrade bonuses added separately in main.c
- Input-controlled reticle position
- Spawn blocking check in `ball_manager_spawn_blocked()`
- Reticle rendering inline in main.c

**Adversary spawning (src/013-adversary.c):**
- `ADVERSARY_SPAWN_RATE = 1.3f` fixed rate
- Credits stored in `adversary->spawn_credits`
- No upgrade system
- Track-based oscillating movement
- Separate spawn blocking check (duplicated logic)
- Separate reticle rendering

Both eventually call `ball_manager_spawn()` but everything else is duplicated.

## Intended Behavior

Single `Spawner` struct and functional API that handles:
- Credit accumulation (configurable rate)
- Spawn attempt with blocking check
- Reticle position management
- Reticle rendering

Control schemes and parameters passed as arguments or function pointers.

## Functional Style Design

### Core Data Structure

```c
typedef struct Spawner {
    float x, y;              // Current reticle position
    float credits;           // Accumulated spawn credits
    float rate;              // Credits per second
    int owner;               // OWNER_PLAYER or OWNER_ADVERSARY
    float gravity_dir;       // +1.0 (down) or -1.0 (up)
    Color color_dim;         // Reticle dim color
    Color color_bright;      // Reticle bright color
} Spawner;
```

### Pure Functions (no side effects, same input = same output)

```c
// Calculate new credits after dt seconds (pure)
float spawner_accumulate(float current_credits, float rate, float dt, float max_credits);

// Check if spawn is blocked at position (pure query)
int spawner_is_blocked(float x, float y, float radius,
                       Ball* balls, int count, int owner_filter);

// Calculate reticle color based on credits (pure)
Color spawner_get_arc_color(float credits, Color dim, Color bright);

// Calculate oscillating position (pure, for AI track)
float spawner_oscillate(float current_x, float direction, float speed, float dt,
                        float min_x, float max_x, float* out_new_direction);
```

### Effectful Functions (clearly separated)

```c
// Attempt spawn - returns 1 if spawned, 0 if blocked/no credits
int spawner_try_spawn(Spawner* spawner, BallManager* manager, float ball_radius);

// Render reticle at current position
void spawner_render(Spawner* spawner);

// Update spawner state (accumulate credits, move position via controller)
void spawner_update(Spawner* spawner, SpawnerController controller, void* controller_data, float dt);
```

### Controller Pattern (functional composition)

```c
// Controller function type - returns new x position
typedef float (*SpawnerController)(Spawner* spawner, void* data, float dt);

// Player controller - reads input, returns new x
float controller_player_input(Spawner* spawner, void* data, float dt);

// AI controller - oscillates on track, returns new x
float controller_ai_track(Spawner* spawner, void* data, float dt);
```

### Usage Example

```c
// Initialization
Spawner player_spawner = {
    .x = center_x, .y = spawn_y,
    .credits = 1.0f, .rate = SPAWN_RATE,
    .owner = OWNER_PLAYER, .gravity_dir = 1.0f,
    .color_dim = {60, 80, 80, 150}, .color_bright = {150, 255, 255, 220}
};

Spawner adversary_spawner = {
    .x = center_x, .y = adversary_spawn_y,
    .credits = 0.0f, .rate = SPAWN_RATE,  // Same rate now!
    .owner = OWNER_ADVERSARY, .gravity_dir = -1.0f,
    .color_dim = {80, 60, 60, 150}, .color_bright = {255, 150, 150, 220}
};

// Update loop
spawner_update(&player_spawner, controller_player_input, &input_data, dt);
spawner_update(&adversary_spawner, controller_ai_track, &track_data, dt);

// Add upgrade bonus to player only
player_spawner.credits = spawner_accumulate(
    player_spawner.credits, upgrade_bonus, dt, MAX_SPAWN_CREDITS);

// Spawn attempts
spawner_try_spawn(&player_spawner, ball_manager, ball_radius);
spawner_try_spawn(&adversary_spawner, ball_manager, BALL_RADIUS);

// Render
spawner_render(&player_spawner);
spawner_render(&adversary_spawner);
```

## Implementation Steps

1. Create `src/040-spawner.h` with Spawner struct and function declarations
2. Create `src/041-spawner.c` with pure functions first, then effectful functions
3. Implement player controller function
4. Implement AI track controller function
5. Refactor main.c to use Spawner for player
6. Refactor to use Spawner for adversary (remove adversary.c spawning logic)
7. Consider: keep Adversary struct for AI state, or fold into controller data?
8. Remove duplicated code from ball_manager (spawn_credits moves to Spawner)
9. Test both spawners work identically except for control scheme
10. Verify upgrade bonuses still work for player only

## Files to Create

- `src/040-spawner.h` - Spawner struct and API
- `src/041-spawner.c` - Implementation

## Files to Modify

- `src/001-main.c` - Use Spawner for player, remove inline reticle code
- `src/012-adversary.h` - Remove spawn_credits, maybe keep for AI movement state
- `src/013-adversary.c` - Use Spawner, remove duplicated spawn logic
- `src/006-ball.h` - Remove spawn_credits from BallManager (or keep for backwards compat)
- `src/007-ball.c` - Remove ball_manager_update_cooldown or simplify

## Benefits of Functional Style

1. **Testability**: Pure functions can be unit tested without game state
2. **Composability**: Controllers can be swapped, combined, or parameterized
3. **Predictability**: Same inputs always produce same outputs
4. **Debugging**: Effectful functions are isolated and clearly marked
5. **Reusability**: Pure accumulate/blocking checks usable elsewhere

## Troubleshooting

### "Player spawns but adversary doesn't"
- Check gravity_dir is set correctly (-1.0 for adversary)
- Check owner field matches OWNER_ADVERSARY
- Verify controller is being called

### "Both use same spawn rate now but feel different"
- Track oscillation speed affects perceived rate
- Player can hold position, AI keeps moving
- This is expected - control scheme differs, not spawn rate

### "Upgrade bonuses not working"
- Ensure upgrade bonus is added to player_spawner.credits specifically
- Don't add to adversary_spawner

### "Reticle colors wrong"
- Check color_dim and color_bright are set per-spawner
- Verify render function uses spawner's colors

## Notes

- Adversary having same base spawn rate as player is fairer
- Difficulty can come from AI movement patterns, not spawn rate
- Future: could add more controller types (random, pattern-based, etc.)
- Future: could make upgrades affect both spawners for co-op mode
