# 1001a - Player Ball Spawn Failure

## Status: Closed (Not a Bug)

## Resolution
Player spawning works correctly. User must press SPACE to spawn balls or press A to enable auto-spawn. Initial report was due to forgetting to provide input during testing.

## Parent Issue: 1001 - Sprint Remediation

## Current Behavior

Player balls do not spawn when pressing SPACE, but adversary balls spawn correctly. The player reticle is visible and the spawn credit ring animates, suggesting credits are accumulating but spawning is blocked.

## Intended Behavior

Player balls should spawn at the reticle position when:
- SPACE is pressed (manual spawn)
- Auto-spawn is enabled

## Investigation Areas

### 1. Spawner Blocking Check

In `src/041-spawner.c:25-46`, `spawner_is_blocked()` checks if same-owner balls are within spawn radius:

```c
if (owner_filter >= 0 && ball->owner != owner_filter) continue;
```

**Potential Issue**: Logic may be inverted - should skip balls that DON'T match owner, currently skips balls that DO match.

### 2. Spawner Position

Player spawner position set in `main.c:866-882`:
- Y position from `slot_manager_get_player_spawn_y(slot_manager)`
- X position from `world->table_x + world->table_width / 2.0f`

**Potential Issue**: If slot manager calculations are wrong, spawn Y could be outside valid world bounds.

### 3. Capacity Check

`spawner_try_spawn()` at line 160-161 checks:
```c
if (manager->active_count >= manager->capacity) return 0;
```

**Potential Issue**: If `active_count` isn't being decremented when balls die, capacity could appear full.

## Debugging Steps

1. Add printf to `spawner_try_spawn()` showing which condition fails
2. Print spawner position and compare to world bounds
3. Print `ball_manager->active_count` vs `capacity`
4. Print result of `spawner_is_blocked()`

## Files to Modify

- `src/041-spawner.c` - Add debug logging, fix blocking logic if needed
- `src/001-main.c` - Verify spawner initialization values

## Related Issues

- Issue 1309: Spawner unification (introduced current spawner system)
