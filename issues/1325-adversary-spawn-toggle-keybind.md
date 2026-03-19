# 1325 - Adversary Spawn Toggle Keybind

## Status: Open

## Parent Phase: Phase 13

## Problem

No way to pause adversary ball spawning during gameplay. This would be useful for:
- Testing player-side mechanics without adversary interference
- Observing how adversary credits accumulate over time
- Creating asymmetric gameplay scenarios

## Current Behavior

- Adversary spawns balls automatically when it has credits
- No way to disable this behavior at runtime
- Adversary always spends credits immediately

## Intended Behavior

- Keybind (suggested: `A`) toggles adversary spawning on/off
- When spawning is disabled:
  - Adversary still earns credits (from scoring, time, etc.)
  - Credits accumulate instead of being spent
  - Visual indicator shows spawning is paused
- When spawning is re-enabled:
  - Adversary resumes spawning with accumulated credits
  - May spawn rapidly to "catch up" or resume normal rate

## Implementation

### Adversary State

```c
// In Adversary struct (src/012-adversary.h)
typedef struct Adversary {
    // ... existing fields ...
    int spawning_enabled;  // 1 = spawning, 0 = paused (accumulating credits)
} Adversary;

// Initialize to enabled
adversary->spawning_enabled = 1;
```

### Keybind Handler

```c
// In main game loop (src/001-main.c)
if (IsKeyPressed(KEY_A)) {
    adversary->spawning_enabled = !adversary->spawning_enabled;
    printf("Adversary spawning: %s\n",
           adversary->spawning_enabled ? "ENABLED" : "PAUSED");
}
```

### Spawn Logic Modification

```c
// In adversary_update or wherever spawning occurs
void adversary_update(Adversary* adversary, float dt) {
    // Credit accumulation happens regardless of spawning state
    adversary_accumulate_credits(adversary, dt);

    // Only spawn if enabled
    if (!adversary->spawning_enabled) {
        return;  // Skip spawning, keep credits
    }

    // Existing spawn logic...
    if (adversary->credits >= SPAWN_COST) {
        adversary_spawn_ball(adversary);
        adversary->credits -= SPAWN_COST;
    }
}
```

### Visual Indicator

```c
// In UI rendering
if (!adversary->spawning_enabled) {
    // Draw paused indicator near adversary info
    DrawText("ADVERSARY PAUSED", screen_width - 180, 200, 16, YELLOW);

    // Or draw over adversary spawn area
    DrawText("[PAUSED]", adversary_spawn_x, adversary_spawn_y - 20, 14, YELLOW);
}
```

## Alternative Keybinds

| Key | Pros | Cons |
|-----|------|------|
| `A` | Mnemonic for "Adversary" | May conflict with future controls |
| `P` | Mnemonic for "Pause" | Could be confused with game pause |
| `F2` | Function key, less likely to conflict | Less discoverable |
| `Tab` | Easy to reach | Often used for UI switching |

## Config Option

Could also add to config.txt for default state:

```
# Adversary settings
ADVERSARY_SPAWN_ENABLED=1
```

## Files to Modify

- `src/012-adversary.h` - Add spawning_enabled field
- `src/013-adversary.c` - Check flag before spawning
- `src/001-main.c` - Add keybind handler, render indicator

## Testing Checklist

- [ ] `A` key toggles adversary spawning
- [ ] Credits accumulate when paused
- [ ] Credits display updates while paused
- [ ] Spawning resumes correctly when re-enabled
- [ ] Visual indicator shows paused state
- [ ] State persists correctly (no reset on other actions)

## Notes

- Consider: Should accumulated credits have a cap?
- Consider: Audio feedback when toggling?
- Consider: Should this be available in all game modes or just debug/sandbox?
