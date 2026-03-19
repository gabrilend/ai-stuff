// src/034-object-render.h
// Standalone rendering functions for board objects
// No game dependencies - can be used by both game and editor
//
// External functions: render_peg, render_line, render_portal_zone,
//                     render_grid, render_grid_cursor

#ifndef OBJECT_RENDER_H
#define OBJECT_RENDER_H

#include "raylib.h"
#include "020-board-data.h"
#include "022-grid.h"

// =============================================================================
// Color Constants
// =============================================================================

#define PEG_DEFAULT_COLOR (Color){178, 128, 50, 255}
#define PEG_OUTLINE_COLOR (Color){100, 100, 120, 255}
#define LINE_DEFAULT_COLOR (Color){140, 140, 160, 255}
#define LINE_OUTLINE_COLOR (Color){80, 80, 100, 255}
#define PORTAL_ENTRY_COLOR (Color){50, 150, 255, 200}
#define PORTAL_EXIT_COLOR (Color){255, 150, 50, 200}
#define GRID_LINE_COLOR (Color){60, 60, 80, 100}
#define GRID_MAJOR_COLOR (Color){80, 80, 100, 150}

// =============================================================================
// Object Rendering
// =============================================================================

// {{{ render_peg
// Renders a peg at pixel coordinates with RGB physics color.
void render_peg(float x, float y, float radius, Color color);
// }}}

// {{{ render_peg_preview
// Renders a semi-transparent peg preview (for cursor).
void render_peg_preview(float x, float y, float radius);
// }}}

// {{{ render_line
// Renders a line with rounded endpoints.
void render_line(float x1, float y1, float x2, float y2,
                 float thickness, Color color);
// }}}

// {{{ render_line_preview
// Renders a semi-transparent line preview.
void render_line_preview(float x1, float y1, float x2, float y2,
                         float thickness);
// }}}

// {{{ render_portal_zone
// Renders a portal zone with direction indicator and channel number.
void render_portal_zone(float x, float y, float width, float height,
                        PortalDirection direction, int channel);
// }}}

// {{{ render_portal_preview
// Renders a semi-transparent portal preview.
void render_portal_preview(float x, float y, float width, float height,
                           PortalDirection direction, int channel);
// }}}

// {{{ render_rotor
// Renders a rotor pivot point at pixel coordinates. (issue 901b)
// Draws a gear-shaped marker to distinguish from regular pegs.
// Direction indicator shows CW (clockwise) or CCW rotation.
void render_rotor(float x, float y, float radius, float current_angle, int cw);
// }}}

// {{{ render_rotor_preview
// Renders a semi-transparent rotor preview (for cursor).
void render_rotor_preview(float x, float y, float radius);
// }}}

// =============================================================================
// Grid Rendering
// =============================================================================

// {{{ render_grid
// Renders a grid overlay with major lines every 5 cells.
void render_grid(Grid* grid, float canvas_x, float canvas_y,
                 float canvas_width, float canvas_height);
// }}}

// {{{ render_grid_cursor
// Renders a highlight at the specified grid cell.
void render_grid_cursor(Grid* grid, int col, int row, Color color);
// }}}

// =============================================================================
// BoardData Rendering
// =============================================================================

// {{{ render_board_objects
// Renders all objects in a BoardData using the given grid.
void render_board_objects(BoardData* board, Grid* grid);
// }}}

// {{{ render_board_zones
// Renders all zones in a BoardData using the given grid.
void render_board_zones(BoardData* board, Grid* grid);
// }}}

// {{{ render_board_rotors
// Renders all rotors in a BoardData using the given grid. (issue 901b)
// Rotors appear as gear-shaped markers with rotation indicators.
void render_board_rotors(BoardData* board, Grid* grid);
// }}}

#endif // OBJECT_RENDER_H
