# 8-006: Fix Note Filenames in Generated HTML

## Status
- **Phase**: 8
- **Priority**: Medium
- **Type**: Bug Fix

## Current Behavior

Notes inserted into the generated HTML pages display stripped filenames with only numeric IDs:

```
-> file: notes/48.txt
```

In addition, fediverse posts and messages incorrectly display the `.txt` extension.

## Intended Behavior

Notes should display their actual filenames without the extension:

```
-> file: notes/name-of-poem
```

Fediverse posts and messages should display numbered identifiers without `.txt` extension.

## Suggested Implementation Steps

1. [ ] Locate the HTML generation code that formats note filenames
2. [ ] Modify to preserve original note filename (strip extension only)
3. [ ] Update fediverse/message display to use numbered format without extension
4. [ ] Test generated HTML to verify proper display
5. [ ] Update relevant documentation if format changed

## Related Documents

- `/src/flat-html-generator.lua`
- `/src/html-generator/template-engine.lua`

## Original Note

> Reformatted from informal issue `notes-lack-names-in-generated-html.md` during cleanup (8-009).

---
