# 403: Implement Chapter Upload

## Status
- [ ] Not started

## Current Behavior

No chapter upload mechanism exists.

## Intended Behavior

A Lua module that:
- Adds chapters to an existing work
- Updates existing chapters with new content
- Handles chapter ordering
- Supports chapter titles and notes
- Respects rate limits between uploads

## Suggested Implementation Steps

1. Extend src/ao3-upload.lua with chapter functions
2. Implement "add chapter" form submission
3. Implement "edit chapter" form submission
4. Build chapter content chunking for large files
5. Add delay between chapter uploads (rate limiting)
6. Track chapter IDs for updates

## Related Documents

- 402-implement-work-creation.md
- 104-document-rate-limits-tos.md
- 301-design-chapter-organization.md

## Notes

Many chapters = many requests. Must be respectful of AO3's servers. Consider: batch upload or incremental?
