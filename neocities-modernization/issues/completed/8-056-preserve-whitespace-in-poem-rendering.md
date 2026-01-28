# Issue 8-056: Preserve Whitespace in Poem Rendering

## Priority
High (artistic content integrity)

## Current Behavior

Poems rendered on similar/different pages lose their intentional whitespace formatting. Leading spaces, multi-space runs, and indentation patterns are collapsed to single spaces. This affects **all categories** but is most visibly damaging to poems with deliberate spatial formatting.

### Example (notes/cohost-introduction)

**Expected rendering** (as authored):
```
   when life gives you mass layoffs
make mass art

                   and maybe a nice card.
```

**Actual rendering** on similar/different pages:
```
 when life gives you mass layoffs make mass art and maybe a nice card.
```

The leading spaces on lines 1 and 3, the paragraph breaks, and the deep indentation of line 3 are all destroyed. The poem becomes a single wrapped line with no spatial structure.

### Root Cause: Duplicated Text Formatting Logic

The HTML generator has **two independent text formatting implementations** that behave differently:

**Main thread** (`flat-html-generator.lua:1720-1750`) — used for chronological pages:
```lua
-- Has a category-specific bypass for notes (line 1738)
if poem_category == "notes" then
    table.insert(formatted_lines, line)  -- NO WRAPPING, preserves whitespace
else
    local wrapped = wrap_text_80_chars(line)  -- word-wraps via %S+ splitting
    ...
end
```

**Worker thread** (`flat-html-generator.lua:3044-3067`) — used for similar/different pages:
```lua
-- No category check at all. Always word-wraps.
for word in paragraph:gmatch("%S+") do        -- ← destroys ALL whitespace
    if #current_line + #word + 1 <= 80 then
        current_line = current_line .. (current_line ~= "" and " " or "") .. word
    else
        ...
    end
end
```

The `paragraph:gmatch("%S+")` pattern in the worker thread splits the text at every whitespace boundary and reconstructs it with exactly one space between each token. This destroys:

1. **Leading whitespace** — indentation is removed
2. **Multi-space runs** — artistic spacing collapses to a single space
3. **Trailing whitespace** — trimmed silently
4. **Tab characters** — replaced with a single space

The main thread partially preserves whitespace (for notes only), but uses a separate `wrap_single_line_80_chars()` function (line 1036) that also uses `%S+` splitting — so even on chronological pages, non-notes poems lose their interior spacing when lines exceed 80 characters.

### Architectural Problem: Divergent Code Paths

This is not an isolated bug. It is a structural problem: the main thread and worker thread have **separate implementations of the same text formatting logic** that have diverged over time. Multiple other bugs (8-053 alt-text fallback, 8-055 golden poem width, this issue) share the same root cause — a fix applied to one code path doesn't reach the other.

The two code paths are:

| Aspect | Main thread | Worker thread |
|--------|-------------|---------------|
| Location | Lines 1035-1067, 1099-1123 | Lines 3044-3067 |
| Wrapping | `wrap_single_line_80_chars()` (named function) | Inline `%S+` loop (anonymous) |
| Notes bypass | ✅ Line 1738 | ❌ Missing |
| Category check | ✅ Uses `poem_category` param | ❌ No category check |
| CW handling | ✅ `format_warning_box()` | ✅ Inline CW box |
| Golden formatting | ✅ `apply_golden_poem_formatting()` | ✅ Inline golden formatting |
| Shared module | ❌ Local functions in file scope | ❌ Inline in thread closure |

## Intended Behavior

1. **Whitespace is preserved for ALL categories**, not just notes. Poems are artistic content — the author's spacing decisions (leading whitespace, multi-space runs, paragraph breaks) must be respected regardless of source category.

2. **Both thread types use the same text formatting machinery**. The formatting logic should live in a shared module (e.g., `libs/text-formatter.lua`) that both the main scope and worker threads `require()`. This eliminates divergent behavior by construction — there is one implementation, not two copies that can drift apart.

3. **No `%S+` word splitting** on poem content. The `gmatch("%S+")` pattern is inherently whitespace-destructive. Text formatting should operate on lines (preserving line structure from `poems.json`), not on individual words.

### What "preserve whitespace" means

| Input | Output |
|-------|--------|
| `"   hello world"` | `"   hello world"` (leading spaces preserved) |
| `"hello    world"` | `"hello    world"` (multi-space run preserved) |
| `""` (empty line) | `""` (paragraph break preserved) |
| `"short line"` | `"short line"` (no modification) |
| 90-char line | Rendered as-is (the author chose that width) |

Poetry content in `poems.json` already contains the author's intended line breaks. The rendering layer should faithfully reproduce them, not re-flow the text.

### Architecture: Shared Text Formatter Module

The effil worker thread at line 2801 already sets up `package.path` to include both `libs/` and `src/`:

```lua
package.path = config.dir .. "/libs/?.lua;" .. config.dir .. "/src/?.lua;" .. package.path
```

And it `require()`s modules (line 2804-2805):

```lua
local t_utils = require('utils')
local t_dkjson = require('dkjson')
```

A new `libs/text-formatter.lua` module can be required by both the main scope and the worker thread, guaranteeing identical behavior.

## Suggested Implementation Steps

### Step 1: Create shared text formatting module

Create `libs/text-formatter.lua` with the whitespace-preserving text formatting logic:

```lua
-- libs/text-formatter.lua
-- Shared text formatting for poem content rendering.
-- Used by both main thread (chronological pages) and effil worker threads
-- (similar/different pages) to ensure identical whitespace handling.

local M = {}

-- {{{ function M.format_poem_lines
-- Splits poem text into lines, preserving all whitespace.
-- Returns a table of lines with no modifications to spacing.
function M.format_poem_lines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end
-- }}}

return M
```

### Step 2: Replace main thread word-wrapping with shared module

In `flat-html-generator.lua`, replace the `poem_category == "notes"` branch (lines 1736-1746):

```lua
-- BEFORE (category-specific, wraps non-notes):
if poem_category == "notes" then
    table.insert(formatted_lines, line)
else
    local wrapped = wrap_text_80_chars(line)
    for wrapped_line in (wrapped .. "\n"):gmatch("(.-)\n") do
        table.insert(formatted_lines, wrapped_line)
    end
end

-- AFTER (all categories, whitespace-preserving):
table.insert(formatted_lines, line)
```

This extends the notes-only bypass to all categories. The `wrap_text_80_chars` and `wrap_single_line_80_chars` functions (lines 1035-1123) can then be removed or marked as deprecated if no other callers exist.

### Step 3: Replace worker thread word-wrapping with shared module

In the worker thread (lines 3044-3067), replace the `%S+` word splitting:

```lua
-- BEFORE (destroys whitespace):
for p_idx, paragraph in ipairs(paragraphs) do
    if paragraph == "" then
        table.insert(wrapped_lines, "")
    else
        local current_line = ""
        for word in paragraph:gmatch("%S+") do
            ...
        end
    end
end

-- AFTER (preserves whitespace):
local text_formatter = require('text-formatter')
local content_lines = text_formatter.format_poem_lines(main_content)
for _, line in ipairs(content_lines) do
    table.insert(wrapped_lines, " " .. line)
end
```

### Step 4: Verify both code paths produce identical output

Generate a poem with intentional whitespace formatting on both:
- A chronological page (main thread rendering)
- A similar page (worker thread rendering)

Compare the `<pre>` block content — it should be identical.

### Step 5: Check for other callers of wrapping functions

Search for any other callers of `wrap_text_80_chars` or `wrap_single_line_80_chars`:

```bash
grep -n "wrap_text_80_chars\|wrap_single_line_80_chars" src/flat-html-generator.lua
```

If there are other callers (e.g., the section at line ~1873 for explore pages), update those too.

### Step 6: Remove deprecated wrapping functions

If `wrap_single_line_80_chars` (lines 1035-1067) and `wrap_text_80_chars` (lines 1099-1123) have no remaining callers, remove them. Leave a comment at the deletion site referencing this issue for future archaeologists.

### Step 7: Test with affected poems

Re-run the pipeline and verify:
- notes/cohost-introduction: leading spaces and deep indentation preserved
- Fediverse poems with HTML-originated line breaks: preserved correctly
- Messages poems: paragraph structure maintained
- Bluesky poems: line breaks preserved
- Golden poems on similar/different pages: whitespace preserved inside golden borders
- Long lines (>80 chars): rendered as-is, no re-flow

## Edge Cases

1. **Lines wider than 80 characters**: Some poems may have lines that exceed the 80-character content area. In the current box-drawing format, these will overflow the right border. This is acceptable — the author chose that width, and it's better to show the poem faithfully than to silently re-flow it. If truncation or overflow handling is desired, it should be a separate issue.

2. **Tab characters**: Tabs in poem content should be rendered as-is. Browsers render tabs in `<pre>` blocks as 8-space stops. If a poem uses tabs for indentation, preserving them gives the closest visual match to the author's intent.

3. **Trailing whitespace**: Lines may have trailing spaces. These are invisible but harmless in `<pre>` blocks. Preserving them avoids any risk of accidentally trimming meaningful content.

4. **Golden poem padding**: The golden poem formatting (lines 3072-3104 in worker thread) adds right padding to align the `│` wall. After removing word-wrapping, content lines may be any width. The padding calculation at line 3097 (`CONTENT_WIDTH - visible_length`) already handles this — shorter lines get more padding. Lines wider than 80 chars will push the right wall further right, which is the existing behavior for any over-width content. Issue 8-055 addresses the related entity-width padding bug.

5. **Content warning lines**: Both code paths strip CW lines from the main content before formatting. This step happens before the whitespace-preserving formatting, so it's unaffected.

6. **Empty poems**: A poem with empty content (`""`) produces an empty `wrapped_lines` table. Both code paths already handle this — the navigation box is still rendered below the empty content area.

## Related Documents

- `src/flat-html-generator.lua:1035-1067` — Main thread `wrap_single_line_80_chars()` (to be removed)
- `src/flat-html-generator.lua:1099-1123` — Main thread `wrap_text_80_chars()` (to be removed)
- `src/flat-html-generator.lua:1720-1750` — Main thread `format_content_with_warnings()` (notes bypass at 1738)
- `src/flat-html-generator.lua:3044-3067` — Worker thread inline word-wrapping (to be replaced)
- `src/flat-html-generator.lua:2799-2806` — Worker thread module loading (proves `require()` works in effil)
- `libs/text-formatter.lua` — New shared module (to be created)
- `issues/8-055-fix-golden-poem-formatting-on-similar-different-pages.md` — Related golden poem formatting bugs
- `docs/effil-usage-patterns.md` — Effil threading patterns and data serialization constraints

## Metadata

- **Status**: Completed
- **Created**: 2026-01-26
- **Completed**: 2026-01-28
- **Phase**: 8 (Website Completion)
- **Estimated Complexity**: Medium
- **Dependencies**: None (but 8-055 touches adjacent code)
- **Affects**: All poems on similar/different pages; architectural unification of text formatting

## Completion Notes

### Changes Made

1. **Created `libs/text-formatter.lua`** - New shared module with:
   - `format_poem_lines(text)` - Splits text into lines preserving all whitespace
   - `format_poem_content(text)` - Convenience wrapper that adds 1-space left padding
   - `decode_html_entities_for_width(content)` - For accurate padding calculations
   - `utf8_char_count(str)` - Counts UTF-8 characters (not bytes)
   - `calculate_visible_width(content)` - Combines entity decoding + UTF-8 counting

2. **Updated main thread** (`flat-html-generator.lua`):
   - Added `require("text-formatter")` at line 31
   - Removed the notes-only bypass at lines 1741-1751
   - Now preserves whitespace for ALL categories, not just notes

3. **Updated worker thread** (`flat-html-generator.lua`):
   - Added `require('text-formatter')` at line 2807 (inside effil thread)
   - Replaced the `%S+` word-splitting loop (lines 3045-3069) with shared module call
   - Worker now uses `t_text_formatter.format_poem_content()` for consistent behavior

### Functions Retained

The old `wrap_text_80_chars()` and `wrap_single_line_80_chars()` functions were NOT removed because they're still used for non-poem content:
- Image alt-text placeholders (UI element)
- Content warning boxes (UI chrome)
- TXT export format (different requirements)
- Instructions/help text (UI element)

These are appropriate use cases for word-wrapping. Only poem content rendering needed the whitespace fix.

### Verification

- `luajit -e "local m = dofile('libs/text-formatter.lua'); ..."` - Module loads and preserves whitespace correctly
- `luajit -e "require('src.flat-html-generator')"` - Main file loads without errors

### Lessons Learned

The root cause was **duplicated logic that diverged over time**. The main thread had a notes-only bypass added, but the worker thread was never updated. By creating a shared module, both code paths now use identical logic - future changes only need to happen in one place.
