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

```
◀─╔═════════[BOOST]═══════════════════════════════════════════════════────────────╗
  ║ ┌────────────────────────────────────────────────────────────────────────────┐ ║
  ║ │  "A gem cannot be polished without friction, nor a man perfected          │ ║
  ║ │   without trials."                                                        │ ║
  ║ └────────────────────────────────────────────────────────────────────────────┘ ║
  ╠─────────┐                                                          ┌───────────╣
  ║ similar │                                                          │ different ║
  ╚═════════╧══════════════════════════════════════════════════════════╧─────────╝─▶
```

## Design Decision: Label Position

**Confirmed**: Position 10 (early, near the left arrow)

```
◀─╔═════════[BOOST]═══════════════════════════════════════════════════────────────╗
```

This places the [BOOST] label close to the left arrow, creating a visual grouping
that reads naturally: "arrow → BOOST → content". The label is visible early when
scanning left-to-right.

## Suggested Implementation Steps

1. [x] Confirm label position preference with user → Position 10 selected
2. [ ] Create `generate_boost_frame_top()` function for outer frame with arrows and label
3. [ ] Create `generate_boost_content_box()` function for inner teal box
4. [ ] Create `generate_boost_frame_bottom()` function with arrow and progress bar
5. [ ] Modify `extract_boost_content()` return value to flag boost formatting needed
6. [ ] Update HTML generator to detect boost type and apply formatting
7. [ ] Update effil worker thread with equivalent boost formatting functions
8. [ ] Add color mappings for boost-specific elements (red arrows, blue frame, teal box)
9. [ ] Test with sample boosts to verify visual appearance
10. [ ] Adjust colors if needed after visual review

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

Prepared three label position variants (Close, Near, Almost-Center) for user selection.

---
