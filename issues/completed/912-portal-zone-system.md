# 1112 - Portal Zone System

## Current Behavior

Zones only exist as scoring gates at the bottom of each stage. There's no mechanism for teleporting balls between locations.

## Intended Behavior

Create portal zones that teleport balls from entry points to exit points:

1. Portals have a **channel ID** (integer, e.g., 1, 2, 3)
2. Portals are marked as **entry** or **exit**
3. Ball entering an entry portal teleports to a random exit portal with same channel
4. Ball entering an exit portal does nothing (pass-through)
5. Ball state fully preserved (position changes, everything else stays)

## Suggested Implementation Steps

### Step 1: Define portal zone structure

```c
// src/020-board-data.h

typedef enum PortalType {
    PORTAL_ENTRY,
    PORTAL_EXIT
} PortalType;

typedef struct BoardZone {
    int type;              // ZONE_SCORE, ZONE_PORTAL
    int col, row;          // Grid position (top-left)
    int width, height;     // Size in grid cells

    // For score zones
    int points;
    int multiplier;

    // For portal zones
    int channel;           // Channel ID (portals with same channel are linked)
    PortalType portal_type; // PORTAL_ENTRY or PORTAL_EXIT
} BoardZone;
```

### Step 2: Define runtime portal manager

```c
// src/028-portal.h

#define MAX_CHANNELS 16
#define MAX_PORTALS_PER_CHANNEL 8

typedef struct Portal {
    float x, y;            // Center position (pixels)
    float width, height;   // Size (pixels)
    PortalType type;       // Entry or exit
    int channel;
} Portal;

typedef struct PortalChannel {
    Portal entries[MAX_PORTALS_PER_CHANNEL];
    int entry_count;
    Portal exits[MAX_PORTALS_PER_CHANNEL];
    int exit_count;
} PortalChannel;

typedef struct PortalManager {
    PortalChannel channels[MAX_CHANNELS];
} PortalManager;
```

### Step 3: Implement portal registration

```c
// src/029-portal.c

PortalManager* portal_manager_create(void) {
    PortalManager* manager = calloc(1, sizeof(PortalManager));
    return manager;
}

void portal_manager_add(PortalManager* manager, int channel, PortalType type,
                        float x, float y, float width, float height) {
    if (channel < 0 || channel >= MAX_CHANNELS) {
        fprintf(stderr, "ERROR: Invalid portal channel: %d\n", channel);
        return;
    }

    PortalChannel* ch = &manager->channels[channel];
    Portal portal = { x, y, width, height, type, channel };

    if (type == PORTAL_ENTRY) {
        if (ch->entry_count < MAX_PORTALS_PER_CHANNEL) {
            ch->entries[ch->entry_count++] = portal;
        }
    } else {
        if (ch->exit_count < MAX_PORTALS_PER_CHANNEL) {
            ch->exits[ch->exit_count++] = portal;
        }
    }
}
```

### Step 4: Implement ball-portal collision check

```c
int portal_check_ball(PortalManager* manager, Ball* ball,
                      float* out_x, float* out_y) {
    // Check all entry portals
    for (int ch = 0; ch < MAX_CHANNELS; ch++) {
        PortalChannel* channel = &manager->channels[ch];

        for (int i = 0; i < channel->entry_count; i++) {
            Portal* entry = &channel->entries[i];

            // Check if ball center is inside entry portal
            if (ball->x >= entry->x - entry->width / 2 &&
                ball->x <= entry->x + entry->width / 2 &&
                ball->y >= entry->y - entry->height / 2 &&
                ball->y <= entry->y + entry->height / 2) {

                // Found entry - select random exit
                if (channel->exit_count > 0) {
                    int exit_idx = rand() % channel->exit_count;
                    Portal* exit = &channel->exits[exit_idx];

                    *out_x = exit->x;
                    *out_y = exit->y;

                    printf("Portal: channel %d, teleporting to exit %d\n",
                           ch, exit_idx);
                    return 1;
                } else {
                    printf("Portal: channel %d has no exits!\n", ch);
                }
            }
        }
    }

    return 0;  // No teleport
}
```

### Step 5: Integrate with ball update

```c
// In ball physics update (src/007-ball.c)

void ball_check_portals(Ball* ball, PortalManager* portals) {
    float new_x, new_y;

    if (portal_check_ball(portals, ball, &new_x, &new_y)) {
        // Teleport ball - preserve everything except position
        ball->x = new_x;
        ball->y = new_y;

        // Velocity, health, owner, etc. all preserved automatically
        // (we only changed x and y)
    }
}
```

### Step 6: Implement portal rendering

```c
void portal_render(Portal* portal) {
    Color color;
    if (portal->type == PORTAL_ENTRY) {
        // Entry portals: blue with inward arrows
        color = (Color){50, 100, 255, 200};
    } else {
        // Exit portals: orange with outward arrows
        color = (Color){255, 150, 50, 200};
    }

    float x = portal->x - portal->width / 2;
    float y = portal->y - portal->height / 2;

    // Draw portal zone
    DrawRectangle((int)x, (int)y, (int)portal->width, (int)portal->height, color);
    DrawRectangleLines((int)x, (int)y, (int)portal->width, (int)portal->height, WHITE);

    // Draw channel number
    char ch_text[8];
    snprintf(ch_text, 8, "%d", portal->channel);
    DrawText(ch_text, (int)portal->x - 4, (int)portal->y - 8, 16, WHITE);

    // Draw direction indicator
    if (portal->type == PORTAL_ENTRY) {
        // Inward arrow (V shape)
        DrawTriangle(
            (Vector2){portal->x, portal->y + 10},
            (Vector2){portal->x - 8, portal->y - 5},
            (Vector2){portal->x + 8, portal->y - 5},
            WHITE
        );
    } else {
        // Outward arrow (^ shape)
        DrawTriangle(
            (Vector2){portal->x, portal->y - 10},
            (Vector2){portal->x - 8, portal->y + 5},
            (Vector2){portal->x + 8, portal->y + 5},
            WHITE
        );
    }
}

void portal_manager_render(PortalManager* manager) {
    for (int ch = 0; ch < MAX_CHANNELS; ch++) {
        PortalChannel* channel = &manager->channels[ch];

        for (int i = 0; i < channel->entry_count; i++) {
            portal_render(&channel->entries[i]);
        }
        for (int i = 0; i < channel->exit_count; i++) {
            portal_render(&channel->exits[i]);
        }
    }
}
```

### Step 7: Implement editor portal placement

```c
// In editor palette, add portal options
typedef enum EditorTool {
    TOOL_PEG,
    TOOL_LINE,
    TOOL_ZONE_GATE,
    TOOL_ZONE_PORTAL_ENTRY,
    TOOL_ZONE_PORTAL_EXIT,
    TOOL_COUNT
} EditorTool;

// When placing portal, prompt for channel
void editor_place_portal(EditorState* editor, PortalType type) {
    BoardZone zone = {
        .type = ZONE_PORTAL,
        .col = editor->hover_col,
        .row = editor->hover_row,
        .width = 1,
        .height = 1,
        .channel = editor->current_portal_channel,
        .portal_type = type
    };

    board_data_add_zone(editor->board_data, &zone);
}

// Cycle channel with number keys or scroll wheel
void editor_handle_channel_select(EditorState* editor) {
    if (IsKeyPressed(KEY_ONE)) editor->current_portal_channel = 1;
    if (IsKeyPressed(KEY_TWO)) editor->current_portal_channel = 2;
    if (IsKeyPressed(KEY_THREE)) editor->current_portal_channel = 3;
    // etc.

    // Or scroll wheel to increment/decrement
    int wheel = GetMouseWheelMove();
    if (wheel != 0) {
        editor->current_portal_channel += wheel;
        if (editor->current_portal_channel < 1) editor->current_portal_channel = 1;
        if (editor->current_portal_channel > MAX_CHANNELS) {
            editor->current_portal_channel = MAX_CHANNELS;
        }
    }
}
```

### Step 8: Prevent re-triggering

A ball that just exited a portal shouldn't immediately trigger another entry:

```c
typedef struct Ball {
    // ... existing fields ...
    int portal_cooldown_frames;  // Frames until portal can trigger again
} Ball;

int portal_check_ball(PortalManager* manager, Ball* ball, ...) {
    if (ball->portal_cooldown_frames > 0) {
        return 0;  // Still on cooldown
    }

    // ... normal check ...

    if (teleported) {
        ball->portal_cooldown_frames = 10;  // ~0.16 seconds at 60fps
    }
}

// In ball update:
if (ball->portal_cooldown_frames > 0) {
    ball->portal_cooldown_frames--;
}
```

## JSON Format

```json
{
  "zones": [
    {
      "type": "portal",
      "col": 2,
      "row": 5,
      "width": 1,
      "height": 1,
      "channel": 1,
      "direction": "entry"
    },
    {
      "type": "portal",
      "col": 10,
      "row": 8,
      "width": 1,
      "height": 1,
      "channel": 1,
      "direction": "exit"
    }
  ]
}
```

## Visual Design

```
Entry Portal (Blue)     Exit Portal (Orange)
+--------+              +--------+
|   1    |              |   1    |
|   V    |              |   ^    |
+--------+              +--------+
  inward                 outward
  arrow                   arrow
```

Portals with the same channel number are linked. Multiple exits allow randomized teleport destinations.

## Files to Create

- `src/028-portal.h` - Portal structures
- `src/029-portal.c` - Portal manager implementation

## Files to Modify

- `src/020-board-data.h` - Add portal zone type
- `src/006-ball.h` - Add portal cooldown field
- `src/007-ball.c` - Add portal check in update
- `src/025-editor.c` - Add portal placement tools

## Testing

1. Create two portals: entry (channel 1) at top, exit (channel 1) at bottom
2. Drop ball into entry - should teleport to exit
3. Verify velocity preserved (ball continues in same direction)
4. Verify health preserved
5. Create entry with no matching exit - ball should not teleport (with warning)
6. Create multiple exits for one channel - ball should randomly choose
7. Ball entering exit portal - nothing happens (pass-through)
8. Rapid re-entry test - cooldown prevents instant re-trigger

## Related Issues

- 1101-board-data-format.md (zone storage)
- 1106-object-placement.md (placement UI)

## Implementation Notes

### Files Created

1. **src/028-portal.h** - Portal structures and API
   - `Portal` struct for runtime portal instances
   - `PortalChannel` struct grouping entry/exit portals
   - `PortalManager` struct managing all portals
   - Functions: create, destroy, clear, add, load_from_board, check_ball, render

2. **src/029-portal.c** - Portal implementation
   - Portal registration and channel management
   - Ball-portal collision detection with cooldown
   - Portal rendering with direction indicators and channel numbers

### Files Modified

1. **src/006-ball.h** - Added `portal_cooldown` field to Ball struct

2. **src/007-ball.c**
   - Added portal.h include
   - Added portal_cooldown copy in ball_update_physics
   - Added portal checking and teleportation in ball_update_task

3. **src/004-world.h** - Added PortalManager forward declaration and `portals` field to World

4. **src/005-world.c**
   - Added portal.h include
   - Initialize portals to NULL in world_create
   - Destroy portals in world_destroy

5. **src/024-editor.h**
   - Added `EditorToolType` enum (EDITOR_TOOL_OBJECT, EDITOR_TOOL_ZONE_PORTAL)
   - Added portal tool state: tool_type, portal_direction, portal_channel

6. **src/025-editor.c**
   - Extended PaletteItem struct with tool_type, object_type, portal_dir
   - Added portal entry/exit to palette (keys 3 and 4)
   - Added scroll wheel channel selection when portal tool active
   - Updated palette rendering for portal icons
   - Added portal placement in editor_handle_placement
   - Added portal cursor preview in editor_render_cursor
   - Added portal syncing in editor_sync_to_world
   - Updated UI to show portal channel info

7. **src/001-main.c**
   - Added portal.h include
   - Added portal_manager_render call in rendering section

### Key Features

- Portal entry zones (blue) and exit zones (orange)
- Channel system links portals (1-16)
- Ball enters entry portal → teleports to random exit with same channel
- Cooldown prevents immediate re-entry (10 frames)
- Velocity and other ball state preserved on teleport
- Editor tools: keys 3/4 for entry/exit, scroll wheel for channel
- Visual feedback: direction arrows, channel numbers

## Status: Complete
