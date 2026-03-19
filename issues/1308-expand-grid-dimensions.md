# 1308 - Expand Grid Dimensions

## Status: Re-opened

## Parent Phase: Phase 13

## Problem

Current board size (12 columns x 20 rows) feels cramped. Need to expand to 14 columns x 22 rows with a denser grid while keeping the same pixel dimensions.

## Current Behavior (after partial implementation)

- Default board: 14x22 grid with 50px cells = 700x1100 pixels
- Other boards in `boards/`: Still 12x20 grid with 50px cells = 600x1000 pixels
- Inconsistent dimensions between boards
- SLOT_BOARD_HEIGHT updated to 1100 (incorrect for 600x1000 target)

## Intended Behavior

- **All boards**: 14 columns x 22 rows
- **Same pixel dimensions**: 600 x 1000 pixels (unchanged from original)
- **Smaller cell size**: ~43px cells (denser grid, more pegs fit)
- All existing boards updated to match

### Cell Size Calculation

To fit 14x22 in 600x1000 pixels:
- Width: 600 / 14 = 42.86px per cell
- Height: 1000 / 22 = 45.45px per cell

Options:
1. Use 43px cells: 14×43=602px, 22×43=946px (close to target)
2. Use non-square cells: 43px wide, 45px tall (exact 602x990)
3. Use 42px cells: 14×42=588px, 22×42=924px (smaller than target)

Recommendation: Use 43px cells with slight board adjustment, or accept 42px for cleaner math.

## Remaining Work

### 1. Revert Pixel Dimension Changes
- `src/038-slot-manager.h`: SLOT_BOARD_HEIGHT back to 1000
- `scripts/compile`: Default board back to 600x1000 pixels

### 2. Update Cell Size
- `src/022-grid.h`: DEFAULT_GRID_CELL_SIZE from 50 → 43 (or 42)
- Update all board JSON files with new cell_size

### 3. Update All Existing Boards
- `boards/*.json`: Update grid dimensions to 14x22
- `boards/*.json`: Update cell_size to 43 (or 42)
- `boards/*.json`: Remap peg/line positions for new grid
- `scripts/compile`: Update default board generator

### 4. Adjust Physics Constants
- Ball radius may need scaling if cells are smaller
- Peg radius may need adjustment
- Spawn positions may need tweaking

## Files to Modify

- `src/022-grid.h` - Cell size constant
- `src/038-slot-manager.h` - Revert SLOT_BOARD_HEIGHT to 1000
- `scripts/compile` - Default board with correct dimensions
- `boards/*.json` - All existing board files
- Possibly `src/006-ball.h` - Ball/peg radius if needed

## Notes

- Denser grid = more level design options in same space
- Smaller cells may require smaller ball/peg radii
- All boards must use same dimensions for consistent gameplay
- Physics tuning may be needed after cell size change
