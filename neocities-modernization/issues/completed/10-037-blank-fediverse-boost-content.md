# Issue 10-037: Blank fediverse_boost Content

## Current Behavior

Some fediverse_boost entries render with completely empty content areas. Example from observed output:

```
 -> file: fediverse_boost/6358
══════════════════════════════════════════════════════════════════════════════─────

┌─────────┐                                                           ┌───────────┐
│ similar │                                                           │ different │
╘═════════╧═══════════════════════════════════════════════════════════╧═══════────┘
```

The content area between the header and navigation is blank (just whitespace). This happens for some boost entries while others display correctly (e.g., 6356 shows full embedded boost content, 6357 shows "External post: {URL}").

## Intended Behavior

All fediverse_boost entries should display meaningful content:
- **Embedded boosts**: Display the actual boosted content text
- **External boosts**: Display "External post: {URL}" with a clickable link
- **Edge cases**: Display informative fallback text explaining why content is unavailable

No boost entry should render with completely blank content. If content cannot be extracted, display diagnostic information such as:
- "Boost content unavailable (external post no longer accessible)"
- "Boost references: {URI}" if URI is available but content is not

## Suggested Implementation Steps

1. **Investigate extraction**: Check `scripts/extract-fediverse.lua` boost content extraction
   - Identify which boost_type produces blank content
   - Check if external boost URI is being captured when content is empty

2. **Add content validation**: In `extract_boost_content()` function (~line 164-204)
   - Validate content is non-empty before returning
   - Log warning if content is empty with boost metadata for diagnosis
   - Add fallback content generation for edge cases

3. **Trace specific entry**: Find fediverse_boost entry 6358 in poems.json
   - Check its `metadata.boost_type` (external, embedded, cached_external)
   - Verify what content/URI was extracted during extraction phase

4. **Add defensive rendering**: In HTML generation
   - Check for empty content before rendering
   - Display diagnostic message rather than blank space

## Related Files

- `scripts/extract-fediverse.lua:164-204` - extract_boost_content() function
- `cache/poems.json` - Where extracted boost data is stored
- `src/flat-html-generator.lua:2180-2200` - Boost content rendering

## Dependencies

- Related to Issue 6-027b (Boost extraction implementation)

## Notes

This issue should be investigated before other boost rendering issues, as the blank content may indicate an extraction bug that affects data quality.

---

**Priority**: Medium - Data quality issue affecting user experience

**Phase**: 10 - Developer Experience & Tooling

## Implementation Notes (2026-03-25)

**Root cause identified**: The boost content cache (`assets/boost-content-cache.json`) contains entries with `"content":""` (empty strings). The check `if cached and cached.content then` passed because empty strings are truthy in Lua.

**Fixes applied**:

1. **scripts/extract-fediverse.lua:374-376** - Added `and cached.content ~= ""` check for cached external boosts
2. **scripts/extract-fediverse.lua:416** - Added `and boosted_object.content ~= ""` check for embedded boosts
3. **scripts/extract-fediverse.lua:433-450** - Added fallback case for embedded objects with empty content (uses `boosted_object.id` as URI)
4. **src/flat-html-generator.lua:2186-2195** - Added defensive rendering (main thread): displays `original_uri` if content is blank
5. **src/flat-html-generator.lua:3621-3632** - Added defensive rendering (worker thread): same fallback logic

**Status**: Ready for testing. Re-extract fediverse data to apply extraction fix, then regenerate HTML to verify blank boosts now show "External post: {URL}".
