# 502: Implement Deprecation Workflow

## Status
- [ ] Not started

## Current Behavior

No deprecation mechanism exists.

## Intended Behavior

A workflow that:
- Marks old versions as deprecated before uploading new
- Optionally deletes old versions after successful new upload
- Updates old work summary to point to new version
- Maintains version history links
- Supports "replace" vs "archive alongside" modes

## Suggested Implementation Steps

1. Create src/deprecation.lua
2. Implement work edit to add deprecation notice
3. Implement work deletion (with confirmation)
4. Build workflow: deprecate -> upload new -> verify -> delete old
5. Add rollback if new upload fails
6. Create "archive mode" that keeps old versions linked

## Deprecation Notice Template

```
[DEPRECATED] This version has been superseded.
Current version: [link to new work]
Archived on: [date]
```

## Related Documents

- 501-implement-version-tracking.md
- 402-implement-work-creation.md

## Notes

Deletion is destructive. Consider: keep old versions as a paper trail? AO3 supports series - maybe version as series entries?
