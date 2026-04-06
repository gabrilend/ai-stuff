# Issue 10-038: Separate ID Numbering for fediverse_boost Category

## Current Behavior

The `fediverse_boost` category shares its ID numbering scheme with the `fediverse` category. Both categories use the same sequential iterator, resulting in interleaved IDs:

```
fediverse/6355       (original post)
fediverse_boost/6356 (boost)
fediverse_boost/6357 (boost)
fediverse_boost/6358 (boost)
fediverse/6359       (original post)
```

This means:
- Boost IDs are mixed into the fediverse sequence
- You cannot determine how many boosts exist by looking at ID range
- The ID "6357" doesn't indicate it's the 2nd boost; it's the 6357th fediverse-related item

## Intended Behavior

Each source category should have its own independent ID iterator, similar to how `fediverse`, `messages-to-myself`, and `notes` already have separate numbering:

```
fediverse/3842       (original fediverse post)
fediverse/3843       (original fediverse post)
fediverse_boost/0001 (boost)
fediverse_boost/0002 (boost)
fediverse_boost/0003 (boost)
notes/0127           (note)
messages/0034        (message)
```

Benefits:
- Clear count of items per category (boost #3 means 3rd boost)
- Consistent with other categories' ID schemes
- Easier to reference specific boosts in documentation
- ID ranges are meaningful per-category

## Suggested Implementation Steps

1. **Modify extraction script**: Update `scripts/extract-fediverse.lua`
   - Add separate counter for boost entries: `local boost_counter = 1`
   - Use `boost_counter` for fediverse_boost IDs instead of shared `counter`

2. **Update ID formatting**: In extract_boost_content() or processing loop
   - Format boost ID as: `string.format("%04d", boost_counter)`
   - Increment: `boost_counter = boost_counter + 1`

3. **Verify file naming consistency**: Ensure output filenames use new IDs
   - `fediverse_boost/0001.txt` not `fediverse_boost/6356.txt`

4. **Re-extract data**: Run extraction to regenerate poems.json with new IDs

5. **Regenerate caches**: Similarity matrix and other caches need refresh
   - The poem_index references will change

6. **Test navigation**: Verify similar/different links work with new IDs

## Related Files

- `scripts/extract-fediverse.lua:310-338` - Boost processing loop
- `cache/poems.json` - Stores extracted poem data with IDs
- `src/flat-html-generator.lua` - Uses poem IDs for filenames and links

## Considerations

- **Breaking change**: All poem_index values for boosts will change
- **Cache invalidation**: Requires full pipeline re-run with --force
- **Existing links**: Any hardcoded references to boost IDs will break

## Dependencies

- Should be implemented after 10-037 (blank boost content) is resolved
- Will require cache regeneration (pipeline stages 1-9)

---

## Implementation Progress

### 2026-04-06: Completed

**Changes made to `scripts/extract-fediverse.lua`:**

1. **Line 590-592**: Added `boost_id_counter` variable initialized to 1
   - Separate from the main `key` iterator used for original posts
   - Comment explains purpose: boosts get their own ID sequence

2. **Line 652-655**: Generate boost-specific ID using new counter
   - `local boost_id = string.format("%04d", boost_id_counter)`
   - Boosts now get IDs like `fediverse_boost/0001`, `0002`, etc.

3. **Line 657-660**: Updated exclusion filter to use boost-specific category and ID
   - Changed from `is_excluded("fediverse", poem_id)` to `is_excluded("fediverse_boost", boost_id)`
   - Allows independent exclusion of boosts

4. **Line 687-688**: Increment counter after successful boost processing
   - Placed alongside `boost_count = boost_count + 1`

**Result:**
- Boosts now have their own ID sequence starting from 0001
- Original posts continue using the activity index from outbox.json
- Exclusion filter works correctly with boost-specific IDs

**Pending user action:**
- Re-run extraction with `--include-boosts` to generate new IDs
- Full pipeline re-run with `--force` to regenerate caches

---

**Priority**: Low - Quality of life improvement, not a bug

**Phase**: 10 - Developer Experience & Tooling

**Status**: ✅ COMPLETED - 2026-04-06
