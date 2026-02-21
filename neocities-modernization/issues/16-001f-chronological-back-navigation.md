# Issue 16-001f: Chronological Position-Aware Back Navigation

## Priority
Medium (Navigation)

## Parent Issue
16-001: Android File Server — Vision

## Current Behavior

Navigation between pages uses simple links without position memory. When viewing content and returning, users land at the top of the target page rather than their previous scroll position.

Similar/different pages have their own navigation context. Chronological pages don't support deep-linking to specific entries by timestamp.

## Intended Behavior

Implement timestamp-based anchors that allow:
1. Deep-linking to specific entries in chronological.html
2. "Back" buttons that return users to their exact position
3. Consistent anchor format based on EXIF/file timestamps

### The Navigation Problem

```
User Journey:
1. Browsing chronological.html, scrolled to entry from Feb 15
2. Clicks on a network image
3. Sees trust warning page
4. Views the image
5. Wants to go back...

Without anchors:
  Returns to chronological.html → lands at TOP of page
  User lost, has to scroll to find where they were

With anchors:
  Returns to chronological.html#2026-02-15-143022
  Page scrolls to EXACT entry they came from
```

### Anchor Format Specification

```
Format: YYYY-MM-DD-HHMMSS
Example: 2026-02-15-143022

Based on: File's timestamp (EXIF datetime or file mtime)
```

Why this format:
- Sortable lexicographically
- Human-readable
- Valid HTML5 ID (starts with digit, but valid in modern browsers)
- Matches typical photo naming conventions

### HTML Entry with Anchor

```html
<!-- chronological/page-042.html -->
<div class="entry entry-network" id="2026-02-15-143022">
    <a href="../trust/a1b2c3d4.html">
        <img src="https://192.168.0.42:8443/api/thumbnail/a1b2c3d4"
             alt="IMG_20260215_143022.jpg"
             loading="lazy" />
    </a>
    <div class="entry-meta">
        <span class="timestamp">Feb 15, 2026 2:30 PM</span>
    </div>
</div>
```

### Trust Page Back Link

```html
<!-- trust/a1b2c3d4.html -->
<a href="../chronological/page-042.html#2026-02-15-143022" class="back">
    &larr; Back
</a>
```

### EXIF Timestamp Extraction

For photos, the authoritative timestamp comes from EXIF data:

```lua
-- {{{ local function extract_exif_datetime
local function extract_exif_datetime(file_path)
    -- Use exiftool if available
    local handle = io.popen(string.format(
        'exiftool -DateTimeOriginal -s -s -s "%s" 2>/dev/null',
        file_path
    ))
    local datetime = handle:read("*l")
    handle:close()

    if datetime and datetime ~= "" then
        -- EXIF format: "2026:02:15 14:30:22"
        -- Convert to ISO: "2026-02-15T14:30:22"
        local year, month, day, hour, min, sec = datetime:match(
            "(%d+):(%d+):(%d+)%s+(%d+):(%d+):(%d+)"
        )
        if year then
            return string.format("%s-%s-%sT%s:%s:%s",
                year, month, day, hour, min, sec)
        end
    end

    -- Fallback to file modification time
    return extract_mtime(file_path)
end
-- }}}

-- {{{ local function extract_mtime
local function extract_mtime(file_path)
    local handle = io.popen(string.format(
        'stat -c %%Y "%s" 2>/dev/null',
        file_path
    ))
    local mtime = tonumber(handle:read("*l"))
    handle:close()

    if mtime then
        return os.date("%Y-%m-%dT%H:%M:%S", mtime)
    end

    return os.date("%Y-%m-%dT%H:%M:%S")  -- Now as last resort
end
-- }}}
```

### Timestamp to Anchor Conversion

```lua
-- {{{ local function timestamp_to_anchor
local function timestamp_to_anchor(iso_timestamp)
    -- Input: "2026-02-15T14:30:22"
    -- Output: "2026-02-15-143022"

    local year, month, day, hour, min, sec = iso_timestamp:match(
        "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
    )

    if not year then
        -- Handle edge case
        return "unknown-timestamp"
    end

    return string.format("%s-%s-%s-%s%s%s",
        year, month, day, hour, min, sec)
end
-- }}}

-- {{{ local function anchor_to_timestamp
local function anchor_to_timestamp(anchor)
    -- Reverse: "2026-02-15-143022" -> "2026-02-15T14:30:22"

    local year, month, day, time = anchor:match(
        "(%d+)-(%d+)-(%d+)-(%d+)"
    )

    if not year then return nil end

    local hour = time:sub(1, 2)
    local min = time:sub(3, 4)
    local sec = time:sub(5, 6)

    return string.format("%s-%s-%sT%s:%s:%s",
        year, month, day, hour, min, sec)
end
-- }}}
```

### Page Number Tracking

When generating paginated chronological pages, track which page each entry lands on:

```lua
-- {{{ local function build_pagination_index
local function build_pagination_index(entries, entries_per_page)
    local index = {
        entry_to_page = {},      -- entry_id -> page_number
        entry_to_anchor = {},    -- entry_id -> anchor string
        page_to_entries = {}     -- page_number -> {entry_ids}
    }

    for i, entry in ipairs(entries) do
        local page = math.ceil(i / entries_per_page)

        index.entry_to_page[entry.id] = page
        index.entry_to_anchor[entry.id] = timestamp_to_anchor(entry.timestamp)

        if not index.page_to_entries[page] then
            index.page_to_entries[page] = {}
        end
        table.insert(index.page_to_entries[page], entry.id)
    end

    return index
end
-- }}}
```

### URL Construction for Back Links

```lua
-- {{{ local function build_chronological_back_url
local function build_chronological_back_url(entry, pagination_index)
    local page = pagination_index.entry_to_page[entry.id]
    local anchor = pagination_index.entry_to_anchor[entry.id]

    if not page or not anchor then
        -- Fallback: link to first page without anchor
        return "../chronological/page-001.html"
    end

    return string.format("../chronological/page-%03d.html#%s", page, anchor)
end
-- }}}
```

### Special Case: Similar/Different Pages

The user noted:
> "if they came from a similar/different file we wouldn't know which one"

For entries accessed via similar/different pages, the back link defaults to chronological position since we can't track which similarity page brought them there.

Alternative: Could use `Referer` header or query param to track origin, but this adds complexity. Chronological position is always valid.

### CSS for Scroll Targets

Ensure targeted anchors are visible (not hidden under sticky headers):

```html
<style>
/* Offset anchor targets for sticky header */
.entry[id] {
    scroll-margin-top: 80px;  /* Height of sticky nav */
}

/* Highlight targeted entry briefly */
.entry:target {
    animation: highlight 2s ease-out;
}

@keyframes highlight {
    0% { background: rgba(79, 195, 247, 0.3); }
    100% { background: transparent; }
}
</style>
```

## Suggested Implementation Steps

1. **Add anchor generation**
   - Extract EXIF datetime
   - Fall back to mtime
   - Convert to anchor format

2. **Add IDs to entries**
   - Include `id="ANCHOR"` in entry divs
   - Update HTML template

3. **Build pagination index**
   - Track entry-to-page mapping
   - Track entry-to-anchor mapping

4. **Update trust page generation**
   - Pass pagination index
   - Build correct back URLs

5. **Add CSS for anchors**
   - Scroll margin for headers
   - Optional highlight animation

6. **Test deep linking**
   - Direct URL with anchor
   - Back button navigation
   - Page reload with anchor

## Testing Checklist

- [ ] Anchors appear on all entries
- [ ] Direct URL with anchor scrolls to entry
- [ ] Trust page back button works
- [ ] Entry visible (not hidden under header)
- [ ] Anchor format consistent
- [ ] EXIF extraction works for photos
- [ ] Fallback to mtime works

## Related Documents

- 16-001: Android File Server — Vision
- 16-001e: Trust warning intermediate page
- 8-012: Implement paginated similarity chapters

## Metadata

- **Status**: Open
- **Created**: 2026-02-20
- **Phase**: 16 (Network Media)
- **Parent**: 16-001
- **Estimated Complexity**: Medium
- **Dependencies**: Pagination infrastructure (Phase 8)
