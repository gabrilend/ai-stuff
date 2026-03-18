# Issue 10-030: Image Source Position Randomization

## Status
- **Phase**: 10
- **Priority**: Low
- **Type**: Enhancement
- **Status**: Open
- **Created**: 2026-03-18

## Current Behavior

Images from each source directory appear in the chronological timeline in a deterministic order based on:
1. File modification time (from stat)
2. EXIF creation date (when available)
3. Filename sorting (fallback)

This means images from the same source always appear in the same relative positions, which can create predictable clustering of similar content (e.g., all screenshots from one day grouped together).

## Intended Behavior

Add a `randomize_order` config option to image source directories that shuffles the positions of images from that source within the timeline:

### Config Syntax

```lua
sources = {
    images = {
        enabled = true,
        directories = {
            {
                name = "things-I-almost-posted",
                path = "input/media_attachments/things-i-almost-posted",
                optional = true,
                -- NEW: Randomize this source's images in the timeline
                randomize_order = true,
                -- Optional: Seed for reproducible randomization
                random_seed = 42,
            },
            {
                name = "my-art",
                path = "input/media_attachments/my-art",
                -- Default: false (preserve original order)
                randomize_order = false,
            },
        },
    },
}
```

### Behavior Details

**When `randomize_order = true`:**
- Images from this source are assigned random timestamps within the timeline's date range
- Spreads images throughout the chronological view instead of clustering by source
- Useful for "things I almost posted" or miscellaneous images that don't have meaningful dates

**When `randomize_order = false` (default):**
- Images preserve their original chronological order based on file/EXIF dates
- Appropriate for art portfolios, sequential photo series, etc.

**Optional `random_seed`:**
- When provided, randomization is deterministic (same seed = same order)
- Useful for reproducible builds and testing
- When omitted, uses system random (different each run)

### Timeline Integration

The randomization should happen during the image cataloging stage (Stage 5) when `creation_date` is assigned:

```lua
-- Pseudocode for randomized timestamp assignment
if source.randomize_order then
    local rng = source.random_seed and create_seeded_rng(source.random_seed) or math.random
    local timeline_start = get_earliest_poem_date()
    local timeline_end = get_latest_poem_date()
    local range = timeline_end - timeline_start

    for _, image in ipairs(source_images) do
        image.creation_date = timeline_start + rng() * range
    end
end
```

## Suggested Implementation Steps

1. [ ] Add `randomize_order` field to sources schema documentation
2. [ ] Update `sources-loader.lua` to pass through randomization config
3. [ ] Modify `image-manager.lua` to check for randomization flag
4. [ ] Implement randomized timestamp assignment in cataloging stage
5. [ ] Add `random_seed` support for deterministic randomization
6. [ ] Update config.lua with example randomized source
7. [ ] Test with `--force-stage=5` to verify randomization works

## Files to Modify

| File | Changes |
|------|---------|
| `config.lua` | Add `randomize_order` examples to image sources |
| `libs/sources-loader.lua` | Pass through randomization config |
| `src/image-manager.lua` | Implement randomized timestamp assignment |

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Empty timeline (no poems yet) | Use current date range or skip randomization |
| Single image in source | Still randomize (assigns random position) |
| All sources randomized | Works fine, all images scattered |
| Mix of randomized and ordered | Ordered sources maintain position, randomized scatter around them |

## Related Documents

- Issue 10-026: Merge sources and external_files (established current config structure)
- `src/image-manager.lua`: Image cataloging implementation
- `libs/sources-loader.lua`: Config loading

## Open Questions

- Should randomization respect "buckets" (e.g., randomize within each month rather than across entire timeline)?
- Should there be a `randomize_weight` for probabilistic scattering (some images stay near original date)?

---

## Implementation Log

### Completed (2026-03-18)

**Files Modified:**
- `libs/sources-loader.lua` - Added `randomize_order` and `random_seed` fields to `get_directories()`
- `src/image-manager.lua` - Added randomization logic:
  - `create_seeded_rng()` - LCG-based deterministic random for reproducible builds
  - `apply_randomization()` - Applies random timestamps to images from randomized sources
  - Updated `load_config()` to return full directory objects
  - Updated `scan_directory_for_images()` to track source config per image
  - Updated `M.discover_images()` to apply randomization before final sort
- `config.lua` - Added `randomize_order = true` to user-selected sources

**Implementation Details:**
- Randomization happens after all images are collected but before the final sort
- Timeline range is determined from non-randomized images (min/max modification times)
- Each randomized source can have its own `random_seed` for deterministic results
- Images from randomized sources get a `randomized = true` flag for debugging
- Uses linear congruential generator (LCG) with glibc parameters for seeded RNG

**Verified Working:**
```
🔍 Scanning directory: ./input/media_attachments/dnd-pictures
   📄 Processed: 83 images
🔍 Scanning directory: ./input/media_attachments/fediverse-stars
   📄 Processed: 116 images
🎲 Randomized timestamps for 199 images
✅ Image discovery complete: 1223 images found
```
