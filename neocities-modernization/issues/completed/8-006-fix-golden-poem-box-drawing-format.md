# Issue 8-006: Fix Golden Poem Box-Drawing Format

## Current Behavior

Golden poems (exactly 1024 characters) are detected correctly via `is_golden_poem()` function in `src/flat-html-generator.lua:514-520`, but the `apply_golden_poem_formatting()` function (lines 524-550) renders them incorrectly.

**Current rendering** (simplified per-line borders):
```
╔═ first line content ╓─
║  middle line content ║
╚═ last line content ╙─
```

This approach:
- Adds borders to each line individually
- Uses inconsistent corner characters (╓ and ╙ are unusual choices)
- Does not create a proper box around the entire poem
- Border width varies with line content length
- Does not maintain the 82-character width specification

## Intended Behavior

Per `notes/golden-poem-example`, golden poems should render with a proper box:

```
╔═════════════════════════════════════════════════───────────────────────────────┐
║                                                                                │
║                          poem text goes in here                                │
║                                                                                │
╚═════════════════════════════════════════════════───────────────────────────────┘
```

**Specifications**:
- Total width: **82 characters** (including corner characters)
- Top border: `╔` + `═` (transitioning to `─`) + `┐`
- Left side: `║`
- Right side: `│`
- Bottom border: `╚` + `═` (transitioning to `─`) + `┘`
- Interior width: 80 characters (space + poem content + space)
- Poem text centered within the 80-character interior

**Regular poem format** (non-golden) for comparison:
```
 ════════════════════════════════════════════════────────────────────────────────

                               poem text goes here

 ════════════════════════════════════════════════────────────────────────────────
```
- 80 character border with 1 space padding on each side (82 total visual width)
- No box, just top and bottom separators

## Suggested Implementation Steps

### Step 1: Rewrite `apply_golden_poem_formatting()` function
- [x] Calculate proper border string (82 chars total)
- [x] Create top border: `╔` + progress×`═` + remaining×`─` + `┐`
- [x] Create bottom border: `╚` + progress×`═` + remaining×`─` + `┘`
- [x] Create side borders: `║` (left) and `│` (right)

### Step 2: Implement proper content padding
- [x] Split poem content into lines
- [x] Pad each line to exactly 80 characters (content width)
- [x] Add `║` prefix and `│` suffix to each line
- [x] Ensure blank lines are also properly padded

### Step 3: Assemble complete golden box
- [x] Integrate progress bar into golden borders (colored progress preserved)
- [x] Verify total width is exactly 82 characters per line
- [x] Test with actual 1024-character golden poems (244 in corpus)

### Step 4: Verify regular poem format
- [x] Ensure non-golden poems use the simpler separator format
- [x] Regular separators: ` ` + colored progress + remaining (81 chars visual)
- [x] Confirm visual alignment between golden and regular poems

## Dependencies

- Requires understanding of poem content structure (already 80-char formatted)
- Works within existing `format_content_with_warnings()` pipeline

## Quality Assurance Criteria

- [x] Golden poems (1024 chars) render with full box-drawing border
- [x] Box is exactly 82 characters wide on all lines
- [x] Border uses correct Unicode characters: ╔ ═ ─ ┐ ║ │ ╚ ┘
- [x] Poem content remains readable within box
- [x] Regular poems render without box (just separators with leading space)
- [x] Visual output matches `notes/golden-poem-example` specification

## Related Issues

- **Issue 3-005b**: Create golden poem visual indicators (established golden detection)
- **Issue 5-015**: Refactor golden poem system (defined 1024-char criterion)

## Technical Notes

**Current implementation location**: `src/flat-html-generator.lua:524-550`

**Unicode box-drawing characters**:
- `╔` (U+2554) - double box drawings down and right
- `═` (U+2550) - double horizontal
- `─` (U+2500) - light horizontal
- `┐` (U+2510) - light down and left
- `║` (U+2551) - double vertical
- `│` (U+2502) - light vertical
- `╚` (U+255A) - double up and right
- `┘` (U+2518) - light up and left

The transition from double (`═`) to single (`─`) in the horizontal borders creates a distinctive visual fade effect.

---

## Implementation Summary

### Changes Made

**1. Modified `generate_progress_dashes()` function** (lines 211-272)
- Added `is_golden` and `position` parameters
- Golden top border: `╔` + colored progress + remaining + `┐`
- Golden bottom border: `╚` + colored progress + remaining + `┘`
- Regular poems: leading space + progress bar (81 chars visual)
- Updated ARIA labels: "golden poem border" vs "eighty dashes"

**2. Rewrote `apply_golden_poem_formatting()` function** (lines 552-591)
- Fixed line splitting pattern (was producing empty lines)
- Each content line: `║` + content padded to 80 chars + `│`
- Total width: 82 characters per line

**3. Updated `format_single_poem_with_progress_and_color()` function** (lines 652-689)
- Added `is_golden_poem(poem)` check
- Passes golden status and position to `generate_progress_dashes()`
- Separate top/bottom border generation with correct corners

**4. Updated `generate_chronological_index_with_navigation()` function** (lines 893-926)
- Added golden poem detection for chronological index generation
- Generates proper golden borders in main index HTML

### Test Results

- **244 golden poems** in corpus detected and rendered correctly
- Top border: `╔<font color="..."><b>═══</b></font>───...┐`
- Content lines: `║...padded content...│`
- Bottom border: `╚<font color="..."><b>═══</b></font>───...┘`
- Progress bar coloring preserved within golden borders
- Regular poems unchanged (leading space, no corners)

---

**ISSUE STATUS: COMPLETED**

**Created**: 2025-12-15
**Completed**: 2025-12-15

**Phase**: 8 (Website Completion)
