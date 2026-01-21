# Issue 6-032: Fix BR Tag Variants in HTML Cleaning

## Priority
High - Data quality issue affecting poem content integrity

## Current Behavior

The `clean_html()` function in `scripts/extract-fediverse.lua` only handles the basic `<br>` tag:

```lua
clean = clean:gsub("<br>", "\n")
```

However, Mastodon and other ActivityPub servers use XHTML-style `<br />` tags (with space and slash). These tags are not converted to newlines, causing the generic tag stripper to remove them entirely:

```lua
clean = clean:gsub("<[^>]+>", "")  -- Removes <br /> without newline
```

**Result**: Line breaks are lost, causing words to run together:
- "balancing of<br />success" → "balancing ofsuccess"
- "base 3<br />step 2" → "base 3step 2"

## Intended Behavior

All `<br>` tag variants should be converted to newlines:
- `<br>` - HTML5 style
- `<br/>` - XHTML self-closing
- `<br />` - XHTML with space (Mastodon default)
- `<br class="...">` or other attributes should also work

## Root Cause

The regex `<br>` is too specific. It should use a pattern that matches the tag name followed by optional attributes/whitespace.

## Suggested Implementation

Replace line 317 in `scripts/extract-fediverse.lua`:

```lua
-- Before:
clean = clean:gsub("<br>", "\n")

-- After:
clean = clean:gsub("<br%s*/?>", "\n")  -- Handles <br>, <br/>, <br />
```

The pattern `<br%s*/?>` matches:
- `<br>` - no space, no slash
- `<br/>` - no space, slash
- `<br />` - space, slash
- `<br  />` - multiple spaces

## Files to Modify

| File | Line | Change |
|------|------|--------|
| `scripts/extract-fediverse.lua` | 317 | Update `<br>` pattern to `<br%s*/?>` |

## Testing

After fix, regenerate poems.json and verify:
1. Poem 3 (fediverse): "balancing of\nsuccess" not "balancing ofsuccess"
2. Poem 36 (fediverse): "base 3\nstep 2" not "base 3step 2"

```bash
# Regenerate fediverse data
luajit scripts/extract-fediverse.lua

# Verify fix
jq '.poems[2].content' input/fediverse/files/poems.json | grep -o "of.success"
# Should output: "of\nsuccess" (with literal newline)
```

## Related Documents

- `scripts/extract-fediverse.lua` - HTML cleaning function
- `src/flat-html-generator.lua` - May have similar patterns to check

## Metadata

- **Status**: Open
- **Created**: 2026-01-21
- **Phase**: 6 (Data Processing)
- **Estimated Complexity**: Low (single regex fix)
- **Dependencies**: None
- **Affects**: All fediverse poem content, embeddings quality
