// src/036-wrap-zones.h
// Dynamic wrap zones for ball teleportation at screen edges
// Zones reposition automatically on window resize and stage expansion
//
// External functions: wrap_zones_create, wrap_zones_destroy, wrap_zones_update,
//                     wrap_zones_check_ball, wrap_zones_render_debug

#ifndef WRAP_ZONES_H
#define WRAP_ZONES_H

#include "004-world.h"
#include "006-ball.h"

// {{{ typedef struct WrapZones
// Dynamic wrap zones that track viewable area edges
// Top zone: receives adversary balls, sends player balls
// Bottom zone: receives player balls, sends adversary balls
typedef struct WrapZones {
    // Zone Y positions (top edge of each zone rectangle)
    float top_zone_y;
    float bottom_zone_y;

    // Zone dimensions
    float zone_height;
    float zone_width;
    float zone_x;  // Left edge (matches table_x)

    // Screen height for viewable area calculation
    float screen_height;

    // World reference for dynamic bounds
    World* world;

    // Debug visualization toggle
    int debug_visible;
} WrapZones;
// }}}

// {{{ wrap_zones_create
// Creates wrap zones system attached to world
// screen_height: Current window height for viewable area calculation
WrapZones* wrap_zones_create(World* world, float screen_height);
// }}}

// {{{ wrap_zones_destroy
// Frees wrap zones memory
void wrap_zones_destroy(WrapZones* zones);
// }}}

// {{{ wrap_zones_update
// Recalculates zone positions based on current world bounds and screen size
// Call on: window resize, stage expansion, game reset
void wrap_zones_update(WrapZones* zones, float screen_height);
// }}}

// {{{ wrap_zones_check_ball
// Checks if ball is in a wrap zone and teleports if so
// Returns: 1 if ball was wrapped, 0 otherwise
int wrap_zones_check_ball(WrapZones* zones, Ball* ball);
// }}}

// {{{ wrap_zones_render_debug
// Renders semi-transparent debug visualization of wrap zones
// Top zone: blue, Bottom zone: red
void wrap_zones_render_debug(WrapZones* zones);
// }}}

// {{{ wrap_zones_toggle_debug
// Toggles debug visualization on/off
void wrap_zones_toggle_debug(WrapZones* zones);
// }}}

#endif // WRAP_ZONES_H
