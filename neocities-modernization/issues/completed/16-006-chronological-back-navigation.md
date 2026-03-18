# Issue 16-006: Chronological Position-Aware Back Navigation

## Priority
Medium (Navigation)

## Current Behavior

Navigation between pages uses simple links without position memory. When viewing content and returning, users land at the top of the target page rather than their previous scroll position.

Similar/different pages have their own navigation context. Chronological pages don't support deep-linking to specific entries by timestamp.

## Design Constraint (Added 2026-03-18)

**NO TIMESTAMPS IN OUTPUT HTML - USE SEQUENTIAL IDs**

This webpage is intended to be read by both humans AND computers. Timestamps leak
temporal metadata and create unnecessarily complex anchor formats.

**Timestamps may be used for:**
- Pre-processing (sorting entries chronologically)
- Internal data structures during generation

**Timestamps must NOT appear in output:**
- No visible timestamp text
- No timestamp-based anchor IDs
- No temporal metadata exposed in any form

**Use sequential numbers instead:**
- Anchor format: `id="poem-1234"` or `id="entry-1234"`
- Based on poem_index or sequential position
- Clean, predictable, machine-readable
- No information leakage

## Intended Behavior

Implement sequential anchor IDs that allow:
1. Deep-linking to specific entries in chronological.html
2. "Back" buttons that return users to their exact position
3. Consistent anchor format based on poem_index or entry position

### The Navigation Problem

```
User Journey:
1. Browsing chronological.html, scrolled to poem #4625
2. Clicks on a link
3. Views the content
4. Wants to go back...

Without anchors:
  Returns to chronological.html → lands at TOP of page
  User lost, has to scroll to find where they were

With anchors:
  Returns to chronological.html#poem-4625
  Page scrolls to EXACT entry they came from
```

### Anchor Format Specification

```
Format: poem-{ID} or entry-{ID}
Example: poem-4625, entry-0042

Based on: poem_index (existing unique identifier)
```

Why this format:
- Simple and predictable
- Machine-readable (easy to parse programmatically)
- Human-readable (clear what it refers to)
- No metadata leakage (no timestamps, no dates)
- Valid HTML5 ID
- Already have poem_index in data model

### HTML Entry with Anchor

```html
<!-- chronological/page-042.html -->
<!-- Anchor based on poem_index, NOT timestamp -->
<div class="entry" id="poem-4625">
    <a href="../similar/4625-01.html">
        <!-- poem content here -->
    </a>
</div>
```

### Back Link Example

```html
<!-- From any page wanting to return to chronological position -->
<a href="../chronological/page-042.html#poem-4625" class="back">
    &larr; Back
</a>
```

### Anchor Generation (Simple)

```lua
-- {{{ local function poem_id_to_anchor
local function poem_id_to_anchor(poem_index)
    -- Input: 4625 (poem_index from data model)
    -- Output: "poem-4625"
    return string.format("poem-%d", poem_index)
end
-- }}}
```

**Note**: EXIF timestamp extraction was removed from this issue. Timestamps are
only used internally for sorting during pre-processing, never in output HTML.
See Phase 16 network media issues if timestamp extraction is needed for Android photos.

### Page Number Tracking

When generating paginated chronological pages, track which page each poem lands on:

```lua
-- {{{ local function build_pagination_index
local function build_pagination_index(poems, poems_per_page)
    local index = {
        poem_to_page = {},       -- poem_index -> page_number
        page_to_poems = {}       -- page_number -> {poem_indexes}
    }

    for i, poem in ipairs(poems) do
        local page = math.ceil(i / poems_per_page)
        local poem_index = poem.poem_index

        index.poem_to_page[poem_index] = page

        if not index.page_to_poems[page] then
            index.page_to_poems[page] = {}
        end
        table.insert(index.page_to_poems[page], poem_index)
    end

    return index
end
-- }}}
```

### URL Construction for Back Links

```lua
-- {{{ local function build_chronological_back_url
local function build_chronological_back_url(poem_index, pagination_index)
    local page = pagination_index.poem_to_page[poem_index]

    if not page then
        -- Fallback: link to first page without anchor
        return "../chronological/page-001.html"
    end

    return string.format("../chronological/page-%03d.html#poem-%d", page, poem_index)
end
-- }}}
```

### Special Case: Similar/Different Pages

The user noted:
> "if they came from a similar/different file we wouldn't know which one"

For entries accessed via similar/different pages, the back link defaults to chronological position since we can't track which similarity page brought them there.

Alternative: Could use `Referer` header or query param to track origin, but this adds complexity. Chronological position is always valid.

### CSS for Scroll Targets (Optional Enhancement)

If sticky headers are used, ensure targeted anchors remain visible:

```html
<style>
/* Offset anchor targets for sticky header */
[id^="poem-"] {
    scroll-margin-top: 80px;  /* Height of sticky nav if present */
}
</style>
```

**Note**: Current output uses pure HTML without CSS. This is only needed if
sticky navigation is added in a future phase.

## Suggested Implementation Steps

1. **Add anchor generation**
   - Use poem_index directly
   - Format: `id="poem-{poem_index}"`

2. **Add IDs to entries in chronological HTML**
   - Include `id="poem-1234"` on each poem entry
   - Update HTML template in `flat-html-generator.lua`

3. **Build pagination index**
   - Track poem_index → page_number mapping
   - Store in memory during generation

4. **Generate back URLs** (for future use)
   - Build URLs like `chronological/page-042.html#poem-4625`
   - Integrate when needed by other features

## Testing Checklist

- [ ] Anchors appear on all poems (`id="poem-XXXX"`)
- [ ] Direct URL with anchor scrolls to correct poem
- [ ] Anchor format is consistent (poem-{number})
- [ ] No timestamps visible in output HTML
- [ ] Machine-parseable anchor format works

## Related Documents

- 8-012: Implement paginated similarity chapters (COMPLETED)
- `src/flat-html-generator.lua` - Chronological HTML generation

**Deferred (Phase 16 Android/Network):**
- 16-001: Android File Server — Vision
- 16-005: Trust warning intermediate page

## Metadata

- **Status**: ✅ COMPLETED
- **Created**: 2026-02-20
- **Updated**: 2026-03-18 (changed to sequential anchors, removed timestamp dependency)
- **Completed**: 2026-03-18
- **Phase**: 16 (but implemented independently of network media)
- **Estimated Complexity**: Low
- **Dependencies**: None

## Implementation Log

**2026-03-18: COMPLETED**

Changed anchor format from category-based to simple sequential:
- Old: `poem-fediverse-0042` (leaked category metadata)
- New: `poem-4625` (just poem_index)

Files modified:
1. `src/flat-html-generator.lua`:
   - Updated `get_poem_anchor_id()` function (line 515-518) to use `poem_index`
   - Updated parallel worker hardcoded anchor (line 3573-3576) to match

The anchor is already being added to chronological HTML entries at line 2827:
```lua
content = content .. string.format('<span id="%s"></span>', anchor_id)
```

**Testing**: Regenerate HTML with `./run.sh --generate-html` to see new anchor format.
