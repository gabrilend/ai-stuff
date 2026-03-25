// src/028-portal.h
// Portal zone system for ball teleportation
// Portals link entry and exit points via channel IDs

#ifndef PORTAL_H
#define PORTAL_H

#include "020-board-data.h"

// Forward declaration
struct Ball;
struct Grid;

// =============================================================================
// Constants
// =============================================================================

#define MAX_PORTAL_CHANNELS 16
#define MAX_PORTALS_PER_CHANNEL 8
#define PORTAL_COOLDOWN_FRAMES 10  // Frames until ball can teleport again (~0.16s at 60fps)

// =============================================================================
// Portal Structures
// =============================================================================

// {{{ typedef struct Portal
// Runtime portal instance with pixel coordinates
typedef struct Portal {
    float x, y;              // Center position (pixels)
    float width, height;     // Size (pixels)
    PortalDirection type;    // PORTAL_ENTRY or PORTAL_EXIT
    int channel;             // Channel ID for linking
} Portal;
// }}}

// {{{ typedef struct PortalChannel
// Groups entry and exit portals by channel
typedef struct PortalChannel {
    Portal entries[MAX_PORTALS_PER_CHANNEL];
    int entry_count;
    Portal exits[MAX_PORTALS_PER_CHANNEL];
    int exit_count;
} PortalChannel;
// }}}

// {{{ typedef struct PortalManager
// Manages all portals organized by channel
typedef struct PortalManager {
    PortalChannel channels[MAX_PORTAL_CHANNELS];
    int total_portals;  // Total count for statistics
} PortalManager;
// }}}

// =============================================================================
// Lifecycle
// =============================================================================

// {{{ portal_manager_create
// Creates an empty portal manager.
// Returns NULL on allocation failure.
PortalManager* portal_manager_create(void);
// }}}

// {{{ portal_manager_destroy
// Frees portal manager resources.
void portal_manager_destroy(PortalManager* manager);
// }}}

// {{{ portal_manager_clear
// Removes all portals from the manager.
void portal_manager_clear(PortalManager* manager);
// }}}

// =============================================================================
// Portal Registration
// =============================================================================

// {{{ portal_manager_add
// Adds a portal to the manager.
// Parameters:
//   manager: PortalManager instance
//   channel: Channel ID (0 to MAX_PORTAL_CHANNELS-1)
//   type: PORTAL_ENTRY or PORTAL_EXIT
//   x, y: Center position in pixels
//   width, height: Portal size in pixels
// Returns: 1 on success, 0 if channel/capacity exceeded
int portal_manager_add(PortalManager* manager, int channel, PortalDirection type,
                       float x, float y, float width, float height);
// }}}

// {{{ portal_manager_load_from_board
// Loads portal zones from board data.
// Converts grid coordinates to pixel positions.
// Parameters:
//   manager: PortalManager instance
//   data: BoardData containing portal zones
//   grid: Grid for coordinate conversion
void portal_manager_load_from_board(PortalManager* manager, BoardData* data,
                                    struct Grid* grid);
// }}}

// =============================================================================
// Ball Interaction
// =============================================================================

// {{{ portal_manager_check_ball
// Checks if a ball is inside an entry portal and should teleport.
// Parameters:
//   manager: PortalManager instance
//   ball: Ball to check (reads x, y, portal_cooldown)
//   out_x, out_y: Output teleport destination (if returns 1)
// Returns: 1 if ball should teleport, 0 otherwise
int portal_manager_check_ball(PortalManager* manager, struct Ball* ball,
                              float* out_x, float* out_y);
// }}}

// =============================================================================
// Rendering
// =============================================================================

// {{{ portal_manager_render
// Renders all portals.
// Entry portals are blue, exit portals are orange.
// Parameters:
//   manager: PortalManager instance
void portal_manager_render(PortalManager* manager);
// }}}

#endif // PORTAL_H
