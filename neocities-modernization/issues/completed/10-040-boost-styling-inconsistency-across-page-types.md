# Issue 10-040: Boost Styling Inconsistency Across Page Types

## Current Behavior

Fediverse_boost entries display with different visual styling depending on which page type they appear on:

### Chronological Pages (basic styling):
```
 -> file: fediverse_boost/6356
══════════════════════════════════════════════════════════════════════════════─────
 Story idea: God somehow exists and made Man in His image: filled with nasty
 impulses and faulty cognitive heuristics...
┌─────────┐                                                           ┌───────────┐
│ similar │                                                           │ different │
╘═════════╧═══════════════════════════════════════════════════════════╧═══════────┘
```

### Similar/Different Pages (boost box styling):
```
--- #3 fediverse_boost/6357 ---
◀─╔════════════════════════════════[BOOST]══════════════════════════════════─────╗
║ ┌────────────────────────────────────────────────────────────────────────────┐ ║
║ │ External post: https://tech.lgbt/users/paleblueyedot/statuses/115644789217659891 │ ║
║ └────────────────────────────────────────────────────────────────────────────┘ ║
╠─────────┐                                                            ┌───────────╣
║ similar │                       chronological                       │ different ║
╚═════════╧════════════════════════════════════════════════════════════╧══─────╝─▶
```

Boosts on chronological pages use the same styling as regular posts, while similar/different pages use the special [BOOST] box formatting with:
- Red arrows (◀─ and ─▶)
- Blue outer frame (╔═╗║╚═╝)
- Teal inner content box (┌─┐│└─┘)
- Yellow content text
- [BOOST] label in the top border

## Intended Behavior

Boost entries use the distinctive [BOOST] box styling on **every** page type that
renders a poem. There are four, and none of them is optional:

- Chronological pages
- Similar pages
- Different pages
- **Word-cloud pages** — boosts do appear there, so this is a requirement, not a
  contingency. Stated flatly because the earlier wording ("if boosts appear
  there") read as permission to skip it, and the word-page builder did: it
  contained no mention of boosts at all, and rendered every reshare as an
  ordinary poem showing the raw `External post: <url>` placeholder with the URL
  not even hyperlinked.

The special boost styling serves to:
1. Visually distinguish shared content from original posts
2. Indicate the content is from another author
3. Provide consistent visual language across the entire site

Point 2 is why this is a correctness matter and not a decorative one. A reshare
rendered as an ordinary post silently attributes someone else's words to the
author of the collection.

## The Rule: One Module Draws the Frame

Every render path calls `src/boost-bars.lua`. No page builder draws boost
geometry itself, and no page builder keeps its own copy of the boost palette —
the palette is exported from the main HTML generator so there is exactly one.

This rule was learned the expensive way: three hand-copied versions of the frame
had already drifted into misaligned walls, wrong junction columns and corrupted
corner characters. A fourth builder that renders boosts without going through
the shared module is the same mistake, whether it drifts or simply omits.

A boost entry is composed in this order, matching the other page types:

1. The ` -> file: <category>/<id>` source line
2. The frame, from `boost_bars.format_boost(...)`

The source line matters and is easy to lose: a builder that returns the frame
early, before the point where it composes that line, produces a boost with no
provenance while every other page type shows one.

## Content Handling Inside the Frame

Three cases, in the order they must be tested:

- **Blank content** — the scrape never captured the original. Fall back to
  `External post: <original_uri>` from the metadata, or `(Boost content
  unavailable)` if even that is absent. Never render an empty frame.
- **An uncached boost** (`External post: <url>` and nothing else) — wrap the URL
  across the box lines at `boost_bars.CONTENT_WIDTH`, with every line anchored to
  the whole URL, so a long address stays inside the frame and stays clickable.
- **Cached content** — wrap each line to `boost_bars.CONTENT_WIDTH`, preserving
  indentation.

## Investigation Notes

Looking at `src/flat-html-generator.lua`:
- Lines 2156-2200+ handle boost detection and formatting
- `is_boost_poem()` function checks `poem.metadata.is_boost`
- Boost formatting functions exist (generate_boost_top_border, etc.)

The issue may be:
1. Different code paths for chronological vs similar/different generation
2. `is_boost` check not being performed in chronological generation
3. Boost formatting functions not being called in chronological context

## Suggested Implementation Steps

1. **Trace code paths**: Identify where chronological page poem rendering occurs
   - Compare to similar/different page rendering
   - Find where `is_boost_poem()` check should be added

2. **Unify boost rendering**: Ensure same formatting functions are called:
   - `generate_boost_top_border()`
   - `generate_boost_content_line()`
   - `generate_boost_inner_box_top()`
   - `generate_boost_inner_box_bottom()`
   - `generate_boost_nav_separator()`
   - `generate_boost_nav_line()`
   - `generate_boost_bottom_border()`

3. **Test all page types**: Verify boost styling appears correctly on:
   - Chronological pages (main, paginated)
   - Similar pages
   - Different pages

4. **Visual regression check**: Ensure styling is consistent across all instances

## Related Files

- `src/flat-html-generator.lua:1526-1534` - is_boost_poem() function
- `src/flat-html-generator.lua:1811-2030` - Boost formatting functions
- `src/flat-html-generator.lua:2156-2200` - Boost rendering decision point
- `src/flat-html-generator.lua:3322-3604` - Worker thread boost handling

## Dependencies

- Should be addressed after 10-041 (malformed boost box formatting)
- Boost formatting functions need to be correct before propagating

---

**Priority**: Medium - Visual consistency issue

**Phase**: 10 - Developer Experience & Tooling

## Implementation Notes (2026-03-25)

**Root cause**: The chronological page generator (`generate_chronological_index_with_navigation`) didn't check for `is_boost_poem()`. It used `format_content_with_warnings` for all poems, treating boosts like regular posts.

**Fixes applied**:

1. **src/flat-html-generator.lua:2876** - Added `is_boost_poem(poem)` check in chronological generator
2. **src/flat-html-generator.lua:2891-2940** - Added complete boost handling block:
   - Issue 10-037: Blank content fallback
   - Issue 10-039: Clickable external URLs
   - Issue 10-041: Content wrapping
   - Calls `apply_boost_poem_formatting()` for consistent [BOOST] box styling
3. **src/flat-html-generator.lua:2980-2988** - Skip standard bottom progress bar for boosts (they have their own bottom border)

**Result**: Boosts now display with the same [BOOST] box formatting on:
- ✓ Chronological pages (NEW)
- ✓ Similar pages
- ✓ Different pages

**Status**: Ready for testing. Regenerate chronological HTML to verify boost styling consistency.
