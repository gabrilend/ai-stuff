# 8-007: Scrape Fediverse Boost Content

## Status
- **Phase**: 8
- **Priority**: Low
- **Type**: Enhancement

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

---
