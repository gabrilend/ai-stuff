# 711 - Expand Grid Dimensions

## Status: Complete

## Parent Phase: See phase progress file

## Problem

Current board size (12 columns x 20 rows) feels cramped. Need to expand to 14 columns x 22 rows with a denser grid while keeping similar pixel dimensions.

## Solution Implemented

Used 43px cells with 14x22 grid = 602x946 pixels (close to original 600x1000).

### Changes Made

1. **src/022-grid.h**: DEFAULT_GRID_CELL_SIZE changed from 50.0f to 43.0f
2. **src/038-slot-manager.h**: SLOT_BOARD_HEIGHT changed from 1100.0f to 946.0f (22 × 43)
3. **scripts/compile**: Default board generator updated to 602x946 with 43px cells
4. **boards/stage1-default.json**: Updated to 14x22 grid with 43px cells, 602x946 pixels
5. **boards/in-and-out.json**: Updated to 14x22 grid with 43px cells, 602x946 pixels
6. **boards/stage1-variant.json**: Updated to 14x22 grid with 43px cells, 602x946 pixels
7. **boards/stage1-variant-2.json**: Updated to 14x22 grid with 43px cells, 602x946 pixels

### Position Remapping

For boards that had 12x20 layouts:
- Edge references (col 12, row 20) updated to (col 14, row 22)
- Score zones moved from row 19 to row 21 (new bottom row)
- Line endpoints using edge positions updated accordingly

## Cell Size Calculation

To fit 14x22 in approximately 600x1000 pixels with square cells:
- 43px cells: 14×43=602px width, 22×43=946px height
- Slightly smaller than original 600x1000 but maintains square cells
- Denser grid provides more level design flexibility

## Notes

- Physics constants (ball radius, peg radius) were not adjusted
- Gameplay may feel slightly different due to denser peg spacing
- All boards now consistent at 14x22 grid
- Future physics tuning may be beneficial
