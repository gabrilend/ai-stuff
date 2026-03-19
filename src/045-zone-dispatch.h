// src/045-zone-dispatch.h
// Grid-based zone dispatch system for unified zone handling
// Provides fast lookup and function pointer dispatch for zone effects
//
// Issue 318: Replaces fragmented zone checking with unified grid-based dispatch.
// Zones are mapped to grid cells for O(1) lookup with no branching in hot path.
//
// External functions: zone_grid_create, zone_grid_destroy, zone_grid_init,
//                     zone_grid_set_gate_row, zone_grid_set_wrap_zones,
//                     zone_dispatch, zone_grid_expand

#ifndef ZONE_DISPATCH_H
#define ZONE_DISPATCH_H

#include <stdint.h>
#include "022-grid.h"

// Forward declarations
typedef struct Ball Ball;
typedef struct World World;

// =============================================================================
// Dispatch Zone Type Enumeration
// =============================================================================

// {{{ DispatchZoneType enum
// Zone types for dispatch table lookup (issue 318).
// Renamed from ZoneType to avoid conflict with board-data.h ZoneType.
// DISPATCH_ZONE_BACKGROUND is default (value 0) - resets has_scored, continues physics.
// Gate zones encode point values for fast dispatch without extra lookup.
typedef enum DispatchZoneType {
    DISPATCH_ZONE_BACKGROUND = 0,   // Default - resets has_scored, normal physics

    // Gate zones (points encoded in type for fast dispatch)
    DISPATCH_ZONE_GATE_10,
    DISPATCH_ZONE_GATE_20,
    DISPATCH_ZONE_GATE_50,
    DISPATCH_ZONE_GATE_100,
    DISPATCH_ZONE_GATE_200,
    DISPATCH_ZONE_GATE_500,

    // Wrap zones (ball teleportation)
    DISPATCH_ZONE_WRAP_TO_BOTTOM,   // Ball at top -> teleport to bottom
    DISPATCH_ZONE_WRAP_TO_TOP,      // Ball at bottom -> teleport to top

    // Boundary zones (wall reflection)
    DISPATCH_ZONE_WALL_LEFT,        // Reflect off left edge
    DISPATCH_ZONE_WALL_RIGHT,       // Reflect off right edge

    // Future zones (placeholder - will be implemented in Phase 9)
    DISPATCH_ZONE_PORTAL_ENTRY,
    DISPATCH_ZONE_PORTAL_EXIT,
    DISPATCH_ZONE_ROTOR_AREA,
    DISPATCH_ZONE_MOVER_AREA,

    DISPATCH_ZONE_TYPE_COUNT
} DispatchZoneType;
// }}}

// =============================================================================
// Zone Grid Constants
// =============================================================================

// Maximum grid size to accommodate stage expansion
// 100 rows supports ~4300 pixels of vertical space at 43px/cell
#define ZONE_GRID_MAX_ROWS 100
#define ZONE_GRID_MAX_COLS DEFAULT_GRID_COLS

// =============================================================================
// Zone Grid Structure
// =============================================================================

// {{{ typedef struct ZoneGrid
// Maps grid cells to zone types for fast dispatch.
// Uses fixed maximum size to avoid reallocation during expansion.
// Grid fits in L1 cache: 100x14 = 1400 bytes for cells + 1400 for multipliers.
typedef struct ZoneGrid {
    // Zone type per cell (indexed [row][col])
    uint8_t cells[ZONE_GRID_MAX_ROWS][ZONE_GRID_MAX_COLS];

    // Multiplier overlay for gate zones (0 = no multiplier, 1 = 2x, 2 = 3x, etc.)
    // Only checked when zone type is ZONE_GATE_*
    uint8_t multipliers[ZONE_GRID_MAX_ROWS][ZONE_GRID_MAX_COLS];

    // Grid parameters (for coordinate conversion)
    float origin_x;
    float origin_y;
    float cell_size;
    int cols;
    int rows;

    // Active row range (for expansion tracking)
    int active_row_start;  // First row with meaningful zones
    int active_row_end;    // Last row with meaningful zones + 1

    // World reference for wrap zone calculations
    World* world;
} ZoneGrid;
// }}}

// =============================================================================
// Zone Function Signature
// =============================================================================

// {{{ ZoneFunc typedef
// Zone handler function signature.
// Parameters:
//   ball: The ball entering/occupying this zone
//   grid: Zone grid for coordinate lookups and world reference
//   col, row: Grid cell coordinates
// Returns:
//   1 if ball should continue physics, 0 if handled specially (e.g., teleport)
typedef int (*ZoneFunc)(Ball* ball, ZoneGrid* grid, int col, int row);
// }}}

// =============================================================================
// Zone Grid Creation/Destruction
// =============================================================================

// {{{ zone_grid_create
// Allocates and initializes a zone grid.
// All cells start as ZONE_BACKGROUND.
// Parameters:
//   origin_x, origin_y: Grid origin in pixels
//   cell_size: Size of each cell in pixels
//   cols, rows: Grid dimensions (clamped to max)
//   world: World reference for wrap zone calculations
// Returns:
//   Allocated ZoneGrid, or NULL on failure
ZoneGrid* zone_grid_create(float origin_x, float origin_y, float cell_size,
                           int cols, int rows, World* world);
// }}}

// {{{ zone_grid_destroy
// Frees zone grid memory.
void zone_grid_destroy(ZoneGrid* grid);
// }}}

// =============================================================================
// Zone Grid Initialization
// =============================================================================

// {{{ zone_grid_init
// Reinitializes zone grid with all background zones.
// Preserves grid dimensions and origin.
void zone_grid_init(ZoneGrid* grid);
// }}}

// {{{ zone_grid_set_gate_row
// Sets a row of gate zones with standard point pattern.
// Pattern: 10, 20, 50, 100, 100, 200, 500, 500, 200, 100, 100, 50, 20, 10
// Parameters:
//   grid: Zone grid to modify
//   row: Row index to set
//   multiplier: Point multiplier (0 = 1x, 1 = 2x, 2 = 3x, etc.)
void zone_grid_set_gate_row(ZoneGrid* grid, int row, int multiplier);
// }}}

// {{{ zone_grid_set_wrap_zones
// Sets wrap zones at specified rows.
// Top row becomes ZONE_WRAP_TO_BOTTOM, bottom row becomes ZONE_WRAP_TO_TOP.
// Parameters:
//   grid: Zone grid to modify
//   top_row: Row for top wrap zone (-1 to skip)
//   bottom_row: Row for bottom wrap zone (-1 to skip)
void zone_grid_set_wrap_zones(ZoneGrid* grid, int top_row, int bottom_row);
// }}}

// {{{ zone_grid_set_walls
// Sets wall zones on left and right edges for specified row range.
// Parameters:
//   grid: Zone grid to modify
//   start_row: First row with walls
//   end_row: Last row with walls (exclusive)
void zone_grid_set_walls(ZoneGrid* grid, int start_row, int end_row);
// }}}

// =============================================================================
// Zone Dispatch
// =============================================================================

// {{{ zone_dispatch
// Dispatches ball to appropriate zone handler based on position.
// Converts ball position to grid cell, looks up zone type, calls handler.
// No branching in hot path - just array lookup and indirect call.
// Parameters:
//   ball: Ball to check
//   grid: Zone grid for lookup and dispatch
// Returns:
//   1 if ball should continue physics, 0 if handled specially
int zone_dispatch(Ball* ball, ZoneGrid* grid);
// }}}

// =============================================================================
// Zone Grid Expansion
// =============================================================================

// {{{ zone_grid_expand_down
// Expands the active zone area downward for new stages.
// Shifts existing zone content and adds new rows.
// Parameters:
//   grid: Zone grid to expand
//   new_rows: Number of rows to add
void zone_grid_expand_down(ZoneGrid* grid, int new_rows);
// }}}

// {{{ zone_grid_shift_content
// Shifts all zone content down by specified rows.
// Used during world expansion to make room for new content.
// Parameters:
//   grid: Zone grid to modify
//   shift_rows: Number of rows to shift down
void zone_grid_shift_content(ZoneGrid* grid, int shift_rows);
// }}}

// =============================================================================
// Zone Grid Query
// =============================================================================

// {{{ zone_grid_get_type
// Returns the zone type at a specific cell.
// Returns DISPATCH_ZONE_BACKGROUND if out of bounds.
DispatchZoneType zone_grid_get_type(ZoneGrid* grid, int col, int row);
// }}}

// {{{ zone_grid_get_multiplier
// Returns the multiplier at a specific cell.
// Returns 0 if out of bounds or not a gate zone.
int zone_grid_get_multiplier(ZoneGrid* grid, int col, int row);
// }}}

// {{{ zone_grid_get_points_for_type
// Returns the base point value for a gate zone type.
// Returns 0 for non-gate zones.
int zone_grid_get_points_for_type(DispatchZoneType type);
// }}}

// =============================================================================
// Debug Rendering
// =============================================================================

// {{{ zone_grid_render_debug
// Renders zone grid as colored overlay for debugging.
// Different colors for different zone types.
void zone_grid_render_debug(ZoneGrid* grid);
// }}}

#endif // ZONE_DISPATCH_H
