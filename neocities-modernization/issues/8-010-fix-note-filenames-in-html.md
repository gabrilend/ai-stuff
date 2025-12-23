# 8-010: Fix Note Filenames in Generated HTML

## Status
- **Phase**: 8
- **Priority**: Medium
- **Type**: Bug Fix
- **Status**: COMPLETED
- **Completed**: 2025-12-23

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

## Implementation Steps

1. [x] Locate the HTML generation code that formats note filenames
2. [x] Modify to preserve original note filename (strip extension only)
3. [x] Update fediverse/message display to use numbered format without extension
4. [x] Test generated HTML to verify proper display
5. [x] Update relevant documentation if format changed

## Implementation Details (2025-12-23)

### Solution

Created helper function `get_poem_display_filename(poem)` in `flat-html-generator.lua`:

```lua
-- For notes: uses metadata.source_file (the original filename)
-- For fediverse/messages: uses the numeric ID
-- All categories: no .txt extension
```

### Files Modified

- `src/flat-html-generator.lua`:
  - Added `get_poem_display_filename()` helper function (lines 887-905)
  - Updated 4 locations that generate file headers to use the helper

### Before/After

| Category | Before | After |
|----------|--------|-------|
| fediverse | `-> file: fediverse/1.txt` | `-> file: fediverse/1` |
| messages | `-> file: messages/42.txt` | `-> file: messages/42` |
| notes | `-> file: notes/48.txt` | `-> file: notes/what-a-lame-movie` |

### Verification

```
fediverse: -> file: fediverse/1
messages: -> file: messages/1
notes: -> file: notes/what-a-lame-movie
PASS: No .txt extensions found in file headers
PASS: Note filename is descriptive
```

## Related Documents

- `/src/flat-html-generator.lua`
- `/src/html-generator/template-engine.lua`

## Original Note

> Reformatted from informal issue `notes-lack-names-in-generated-html.md` during cleanup (8-009).

---
