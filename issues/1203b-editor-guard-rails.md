# 1203b - Editor Guard Rails Not Visible

## Current Behavior

The editable area is implied by grid bounds but guard rails aren't drawn. The playable area boundaries are not visually distinct.

## Intended Behavior

Draw visible guard rails (vertical lines) on left and right edges of the playable area to match the game's appearance. This helps users understand the actual play boundaries.

## Suggested Implementation Steps

1. In `render_canvas()`, add rail rendering after grid but before objects
2. Use world rail styling (or similar visual treatment)
3. Draw two vertical lines at `grid.origin_x` and `grid.origin_x + grid.width`
4. Extend rails from top to bottom of canvas

## Files to Modify

- `src/032-editor-app.c` - `render_canvas()` function

## Testing

1. Run editor: `./edit`
2. Verify vertical lines visible on left and right edges
3. Lines should span full height of grid area

## Related Issues

- 1203-editor-improvements.md (parent issue)
