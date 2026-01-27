# 8-007: Scrape Fediverse Boost Content

## Status
- **Phase**: 8
- **Priority**: Low
- **Type**: Enhancement

**Status**: Open

**Blocked By**: MVP completion (similar/different navigation functional, pipeline stable, site deployable)

## Current Behavior

Fediverse boosts are displayed as simple links to the original post rather than
showing the actual content of the boosted post.

## Intended Behavior

Boosted posts should display the actual text content instead of just a link.
The implementation should:

1. Slowly/respectfully scrape the text of boosted posts
2. Anonymize any usernames in the boosted content
3. Apply the same anonymization rules used for other poem text

## Suggested Implementation Steps

1. [ ] Identify boost detection in fediverse extraction code
2. [ ] Implement rate-limited scraping for boost URLs
3. [ ] Extract text content from scraped boost pages
4. [ ] Apply existing username anonymization to scraped content
5. [ ] Update HTML generation to display boost content instead of link
6. [ ] Add caching to avoid re-scraping known boosts
7. [ ] Test with sample boosts to verify anonymization

## Related Documents

- `/scripts/extract-fediverse.lua`
- `/src/poem-extractor.lua`

## Original Note

> Reformatted from informal issue `fediverse-boosts-are-links-and-not-text` during cleanup (8-009).

## Implementation Progress

### 2026-01-21: Added run.sh checkbox option

**Note**: The boost extraction functionality itself was already implemented in Issue 6-027b. This update adds a convenient CLI/TUI option to control it.

**Changes:**

1. **`scripts/extract-fediverse.lua`**: Added CLI argument parsing
   - `--include-boosts` flag overrides config setting
   - `--no-boosts` flag explicitly disables boosts
   - Logs when boost inclusion is enabled

2. **`scripts/update`**: Pass-through for boost flag
   - Added `--include-boosts` argument parsing
   - Passes flag to extract-fediverse.lua

3. **`run.sh`**: Full integration
   - Added `INCLUDE_BOOSTS=false` config variable
   - Added `--include-boosts` CLI flag
   - Added `run_extract()` flag passing
   - Added TUI checkbox "Include Boosts" with hotkey 'b'
   - Updated help text under "Extraction Options"

**Usage:**

CLI:
```bash
./run.sh --extract --include-boosts    # Extract with boosts
./run.sh --full --include-boosts       # Full pipeline with boosts
```

TUI:
- Press 'b' to toggle "Include Boosts" checkbox in Configuration section

**Result**: 458 boost activities can now be optionally included during extraction via convenient CLI/TUI controls.

---
