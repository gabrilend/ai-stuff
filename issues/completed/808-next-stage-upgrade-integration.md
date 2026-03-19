# 1008 - Next Stage Upgrade Menu Integration

## Current Behavior

The upgrade menu (opened with Tab key) shows two upgrades:
- Spawn Rate: +0.0166 ball/sec per level (500 levels)
- Ball Size: -0.01 radius per level (300 levels)

Upgrades are purchased with points and have scaling costs.

```c
// src/010-upgrades.h
typedef enum UpgradeType {
    UPGRADE_SPAWN_RATE,
    UPGRADE_BALL_SIZE,
    UPGRADE_COUNT
} UpgradeType;
```

## Intended Behavior

Add a "Next Stage" upgrade that expands the board when purchased:

**Upgrade properties:**
- Name: "Next Stage"
- Description: "Unlock stage 2 (ramps)"
- Cost: High one-time cost (e.g., 10,000 points)
- Max level: 1 (single purchase, though future stages could add more levels)
- Effect: Triggers stage expansion animation and adds stage 2

**Menu display:**
- Shows alongside other upgrades
- Grayed out / hidden if already purchased
- Special visual treatment (different color, icon) to indicate major upgrade

**Future extensibility:**
- Level 1 unlocks stage 2 (ramps)
- Level 2 could unlock stage 3 (different obstacle type)
- etc.

## Suggested Implementation Steps

### Step 1: Add upgrade type

```c
// src/010-upgrades.h
typedef enum UpgradeType {
    UPGRADE_SPAWN_RATE,
    UPGRADE_BALL_SIZE,
    UPGRADE_NEXT_STAGE,  // NEW
    UPGRADE_COUNT
} UpgradeType;
```

### Step 2: Initialize stage upgrade

```c
// src/011-upgrades.c - in upgrade_manager_create()

// Initialize next stage upgrade (1 level per stage)
manager->upgrades[UPGRADE_NEXT_STAGE].name = "Next Stage";
manager->upgrades[UPGRADE_NEXT_STAGE].description = "Unlock ramp stage";
manager->upgrades[UPGRADE_NEXT_STAGE].base_cost = 10000;
manager->upgrades[UPGRADE_NEXT_STAGE].level = 0;
manager->upgrades[UPGRADE_NEXT_STAGE].max_level = 1;  // Stage 2 only for now
```

### Step 3: Special cost scaling (no scaling)

Stage upgrades have fixed costs rather than exponential scaling:

```c
int upgrade_get_cost(UpgradeManager* manager, UpgradeType type) {
    Upgrade* upgrade = &manager->upgrades[type];

    if (type == UPGRADE_NEXT_STAGE) {
        // Fixed costs per stage
        int stage_costs[] = { 10000, 50000, 200000 };  // Future stages
        if (upgrade->level < 3) {
            return stage_costs[upgrade->level];
        }
        return 999999;  // Max stages reached
    }

    // Normal exponential scaling for other upgrades
    return upgrade->base_cost * (upgrade->level + 1);
}
```

### Step 4: Handle purchase with callback

```c
// Need to signal main loop to trigger animation
typedef void (*StagePurchaseCallback)(void* user_data);

typedef struct UpgradeManager {
    // ... existing fields
    StagePurchaseCallback on_stage_purchase;
    void* callback_user_data;
} UpgradeManager;

int upgrade_purchase(UpgradeManager* manager, UpgradeType type, int* score) {
    // ... existing purchase logic

    if (type == UPGRADE_NEXT_STAGE && success) {
        // Trigger callback to start animation
        if (manager->on_stage_purchase) {
            manager->on_stage_purchase(manager->callback_user_data);
        }
    }

    return success;
}
```

### Step 5: Connect to main loop

```c
// src/001-main.c

void on_stage_purchased(void* user_data) {
    GameState* state = (GameState*)user_data;

    // Start expansion animation
    stage_manager_purchase_stage(state->world->stages, &state->expansion_anim);
}

// In initialization
upgrade_manager->on_stage_purchase = on_stage_purchased;
upgrade_manager->callback_user_data = &game_state;
```

### Step 6: Menu rendering for stage upgrade

```c
void upgrade_render_item(Upgrade* upgrade, UpgradeType type,
                         int x, int y, int selected, int affordable) {
    Color bg_color = selected ? DARKGRAY : BLACK;
    Color text_color = affordable ? WHITE : GRAY;

    // Special treatment for stage upgrade
    if (type == UPGRADE_NEXT_STAGE) {
        if (upgrade->level >= upgrade->max_level) {
            // Already purchased - show as complete
            bg_color = DARKGREEN;
            DrawText("UNLOCKED", x, y, 20, GREEN);
        } else {
            // Available - highlight as special
            bg_color = selected ? DARKBLUE : DARKPURPLE;
            // Draw with star/icon to indicate major upgrade
        }
    }

    // ... rest of rendering
}
```

### Step 7: Prevent purchase during animation

```c
int upgrade_manager_handle_input(UpgradeManager* manager, int* score,
                                 int animation_active) {
    if (animation_active) {
        // Don't allow purchases during expansion animation
        return 0;
    }

    // ... existing input handling
}
```

## Files to Modify

- `src/010-upgrades.h` - Add UPGRADE_NEXT_STAGE enum, callback typedef
- `src/011-upgrades.c` - Stage upgrade initialization, special cost logic, rendering
- `src/001-main.c` - Connect callback, check animation state

## Dependencies

- Issue 1002 (Stage system architecture)
- Issue 1007 (Stage insertion animation)

## Testing

1. Stage upgrade appears in menu
2. Cost displayed correctly (10,000 points)
3. Can purchase when affordable
4. Animation triggers on purchase
5. Upgrade shows as "UNLOCKED" after purchase
6. Cannot purchase again (max level 1)
7. Menu blocks further purchases during animation
8. Score deducted correctly

## Future Considerations

When adding more stages:
- Increment max_level
- Add stage-specific descriptions ("Unlock spinner stage", etc.)
- Update cost array with new stage prices
- Each purchase triggers appropriate stage type creation
