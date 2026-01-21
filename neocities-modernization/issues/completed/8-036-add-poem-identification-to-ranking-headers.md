# Issue 8-036: Add Poem Identification to Ranking Headers

## Priority
Low

## Current Behavior

On similar/ and different/ pages, ranked poems are displayed with minimal identification:

```
--- #1 ---
[poem content]

--- #2 ---
[poem content]

--- #3 ---
[poem content]
```

The ranking header (generated at `flat-html-generator.lua:2826`) only shows the ranking number:
```lua
table.insert(html_parts, string.format("--- #%d ---\n", i))
```

Users cannot easily identify which poem they're looking at without reading the content itself. There's no indication of the poem's source, category, or original filename/identifier.

## Intended Behavior

Enhance ranking headers to display the poem's full source path/identifier alongside the ranking number:

### Notes Category:
```
--- #3 /home/ritz/notes/semblance-of-remembrance ---
[poem content]
```

### Fediverse Category:
```
--- #5 tech.lgbt/@gabrilend/123456789 ---
[poem content]
```
(Format: `{instance}/@{username}/{post_id}`)

### Messages Category:
```
--- #7 messages-to-myself/1234 ---
[poem content]
```

### Bluesky Category:
```
--- #2 bluesky#1234 ---
[poem content]
```

### Visual Format:
The path should be visually distinct but not overwhelming. Options:
1. Same line as ranking: `--- #3 /home/ritz/notes/poem-name ---`
2. Two-line format:
   ```
   --- #3 ---
       /home/ritz/notes/poem-name
   ```

## Data Sources

The required data is already available in the poem data model (`assets/poems.json`):

### Notes:
```lua
poem.category == "notes"
poem.metadata.source_file  -- e.g., "semblance-of-remembrance"
-- Construct: "/home/ritz/notes/" .. poem.metadata.source_file
```

### Fediverse:
```lua
poem.category == "fediverse"
poem.id  -- per-category post ID
-- Note: May need to extract instance/username from metadata or filepath
-- Check if metadata contains ActivityPub source URL
```

### Messages:
```lua
poem.category == "messages"
poem.id  -- per-category message ID
-- Construct: "messages-to-myself/" .. poem.id
```

### Bluesky:
```lua
poem.category == "bluesky"
poem.id  -- per-category post ID
-- Construct: "bluesky#" .. poem.id
```

## Suggested Implementation Steps

1. **Investigate fediverse metadata structure**:
   - Check `assets/poems.json` for fediverse entries
   - Determine if ActivityPub source URL (instance, username) is stored
   - If not available, may need to extract from content or add to extraction pipeline

2. **Create helper function** `get_poem_source_path(poem)`:
   ```lua
   -- {{{ get_poem_source_path
   local function get_poem_source_path(poem)
       if poem.category == "notes" then
           return "/home/ritz/notes/" .. (poem.metadata.source_file or poem.id)
       elseif poem.category == "fediverse" then
           -- TODO: Determine instance/username format
           return "fediverse/" .. poem.id
       elseif poem.category == "messages" then
           return "messages-to-myself/" .. poem.id
       elseif poem.category == "bluesky" then
           return "bluesky#" .. poem.id
       else
           return poem.category .. "/" .. poem.id
       end
   end
   -- }}}
   ```

3. **Modify ranking header generation** (line ~2826):
   - Pass poem data to the header generation
   - Call `get_poem_source_path()` for each ranked poem
   - Format: `string.format("--- #%d %s ---\n", i, source_path)`

4. **Handle line length considerations**:
   - Some paths may be long (notes with long filenames)
   - Consider truncation or wrapping strategy
   - Maximum reasonable header width: ~80 characters to match content width

5. **Test with all categories**:
   - Generate sample similar/different pages for each category
   - Verify paths are correct and readable
   - Check that formatting doesn't break page structure

6. **Update golden poem handling** if needed:
   - Golden poems have special formatting
   - Ensure source path appears correctly for golden poems too

## Technical Notes

### Poem Categories in Dataset:
Based on `assets/poems.json`, the categories are:
- `notes` - Personal notes from `/home/ritz/notes/`
- `fediverse` - ActivityPub posts (Mastodon, etc.)
- `messages` - Messages to self
- `bluesky` - Bluesky social posts

### Fediverse URL Reconstruction:
If the full ActivityPub URL isn't stored, it may need to be reconstructed from:
- Instance domain (e.g., "tech.lgbt")
- Username (e.g., "gabrilend")
- Post ID

Check `src/extract-fediverse-from-archive.lua` or similar extraction scripts to understand what metadata is preserved.

### Line Length Budget:
```
--- #XXX ------------------------------------------------------------ ---
        ^                                                              ^
        5 chars for rank                           ~60 chars for path
```
Total: ~70-75 chars for path portion (leaving room for rank and delimiters)

## Related Documents

- `src/flat-html-generator.lua` - Primary implementation file (line 2826 for header generation)
- `assets/poems.json` - Poem data with category and metadata
- `issues/completed/8-006-fix-golden-poem-box-drawing-format.md` - Golden poem formatting
- `issues/8-035-colorize-nav-boxes-with-progress-bar.md` - Related visual enhancement

## Implementation Progress

### 2026-01-21: Implemented

**Investigation findings:**
- Fediverse poems do NOT store ActivityPub URLs, only numeric IDs
- Notes store original filenames in `metadata.source_file`
- Messages and Bluesky only have numeric IDs

**Changes made:**

1. **`src/flat-html-generator.lua`** (effil worker thread):
   - Added `get_source_path()` helper function (lines 2753-2773)
   - Formats paths based on category:
     - Notes: `notes/source_file` (e.g., "notes/what-a-lame-movie")
     - Bluesky: `bluesky#N` (e.g., "bluesky#42")
     - Fediverse: `fediverse/N` (e.g., "fediverse/1234")
     - Messages: `messages/N` (e.g., "messages/567")
   - Updated ranking header generation (line 3092) to include source path:
     ```lua
     string.format("--- #%d %s ---\n", i, source_path)
     ```

**Example output:**
```
--- #1 notes/what-a-lame-movie ---
[poem content]

--- #2 fediverse/1234 ---
[poem content]

--- #3 bluesky#42 ---
[poem content]
```

**Design decisions:**
- Single-line format chosen (cleaner, less vertical space)
- No truncation implemented (note filenames fit within 80-char width)
- Category prefix provides quick visual identification

## Metadata

- **Status**: ✅ Complete
- **Created**: 2026-01-19
- **Completed**: 2026-01-21
- **Phase**: 8 (Website Completion / HTML Enhancement)
- **Estimated Complexity**: Low-Medium (straightforward string formatting, main work is investigating fediverse metadata)
- **Dependencies**: None (standalone visual enhancement)

## Resolved Questions

1. **Fediverse URL format**: Only numeric IDs available. Using `fediverse/N` format.
2. **Display preference**: Single-line format chosen for cleaner appearance.
3. **Truncation strategy**: Not needed - filenames fit comfortably.
