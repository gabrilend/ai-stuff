# Issue 10-021: Whitespace-Preserving Word Wrap for Poems

## Priority
High (content readability)

## Current Behavior

After Issue 8-056, poem content preserves all whitespace (leading spaces, indentation,
multi-space runs). However, lines longer than 80 characters now extend beyond the page
boundary, causing horizontal overflow.

This is visible on chronological pages where poems containing long URLs push content
far to the right.

### Example

A poem line like:
```
   Here is a link: https://www.reddit.com/r/antiwork/comments/n5g17c/remote_revolution/gx1itp0?utm_source=share&utm_medium=web2x&context=3
```

Currently renders as one 140+ character line, overflowing the 80-char content area.

## Intended Behavior

Long lines should wrap at word boundaries while **preserving leading whitespace**:

```
   Here is a link:
   https://www.reddit.com/r/antiwork/comments/n5g17c/remote_revolution/gx1itp
   0?utm_source=share&utm_medium=web2x&context=3
```

Key requirements:
1. **Leading whitespace preserved**: If a line starts with 3 spaces, all wrapped
   continuations also start with 3 spaces (or configurable indent)
2. **Interior whitespace preserved**: Multi-space runs within words stay intact
3. **Paragraph breaks preserved**: Empty lines remain empty
4. **Long words broken**: URLs or other strings exceeding line width get character-broken
5. **Short lines unchanged**: Lines <= 80 chars pass through unmodified

## Root Cause

Issue 8-056 disabled word wrapping entirely to fix whitespace destruction. The old
`wrap_single_line_80_chars` function used `%S+` splitting which collapsed all whitespace.

The fix was too aggressive - we need wrapping that RESPECTS whitespace, not no wrapping.

## Suggested Implementation

### Step 1: Add `wrap_preserving_indent` to text-formatter.lua

```lua
function M.wrap_preserving_indent(line, max_width)
    max_width = max_width or 80

    if #line <= max_width then
        return {line}  -- Short enough, no wrapping needed
    end

    -- Capture leading whitespace separately
    local leading, remainder = line:match("^(%s*)(.*)$")
    local indent_width = #leading
    local content_width = max_width - indent_width

    if content_width < 10 then
        -- Edge case: huge indent, can't wrap meaningfully
        return {line}
    end

    -- Word-wrap the remainder, preserving multi-space runs
    local result_lines = {}
    local current = ""

    -- Split on space boundaries while keeping the spaces
    for segment in remainder:gmatch("(%S+%s*)") do
        if #current + #segment <= content_width then
            current = current .. segment
        else
            -- Flush current line
            if #current > 0 then
                table.insert(result_lines, leading .. current:gsub("%s+$", ""))
            end
            -- Start new line with this segment
            current = segment

            -- Handle very long segments (URLs) that exceed width
            while #current > content_width do
                local chunk = current:sub(1, content_width)
                table.insert(result_lines, leading .. chunk)
                current = current:sub(content_width + 1)
            end
        end
    end

    -- Flush final line
    if #current > 0 then
        table.insert(result_lines, leading .. current:gsub("%s+$", ""))
    end

    return result_lines
end
```

### Step 2: Update `format_poem_content`

Change from direct line insertion to using the wrapping function:

```lua
function M.format_poem_content(text)
    local lines = M.format_poem_lines(text)
    local padded_lines = {}

    for _, line in ipairs(lines) do
        -- Wrap long lines while preserving leading whitespace
        local wrapped = M.wrap_preserving_indent(" " .. line, 80)
        for _, wrapped_line in ipairs(wrapped) do
            table.insert(padded_lines, wrapped_line)
        end
    end

    return padded_lines
end
```

### Step 3: Test with affected poems

1. Poems with long URLs (chronological pages)
2. Poems with artistic indentation (notes category)
3. Poems with paragraph breaks
4. Golden poems (ensure border alignment still works)

## Related Documents

- `issues/completed/8-056-preserve-whitespace-in-poem-rendering.md` - Previous fix
- `libs/text-formatter.lua` - Shared formatting module
- `src/flat-html-generator.lua` - Main/worker thread formatting

## Metadata

- **Status**: Completed
- **Created**: 2026-01-30
- **Completed**: 2026-01-30
- **Phase**: 10 (Developer Experience & Tooling)
- **Estimated Complexity**: Medium
- **Dependencies**: Extends 8-056 work

## Completion Notes

### Changes Made

1. **Added `wrap_preserving_indent()` to `libs/text-formatter.lua`**
   - Wraps lines at word boundaries while preserving leading whitespace
   - Continuation lines inherit original line's indentation
   - Very long words (URLs) get character-broken when they exceed available width
   - Lines <= max_width pass through unchanged

2. **Updated `format_poem_content()` in `libs/text-formatter.lua`**
   - Now calls `wrap_preserving_indent()` for each line
   - Maintains 1-space left padding for all lines
   - Optional max_width parameter (default 80)

### Test Results

```
=== Test: format_poem_content with long URL ===
1 | short line|       #11
2 | |                 #1  (empty line preserved)
3 | Here is a long URL:|  #20
4 | https://www.reddit.com/r/antiwork/.../gx1itp0?utm|  #80 (broken)
5 | _source=share&utm_medium=web2x&context=3|         #41
6 | |                 #1  (empty line preserved)
7 |    artistic indent|   #19 (3-space indent preserved)
```

### Lessons Learned

The key insight from 8-056 was correct: `%S+` pattern destroys whitespace structure.
The solution is to split on word boundaries `(%S+)(%s*)` which captures both the word
AND its trailing whitespace. By processing the remainder (after capturing leading
whitespace), we preserve the original indentation on all wrapped lines.
