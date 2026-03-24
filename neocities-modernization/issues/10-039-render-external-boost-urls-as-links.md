# Issue 10-039: Render External Boost URLs as Clickable Links

## Current Behavior

External boost entries display URLs as plain text, not as clickable links:

```
 -> file: fediverse_boost/6357
══════════════════════════════════════════════════════════════════════════════─────
 External post: https://tech.lgbt/users/paleblueyedot/statuses/115644789217659891
┌─────────┐                                                           ┌───────────┐
│ similar │                                                           │ different │
╘═════════╧═══════════════════════════════════════════════════════════╧═══════────┘
```

The URL `https://tech.lgbt/users/paleblueyedot/statuses/115644789217659891` is displayed as plain text. Users cannot click to view the original boosted post on the fediverse.

## Intended Behavior

External boost URLs should be rendered as clickable HTML links:

```html
External post: <a href="https://tech.lgbt/users/paleblueyedot/statuses/115644789217659891" target="_blank">
  https://tech.lgbt/users/paleblueyedot/statuses/115644789217659891
</a>
```

Or with friendlier display text:

```html
External post: <a href="https://tech.lgbt/..." target="_blank">paleblueyedot@tech.lgbt</a>
```

Benefits:
- Users can view the original boosted content on the fediverse
- Provides attribution to original author
- Improves user experience for external boost entries

## Suggested Implementation Steps

1. **Modify boost content generation**: In `scripts/extract-fediverse.lua`
   - When generating "External post: {URL}" content
   - Wrap URL in markdown link format: `[{URL}]({URL})`
   - Or store URL separately in metadata for rendering-time formatting

2. **Add link rendering in HTML generator**: In `src/flat-html-generator.lua`
   - Detect external boost content pattern: `^External post: (https?://[^\s]+)`
   - Convert to HTML anchor tag with appropriate attributes
   - Consider adding `rel="noopener noreferrer"` for security

3. **Alternative: Store URL in metadata**:
   - Keep raw URL in `metadata.original_uri`
   - Generate link at render time based on boost_type

4. **Test with actual external boost entries**: Verify links work across browsers

## Technical Approach

### Option A: Extraction-time formatting (simpler)
```lua
-- In extract_boost_content() when handling external boosts
content = string.format("External post: [View on fediverse](%s)", boosted_object)
```

### Option B: Render-time detection (more flexible)
```lua
-- In flat-html-generator.lua boost rendering
local external_pattern = "^External post: (https?://[^\n]+)"
local url = content:match(external_pattern)
if url then
    content = string.format('External post: <a href="%s" target="_blank" rel="noopener">%s</a>',
        url, url)
end
```

## Related Files

- `scripts/extract-fediverse.lua:164-204` - extract_boost_content() function
- `src/flat-html-generator.lua:2180-2200` - Boost content rendering
- `libs/text-formatter.lua` - May have existing URL detection utilities

## Dependencies

- Should coordinate with 10-037 (blank boost content) for consistent handling
- Consider markdown link rendering already implemented in text-formatter.lua

---

**Priority**: Low - Enhancement for external boost usability

**Phase**: 10 - Developer Experience & Tooling
