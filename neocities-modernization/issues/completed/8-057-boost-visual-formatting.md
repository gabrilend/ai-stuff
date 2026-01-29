# 8-057: Boost Visual Formatting

## Status
- **Phase**: 8
- **Priority**: Medium
- **Type**: Enhancement

**Status**: Open

**Depends On**: 8-011 (Scrape Fediverse Boost Content)

## Current Behavior

Boosted posts are extracted and will have actual content (via 8-011 scraper), but they
render identically to regular poems. There is no visual indication that a poem is
boosted/shared content from another author.

## Intended Behavior

Boosted posts should have a distinctive visual format that:

1. Indicates the content is a "boost" (shared from another source)
2. Uses nested box-drawing characters (outer frame + inner content box)
3. Has asymmetric arrows at upper-left (◀─) and lower-right (─▶) corners
4. Includes a [BOOST] label in the top border
5. Integrates with the existing progress bar system (═/─ transition)
6. Maintains the 84-character width standard
7. Preserves similar/different navigation corner boxes

### Color Scheme (from design reference)

Based on `/notes/boost post image style.png`:

- **Red/Magenta**: Arrows (◀─, ─▶) and [BOOST] label
- **Blue/Navy**: Outer frame (╔═╗║╚═╝)
- **Teal/Cyan**: Inner content box (┌─┐│└─┘)
- **Yellow**: The actual text content

### Design Reference

Example at 60% progress (label centered at position ~25):
```
◀─╔════════════════════════[BOOST]════════════════════════─────────────────────────╗
  ║ ┌────────────────────────────────────────────────────────────────────────────┐ ║
  ║ │  "A gem cannot be polished without friction, nor a man perfected          │ ║
  ║ │   without trials."                                                        │ ║
  ║ └────────────────────────────────────────────────────────────────────────────┘ ║
  ╠─────────┐                                                          ┌───────────╣
  ║ similar │                                                          │ different ║
  ╚═════════════════════════════════════════════════════╧═════════════────────────╝─▶
```

## Design Decision: Dynamic Label Position

**Confirmed**: [BOOST] label centered at 50% of current progress

The label "floats" on the progress wave - positioned at the halfway point of the
completed (═) section of the progress bar.

### Formula

```
label_center = (progress_percentage × bar_width) / 2
             = progress_percentage × 40  (for 80-char bar interior)

label_start  = label_center - 3  ([BOOST] is 7 chars)
label_end    = label_center + 4
```

### Visual Examples

At 20% progress (label at ~8):
```
◀─╔══[BOOST]══════════────────────────────────────────────────────────────────────╗
```

At 40% progress (label at ~16):
```
◀─╔═══════════════[BOOST]════════════════──────────────────────────────────────────╗
```

At 60% progress (label at ~25):
```
◀─╔════════════════════════[BOOST]════════════════════════─────────────────────────╗
```

At 80% progress (label at ~33):
```
◀─╔═══════════════════════════════════[BOOST]══════════════════════════════────────╗
```

At 100% progress (label at ~41):
```
◀─╔═════════════════════════════════════════[BOOST]════════════════════════════════╗
```

**Effect**: Early poems have [BOOST] near the left arrow; later poems have it drift
toward center. The label visually "rides" the progress wave, creating a playful
connection between the boost indicator and the poem's chronological position.

## Suggested Implementation Steps

1. [x] Confirm label position preference with user → Dynamic: 50% of current progress
2. [x] Create `generate_boost_frame_top()` function for outer frame with arrows and label
3. [x] Create `generate_boost_content_box()` function for inner teal box
4. [x] Create `generate_boost_frame_bottom()` function with arrow and progress bar
5. [x] Modify `extract_boost_content()` return value to flag boost formatting needed (via `is_boost` metadata)
6. [x] Update HTML generator to detect boost type and apply formatting
7. [x] Update effil worker thread with equivalent boost formatting functions
8. [x] Add color mappings for boost-specific elements (red arrows, blue frame, teal box)
9. [ ] Test with sample boosts to verify visual appearance
10. [ ] Adjust colors if needed after visual review

## Implementation Progress

### 2026-01-28: Core Implementation Complete

**Files Modified:**

1. **`src/flat-html-generator.lua`** - Main thread implementation:
   - Added `BOOST_COLOR_CONFIG` color scheme (lines 76-83)
   - Added `is_boost_poem()` detection function (lines 1484-1494)
   - Added boost frame generation functions:
     - `generate_boost_top_border()` - Top border with arrow and [BOOST] label
     - `generate_boost_content_line()` - Content wrapped in nested frames
     - `generate_boost_inner_box_top()` / `generate_boost_inner_box_bottom()` - Inner teal box borders
     - `generate_boost_nav_separator()` / `generate_boost_nav_line()` - Navigation within boost frame
     - `generate_boost_bottom_border()` - Bottom border with arrow and progress bar
     - `apply_boost_poem_formatting()` - Main formatting orchestrator
   - Updated `format_single_poem_with_progress_and_color()` to handle boosts (early return)

2. **`src/flat-html-generator.lua`** - Effil worker thread implementation:
   - Added `BOOST_COLORS` configuration (lines 3276-3282)
   - Added `is_boost_poem()` worker helper (lines 3267-3274)
   - Added worker boost functions (lines 3331-3477):
     - `worker_boost_top_border()`, `worker_boost_inner_top()`, `worker_boost_inner_bottom()`
     - `worker_boost_content_line()`, `worker_boost_nav_separator()`, `worker_boost_nav_line()`
     - `worker_boost_bottom_border()`, `worker_apply_boost_formatting()`
   - Updated `format_poem_entry()` to handle boosts with early return (lines 3542-3627)

**Design Details:**

- Width: 84 characters total (matching golden poem width)
- Top border: `◀─╔═══════[BOOST]═══════─────────╗` with dynamic label position
- Content: `║ │ text content │ ║` nested frames (outer blue + inner teal)
- Bottom: `╚═══════╧═══════════╧═══════════╝─▶` with junctions for nav box

**Color Scheme:**
- Arrow (`◀─`, `─▶`) and `[BOOST]` label: `#dc3c3c` (red)
- Outer frame (`╔═╗║╚═╝`): `#3c78dc` (blue)
- Inner box (`┌─┐│└─┘`): `#2aa198` (teal)
- Content text: `#c8b428` (yellow)

### 2026-01-29: Parallel Worker Thread Implementation

**Files Modified:**

3. **`scripts/generate-html-parallel`** - Similarity/Different page worker threads:
   - Added `BOOST_COLOR_CONFIG` constant (lines 207-214)
   - Updated `similarity_worker()` function (lines 216-475):
     - Added `poem_is_boost` and `boost_colors` parameters
     - Added inline boost formatting helper functions (no upvalues allowed)
     - Poem array now contains 4 elements per poem: `id, content, category, is_boost`
     - Content rendering checks `is_boost` and applies formatting
   - Updated `diversity_worker()` function (lines 477-815):
     - Same boost formatting support as similarity_worker
   - Updated `cached_diversity_worker()` function (lines 817-1030):
     - Added `boost_colors` parameter
     - Poem lookup now includes `is_boost` field
   - Updated main code:
     - Poem array building includes `is_boost` flag (lines 1263-1269)
     - Poem content lookup includes `is_boost` field (lines 1308)
     - Shared `BOOST_COLOR_CONFIG` effil table (line 1424)
     - Worker calls updated with new parameters (lines 1472-1484, 1579-1623)

**Key Design Decisions:**
- Simplified boost frame for similarity/different pages (no navigation section)
- All boost formatting functions defined inside each worker (effil upvalue limitation)
- Boost poems identified by `poem.metadata.is_boost` flag

**Pending Testing:**
- Requires extraction with `--include-boosts` to populate boost poems
- Then HTML generation to verify visual appearance

## Technical Notes

### Character Width Breakdown (84 chars total)

Top border:
```
◀─╔═══════════════════════════════════[BOOST]═════════════════════════────────────╗
│││                                   │     │                                     │
│││                                   └──┬──┘                                     │
│││                                      │                                        │
│││     Progress bar (═ then ─)       [BOOST]           Progress bar continues    │
││└─ Outer frame start (╔)            label                                       │
│└── Arrow extension (─)                                          Outer frame (╗)─┘
└─── Arrow head (◀)
```

Content area:
- Outer frame: 2 chars (║ ... ║)
- Inner padding: 2 chars (space after ║, space before ║)
- Inner box borders: 2 chars (│ ... │)
- Inner padding: 2 chars (space after │, space before │)
- Content: 76 chars

### Integration with Existing Code

The boost format should be triggered when:
- `poem.metadata.is_boost == true`
- `poem.metadata.boost_type == "cached_external"` or `"embedded"`

Files to modify:
- `src/flat-html-generator.lua` - Main thread formatting
- `scripts/generate-html-parallel` - Effil worker thread formatting
- `libs/text-formatter.lua` - Possibly add boost-specific text wrapping

## Related Documents

- `/notes/boost post image style.png` — Original visual reference
- `/notes/golden-poem-example` — Existing poem format specifications
- `/issues/8-011-scrape-fediverse-boost-content.md` — Boost content scraping
- `/issues/completed/6-027b-add-boost-announce-activity-extraction.md` — Boost extraction

## Design Evolution

### 2026-01-28: Initial Design Session

Examined `/notes/boost post image style.png` which shows:
- Red outer border frame
- Dark blue inner layer
- Teal/cyan content area with rounded corners
- Arrows at upper-left (pointing left) and lower-right (pointing right)
- Yellow text content

Evaluated 6 design options:
1. Nested Double/Single with Corner Arrows
2. Asymmetric Arrows (matching image layout)
3. Ribbon/Banner Style
4. Minimal with Boost Indicator label
5. Double-Frame with Arrow Flags
6. Integrated with Progress Bar

**Selected**: Combination of Option 2 (asymmetric arrows) + Option 4 ([BOOST] label) +
Option 6 (progress bar integration).

Initially prepared three fixed label positions (Close, Near, Almost-Center).
User selected position 10, then refined to dynamic positioning:

**Final decision**: [BOOST] label centered at 50% of current progress.
- Formula: `label_center = progress_percentage × 40`
- Effect: Label "floats" on the progress wave, drifting from left (early poems) toward center (later poems)
- Creates playful visual connection between boost indicator and chronological position

---
