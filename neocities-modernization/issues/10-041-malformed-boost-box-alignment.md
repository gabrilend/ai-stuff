# Issue 10-041: Malformed Boost Box Alignment and Formatting

## Current Behavior

The [BOOST] box styling has misaligned box-drawing characters. Example from similar/different page output:

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

Issues observed:
1. **Right side not aligned**: The `╗`, `║`, and `╝` characters don't form a straight vertical line
2. **Inner box overflow**: Content line's `│ ║` extends past the outer frame
3. **Bottom border length**: `══─────╝` doesn't match the top border length
4. **Nav separator misalignment**: `┌───────────╣` position doesn't match content box width
5. **Long embedded boost content not wrapped**: Embedded boosts with long content scroll off the right side of the page instead of wrapping to multiple lines

### Long Content Overflow Example (embedded boost):
```
◀─╔════════════════════════════════[BOOST]══════════════════════════════════─────╗
║ ┌────────────────────────────────────────────────────────────────────────────┐ ║
║ │ Story idea: God somehow exists and made Man in His image: filled with nasty impulses and faulty cognitive heuristics. God checks back in with his progeny and is weirded out by how wildly civilization enabled us to diverge from Him. He gets out-thought and out-argued by average adjunct professors. He has the sort of omnipotence and omniscience that's more brute force than clear thinking, and gets mad at being left behind by His children. │ ║
║ └────────────────────────────────────────────────────────────────────────────┘ ║
```

The content line extends far beyond the 80-character box width, breaking the visual frame.

## Intended Behavior

All box-drawing characters should align properly to form clean nested frames:

```
--- #3 fediverse_boost/6357 ---
◀─╔═════════════════════════════════════[BOOST]═════════════════════════════════─────────╗
  ║ ┌──────────────────────────────────────────────────────────────────────────────────┐ ║
  ║ │ External post: https://tech.lgbt/users/paleblueyedot/statuses/115644789217659891 │ ║
  ║ └──────────────────────────────────────────────────────────────────────────────────┘ ║
  ╠─────────┐                                                                ┌───────────╣
  ║ similar │                       chronological                            │ different ║
  ╚═════════╧════════════════════════════════════════════════════════════════╧═══════════╝─▶
```

Key requirements:
1. **Consistent line width**: All lines should be the same total character width
2. **Vertical alignment**: Right-side frame characters (`╗`, `║`, `╣`, `╝`) must align vertically
3. **Inner box fits**: Content box must fit within outer frame without overflow
4. **Progress bar consistency**: Top and bottom progress bars should use matching widths

## Technical Analysis

Looking at `src/flat-html-generator.lua:1815-2030`:

### Current width calculations (problematic):
- Top border: `BAR_WIDTH = 78` characters for progress bar interior
- Inner box: `INNER_WIDTH = 78` with 76 dashes between corners
- Content line: `CONTENT_WIDTH = 74` characters for text ← too narrow, should be 80
- Nav separator: `60` spaces between corners
- Bottom border: Same `BAR_WIDTH = 78`

### Problems:
1. **Width mismatch**: Different sections use inconsistent total widths
2. **Arrow placement**: `◀─` prefix and `─▶` suffix add 4 characters that may not be accounted for
3. **Padding inconsistency**: Space padding varies between frame layers
4. **Junction positions**: `LEFT_JUNCTION_POS = 10`, `RIGHT_JUNCTION_POS = 71` may not align with nav boxes

## Suggested Implementation Steps

1. **Define master width constant**: Establish single source of truth for box width
   ```lua
   local BOOST_CONTENT_WIDTH = 80   -- Inner content area (standard terminal width)
   -- Frame structure: ║ │ {content} │ ║
   -- Left padding:  ║(1) + space(1) + │(1) + space(1) = 4 chars
   -- Right padding: space(1) + │(1) + space(1) + ║(1) = 4 chars
   -- Total line width: 4 + 80 + 4 = 88 chars (plus ◀─ prefix on borders)
   ```

2. **Audit all formatting functions**: Verify each returns exactly `BOOST_BOX_TOTAL_WIDTH` characters
   - `generate_boost_top_border()` - verify total width
   - `generate_boost_inner_box_top()` - verify alignment with top
   - `generate_boost_content_line()` - verify fits in inner box
   - `generate_boost_inner_box_bottom()` - verify matches inner_box_top
   - `generate_boost_nav_separator()` - verify junction positions
   - `generate_boost_nav_line()` - verify box positions
   - `generate_boost_bottom_border()` - verify matches top_border

3. **Create visual test**: Generate boost box in isolation to verify alignment
   ```lua
   -- Test function to print boost box without HTML
   local function test_boost_box_alignment()
       print(generate_boost_top_border(0.5))
       print(generate_boost_inner_box_top())
       print(generate_boost_content_line("Test content here"))
       print(generate_boost_inner_box_bottom())
       print(generate_boost_nav_separator())
       print(generate_boost_nav_line("similar", "different", "chronological"))
       print(generate_boost_bottom_border(0.5))
   end
   ```

4. **Fix width calculations**: Adjust constants so all lines match
   - Account for `◀─` prefix (2 chars) and `─▶` suffix (2 chars)
   - Ensure inner content width leaves room for frame characters

5. **Handle long content**: Content lines exceeding inner width need word wrapping
   - **Embedded boosts**: Multi-line word wrapping with preserved indentation
     - Split content at word boundaries to fit `BOOST_CONTENT_WIDTH` (80 chars)
     - Each wrapped line gets its own `║ │ {content} │ ║` frame
     - Use existing `wrap_preserving_indent()` from text-formatter.lua (Issue 10-021)
   - **External boost URLs**: Break at logical points (path separators, query params)
     - Keep full URL intact so users can visit the original post
     - Example: `https://tech.lgbt/users/paleblueyedot/` wraps to next line
              `/statuses/115644789217659891`
     - Coordinate with Issue 10-039 (make URLs clickable) - link href stays complete
   - Inner box top/bottom borders appear once (not per-line)

6. **Replicate fixes to worker thread**: Update worker functions to match
   - `worker_boost_top_border()`
   - `worker_boost_inner_top()`
   - `worker_boost_inner_bottom()`
   - `worker_boost_content_line()`
   - `worker_boost_nav_separator()`
   - `worker_boost_nav_line()`
   - `worker_boost_bottom_border()`

## Related Files

- `src/flat-html-generator.lua:1811-2030` - Main thread boost formatting functions
- `src/flat-html-generator.lua:3388-3520` - Worker thread boost formatting functions
- `libs/text-formatter.lua` - Contains `wrap_preserving_indent()` for word wrapping (Issue 10-021)
- Issue 8-057 (original boost visual formatting implementation)

## Test Cases

1. Short content: "Hello world" - should be padded correctly
2. Medium content: 40-character string - should center properly
3. Long URL (external boost): 100+ character URL - should wrap at path separators (full URL preserved)
4. Long text (embedded boost): 300+ character paragraph - should word-wrap to multiple content lines
5. Progress bar: Test 0%, 50%, 100% progress positions
6. Multi-paragraph embedded boost: Verify line breaks are preserved within wrapped content

### Expected Long Content Rendering (embedded boost with 80-char content width):
```
◀─╔═══════════════════════════════════════════[BOOST]═══════════════════════════════════════════─────╗
  ║ ┌──────────────────────────────────────────────────────────────────────────────────────────────┐ ║
  ║ │ Story idea: God somehow exists and made Man in His image: filled with nasty impulses and     │ ║
  ║ │ faulty cognitive heuristics. God checks back in with his progeny and is weirded out by how   │ ║
  ║ │ wildly civilization enabled us to diverge from Him. He gets out-thought and out-argued by    │ ║
  ║ │ average adjunct professors. He has the sort of omnipotence and omniscience that's more       │ ║
  ║ │ brute force than clear thinking, and gets mad at being left behind by His children.          │ ║
  ║ └──────────────────────────────────────────────────────────────────────────────────────────────┘ ║
  ╠───────────┐                                                                        ┌─────────────╣
  ║ similar   │                            chronological                               │   different ║
  ╚═══════════╧════════════════════════════════════════════════════════════════════════╧═════════════╝─▶
```

Note: Exact character counts in this example are illustrative. Implementation should derive all widths from `BOOST_CONTENT_WIDTH = 80`.

## Dependencies

- This is a foundational fix that 10-040 (styling consistency) depends on
- Fix alignment BEFORE propagating boost styling to other page types

---

**Priority**: Medium - Visual quality issue

**Phase**: 10 - Developer Experience & Tooling

## Reference: Original Design

From `/notes/boost post image style.png` design reference (referenced in code comments):
- Red/Magenta: `◀─` and `─▶` arrows, `[BOOST]` label
- Blue/Navy: `╔═╗║╚═╝` outer frame
- Teal/Cyan: `┌─┐│└─┘` inner content box
- Yellow: Content text
