# 103: Research Work Creation Form Structure

## Status
- [ ] Not started

## Current Behavior

Unknown. Need to map the form fields required to create a new work on AO3.

## Intended Behavior

Complete documentation of:
- Form action URL and method
- Required fields (title, rating, warnings, fandom, etc.)
- Optional fields (summary, notes, tags)
- Chapter content submission format
- Multi-chapter work creation flow
- Work update/edit form differences

## Suggested Implementation Steps

1. Navigate to AO3 "Post New Work" page while authenticated
2. Inspect form HTML structure
3. Document all input fields, names, and types
4. Identify required vs optional fields
5. Test minimal work creation manually
6. Document the complete field mapping

## Related Documents

- docs/upload-protocol.md
- 102-research-ao3-authentication.md

## Notes

For code archives, likely tags:
- Fandom: Original Work
- Category: Gen (no relationships)
- Rating: General Audiences
- Additional Tags: Software, Source Code, Lua, Game Development

Consider: what's the appropriate "archive warning" for code?
