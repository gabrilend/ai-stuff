# 8-011: Scrape Fediverse Boost Content

## Status
- **Phase**: 8
- **Priority**: Low
- **Type**: Enhancement

**Status**: In Progress

**Blocked By**: ~~MVP completion~~ (no longer blocked - MVP complete)

## Current Behavior

External fediverse boosts (Announce activities pointing to URIs on other servers)
display placeholder text "External post: [URI]" instead of the actual content.
458 external boosts exist, spread across 140+ unique fediverse instances.

## Intended Behavior

Boosted posts should display the actual text content instead of just a link.
The implementation should:

1. Slowly/respectfully scrape the text of boosted posts
2. Anonymize any usernames in the boosted content
3. Apply the same anonymization rules used for other poem text
4. Cache results to avoid re-scraping

## Suggested Implementation Steps

1. [x] Identify boost detection in fediverse extraction code
2. [x] Implement rate-limited scraping for boost URLs
3. [x] Extract text content from scraped boost pages (via ActivityPub JSON)
4. [x] Apply existing username anonymization to scraped content (integrated)
5. [ ] Update HTML generation to display boost content instead of link
6. [x] Add caching to avoid re-scraping known boosts
7. [ ] Test with sample boosts to verify anonymization
8. [ ] Run full scrape of 458 URIs

## Related Documents

- `/scripts/extract-fediverse.lua` — Fediverse content extraction (modified)
- `/scripts/scrape-boost-content.lua` — Boost content scraper (new)
- `/assets/boost-content-cache.json` — Cached boost content (generated)
- `/issues/completed/6-027b-add-boost-announce-activity-extraction.md` — Original boost extraction implementation

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

### 2026-01-28: Implemented Boost Content Scraper

**Analysis:**

Examined the 458 external boosts in `poems.json`:
- All 458 boosts are external (URI-only, no embedded content)
- Spread across 140+ unique fediverse instances
- Top instances: mastodon.social (83), tech.lgbt (53), mas.to (23)

**Technical Approach:**

ActivityPub servers expose post content as JSON when requested with `Accept: application/activity+json` header:
```bash
curl -H "Accept: application/activity+json" "https://mastodon.social/users/foo/statuses/123"
```

Returns JSON with `content` (HTML), `summary` (content warning), `sensitive` flag, etc.

**Implementation:**

1. **Created `scripts/scrape-boost-content.lua`**:
   - Reads external boost URIs from `poems.json`
   - Fetches each with ActivityPub JSON header
   - Rate-limited: 1s between requests, 2s extra for same domain
   - Extracts content, summary (CW), sensitive flag, published date
   - Caches results to `assets/boost-content-cache.json`
   - Supports `--dry-run`, `--force`, `--max=N` options

   Usage:
   ```bash
   lua scripts/scrape-boost-content.lua --dry-run        # Show what would be scraped
   lua scripts/scrape-boost-content.lua --max=10         # Scrape first 10
   lua scripts/scrape-boost-content.lua                  # Scrape all uncached
   lua scripts/scrape-boost-content.lua --force          # Re-scrape all
   ```

2. **Updated `scripts/extract-fediverse.lua`**:
   - Added `load_boost_content_cache()` function
   - Modified `extract_boost_content()` to check cache before falling back to placeholder
   - Cached boosts get `boost_type = "cached_external"`
   - Uncached boosts keep `boost_type = "external"` with placeholder text

**Cache Format:**

```json
{
  "metadata": {"created": "...", "last_updated": "..."},
  "entries": {
    "https://mastodon.social/...": {
      "scraped_at": "2026-01-28T...",
      "content": "<p>The actual post content</p>",
      "summary": null,
      "sensitive": false,
      "published": "2023-11-01T...",
      "attributed_to": "https://mastodon.social/users/foo"
    }
  },
  "errors": {}
}
```

**Test Results:**

- Successfully scraped 5 test URIs
- All returned valid ActivityPub JSON
- Content properly extracted and cached
- Estimated full scrape time: ~8 minutes (458 URIs × 1s delay)

**Remaining Work:**

- Run full scrape of all 458 URIs
- Test that extraction properly uses cached content
- Verify anonymization is applied to cached boost content
- Consider handling errors (deleted posts, unavailable instances)

---
