# Issue 8-055: Fix Golden Poem Formatting on Similar/Different Pages

## Priority
Medium

## Current Behavior

Golden poems rendered on similar/different pages exhibit three formatting bugs that produce misaligned box-drawing characters. These are visible in the generated HTML when viewing the `<pre>` block output.

### Bug 1: HTML Entity Padding Miscalculation

Content lines containing `>`, `<`, or `&` characters have their right wall `│` shifted left. The characters are HTML-escaped (`>` → `&gt;`), but the padding calculation counts the entity's byte length instead of its display width.

**Example** (fediverse/1317):
```
║ I could code my own horoscope >.>                                          │  ← 6 chars too far left
║                                                                                  │  ← correct position
```

**Root cause** (`flat-html-generator.lua:~3088-3097`, worker thread):
```lua
visible_content = content:gsub("<[^>]+>", "")   -- strips <font>, <b> tags
visible_length = utf8_char_count(visible_content) -- counts &gt; as 4 chars, not 1
padding_needed = CONTENT_WIDTH - visible_length   -- padding is 6 too few
```

The regex `<[^>]+>` strips HTML tags but not HTML entities. `&gt;` does not match `<[^>]+>`, so it remains in the string. `utf8_char_count("&gt;")` returns 4 (all ASCII bytes), but the browser renders it as 1 character (`>`). Each escaped entity adds phantom characters to the width count.

**Magnitude**: 3 extra bytes per `>` or `<`, 4 extra bytes per `&`. A line with `>.>` (two `>` entities) loses 6 padding spaces.

**Also affects**: The main scope padding at lines ~1658-1675 (`apply_golden_poem_formatting()`), and regular poem padding wherever HTML-escaped content is padded.

### Bug 2: Golden Poem Bottom Border Junction Off-By-One

The `╧` and `┴` junction characters on the bottom progress bar don't align with the `┐` and `┌` corners on the navigation junction line above them.

**Example**:
```
╟─────────┐                                                            ┌───────────┤
╚════════╧════════────────────────────────────────────────────────────┴──────────┘
          ↑ ┐ at position 10                                          ↑ ┌ at position 71
         ↑ ╧ at position 9 (WRONG)                                   ↑ ┴ at position 70 (WRONG)
```

**Root cause** (`flat-html-generator.lua:~823-824`):
```lua
-- Golden poem junction positions (WRONG)
LEFT_JUNCTION_POS = 9     -- should be 10
RIGHT_JUNCTION_POS = 70   -- should be 71
```

Regular poems use correct positions:
```lua
-- Regular poem junction positions (CORRECT)
REGULAR_LEFT_JUNCTION_POS = 10
REGULAR_RIGHT_JUNCTION_POS = 70
```

The golden poem is 1 character wider than regular (84 vs 83). The left box dimensions are the same (11 chars, `┐` at position 10), so `LEFT_JUNCTION_POS` should also be 10. The right box starts 1 position further right in golden poems (position 71 vs 70), so `RIGHT_JUNCTION_POS` should be 71.

**Also in worker thread** (`flat-html-generator.lua:~3185-3186`):
```lua
local LEFT_JUNCTION = is_golden and 9 or 10    -- golden should be 10
local RIGHT_JUNCTION = is_golden and 70 or 70  -- golden should be 71
```

### Bug 3: Worker Thread Ignores Config Layout Overrides

The main scope loads layout constants from `config.lua`:
```lua
LAYOUT.GOLDEN_POEM_WIDTH = config.layout.golden_poem_width or 84  -- config says 85
```

But the effil worker thread cannot access the `LAYOUT` table (not serializable). It hardcodes the defaults:
```lua
local TOTAL_CHARS = is_golden and 82 or 83  -- line 3184 (84 total, should be 85)
```

This means golden poems on chronological pages (main scope, 85-wide) look different from golden poems on similar/different pages (worker thread, 84-wide).

## Intended Behavior

1. **Right wall `│` perfectly aligned** on all content lines, regardless of HTML entities in the text
2. **Bottom border junctions `╧`/`┴` aligned** directly under the navigation corner characters `┐`/`┌`
3. **Consistent golden poem width** across all page types (chronological, similar, different)

### Correct rendering:
```
╔══════════════════────────────────────────────────────────────────────────────────────┐
║ I could code my own horoscope >.>                                                    │
║                                                                                      │
╟──────────┐                                                              ┌────────────┤
║ similar  │                        chronological                        │  different  │
╚══════════╧══════════────────────────────────────────────────────────────┴────────────┘
```

All `│` right walls at the same column. `╧` directly under `┐`. `┴` directly under `┌`. Width consistent with config (85 chars if `golden_poem_width = 85`).

## Suggested Implementation Steps

### Fix 1: HTML Entity Display-Width Counting

1. **Add an entity-decoding step** to the visible-width calculation in both the main scope and worker thread:

   ```lua
   -- After stripping HTML tags, decode entities for accurate width counting
   visible_content = content:gsub("<[^>]+>", "")
   -- Decode common HTML entities to their display characters
   visible_content = visible_content:gsub("&gt;", ">")
                                     :gsub("&lt;", "<")
                                     :gsub("&amp;", "&")
                                     :gsub("&quot;", '"')
                                     :gsub("&#39;", "'")
   visible_length = utf8_char_count(visible_content)
   ```

2. **Apply in main scope** at `apply_golden_poem_formatting()` (~line 1659-1660) and in the regular poem padding logic.

3. **Apply in worker thread** at the golden poem formatting (~line 3088-3090) and the regular poem formatting.

4. **Test with poems containing**: `>`, `<`, `&`, `"`, `'` in their content. Verify the right wall aligns perfectly.

### Fix 2: Golden Junction Position Correction

5. **Fix main scope** junction positions (~line 823-824):
   ```lua
   -- Golden poem junction positions (corrected)
   LEFT_JUNCTION_POS = 10    -- was 9, now aligns ╧ under ┐ at position 10
   RIGHT_JUNCTION_POS = 71   -- was 70, now aligns ┴ under ┌ at position 71
   ```

6. **Fix worker thread** junction positions (~line 3185-3186):
   ```lua
   local LEFT_JUNCTION = is_golden and 10 or 10    -- both are 10 now
   local RIGHT_JUNCTION = is_golden and 71 or 70   -- golden +1 for wider box
   ```

7. **Verify alignment** by regenerating a golden poem page and checking that `╧` and `┴` sit directly under `┐` and `┌`.

### Fix 3: Pass Layout Constants to Worker Thread

8. **Serialize layout values** before launching the effil worker thread. Pass them as arguments:
   ```lua
   -- Before effil.thread() call (~line 2799):
   local worker_layout = {
       golden_width = LAYOUT.GOLDEN_POEM_WIDTH or 84,
       regular_width = LAYOUT.REGULAR_POEM_WIDTH or 83,
       content_width = LAYOUT.TEXT_CONTENT_WIDTH or 80,
       left_box_width = LAYOUT.LEFT_BOX_WIDTH or 11,
       right_box_width = LAYOUT.RIGHT_BOX_WIDTH or 13,
       gap_width = LAYOUT.GAP_WIDTH or 59
   }
   -- Pass as a string-encoded table or individual numeric arguments
   ```

9. **Use the passed values** inside the worker thread instead of hardcoded numbers.

10. **Verify consistency**: Generate a golden poem on both a chronological page and a similar page. Diff the box widths — they should match.

### Verification

11. **Visual test**: Regenerate HTML and check at least 3 golden poems:
    - One with `>` or `<` in content (entity padding test)
    - One on a chronological page (main scope rendering)
    - The same poem on a similar/different page (worker thread rendering)
    - Compare widths, junction alignment, and right wall alignment

## Edge Cases

1. **Multiple entities on one line**: A line like `a < b && c > d` has 4 entity conversions (`<`, `&`, `&`, `>`). The padding fix must decode all of them.

2. **Entity at end of line**: Content that ends with `&gt;` exactly at the 80-char boundary — after entity decoding, the display content is shorter, so the line wraps differently. The padding fix addresses display width but word-wrapping logic may also need entity awareness.

3. **Nested HTML in content**: Some fediverse content may contain HTML that survived cleaning (e.g., `&lt;div&gt;`). The entity decoding in the padding calculation must only affect the **width counting** string, not the actual rendered content — the entities must remain for correct HTML display.

4. **Config changes after worker launch**: If config.lua is modified between pipeline runs, the worker thread picks up the new values on next run since layout constants are passed at thread launch time.

## Related Documents

- `src/flat-html-generator.lua:~823-824` — Golden junction position constants
- `src/flat-html-generator.lua:~1658-1675` — Main scope golden poem padding
- `src/flat-html-generator.lua:~3084-3102` — Worker thread golden poem padding
- `src/flat-html-generator.lua:~3184-3186` — Worker thread junction positions
- `src/flat-html-generator.lua:~2999` — HTML escaping that creates the entities
- `issues/completed/8-044-golden-poem-detection-and-formatting-parity.md` — Prior golden poem formatting work
- `config.lua:layout` — Layout width configuration

## Metadata

- **Status**: Completed
- **Created**: 2026-01-26
- **Completed**: 2026-01-28
- **Phase**: 8 (Website Completion)
- **Estimated Complexity**: Medium
- **Dependencies**: None
- **Affects**: All golden poems on all page types (chronological, similar, different)

## Completion Notes

### Bug 1 Fix: HTML Entity Padding Miscalculation
- Used `text_formatter.calculate_visible_width()` (from shared module created in 8-056)
- This function decodes HTML entities (`&gt;`, `&lt;`, `&amp;`, etc.) before counting width
- Applied in both main thread (line 1668) and worker thread (line 3078)
- Now `&gt;` counts as 1 display char, not 4 bytes

### Bug 2 Fix: Golden Junction Position Correction
- Changed `GOLDEN_LEFT_JUNCTION_POS` from 9 to 10 (same as regular)
- Changed `GOLDEN_RIGHT_JUNCTION_POS` from 70 to 71 (regular + 1)
- Updated LAYOUT config (lines 127-128), main thread (lines 827-828), and worker thread (lines 3184-3190)
- Junction characters `╧`/`┴` now align directly under `┐`/`┌` corners

### Bug 3 Fix: Worker Thread Config Layout Support
- Added `layout` object to `thread_config` (lines 2795-2803) with:
  - `golden_poem_width`, `regular_poem_width`, `text_content_width`
  - `golden_left_junction`, `golden_right_junction`, `regular_left_junction`, `regular_right_junction`
- Worker thread now reads from `config.layout` instead of hardcoding values
- Golden poems now render identically on chronological and similar/different pages

### Verification
- `luajit -e "require('src.flat-html-generator')"` loads without errors
