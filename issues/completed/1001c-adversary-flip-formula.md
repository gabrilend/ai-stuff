# 1001c - Adversary Board Vertical Flip Formula

## Status: Complete (Consolidated into Issue 602)

## Parent Issue: 1001 - Sprint Remediation

## Current Behavior

In `src/001-main.c:306-310`, adversary pegs use:
```c
int flipped_row = data->grid_rows - obj->row;
```

For a 22-row grid (rows 0-21):
- Row 0 becomes row 22 (beyond grid bounds)
- Row 21 becomes row 1
- Row 10 becomes row 12

This creates asymmetric board with objects at wrong positions.

## Intended Behavior

Proper vertical mirroring should map:
- Row 0 → Row 21 (top becomes bottom)
- Row 21 → Row 0 (bottom becomes top)
- Row 10 → Row 11 (center stays near center)

Formula should be: `flipped_row = data->grid_rows - 1 - obj->row`

## Affected Code

### Pegs (main.c:306-310)
```c
// Current:
int flipped_row = data->grid_rows - obj->row;

// Should be:
int flipped_row = data->grid_rows - 1 - obj->row;
```

### Lines (main.c:343-346)
```c
// Current:
int flipped_row1 = data->grid_rows - obj->row;
int flipped_row2 = data->grid_rows - obj->end_row;

// Should be:
int flipped_row1 = data->grid_rows - 1 - obj->row;
int flipped_row2 = data->grid_rows - 1 - obj->end_row;
```

### Stage Application (main.c:110, 135-136)
Similar flip logic in `apply_board_data_to_stage()`:
```c
// Current:
int row = flip_vertical ? (data->grid_rows - obj->row) : obj->row;

// Should be:
int row = flip_vertical ? (data->grid_rows - 1 - obj->row) : obj->row;
```

## Files Modified

- `src/001-main.c` - Fixed all 4 instances of vertical flip calculations:
  - Line 111: `apply_board_data_to_stage()` peg flipping
  - Line 137-138: `apply_board_data_to_stage()` line endpoint flipping
  - Line 311: `apply_adversary_board_data()` peg flipping
  - Line 349-350: `apply_adversary_board_data()` line endpoint flipping

## Testing

1. Load board with peg at row 0, col 7
2. Verify adversary board has peg at row 21 (bottom), col 7
3. Verify board is vertically symmetric across center line
