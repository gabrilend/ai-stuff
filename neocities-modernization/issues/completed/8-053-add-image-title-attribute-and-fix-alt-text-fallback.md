# Issue 8-053: Add Image Title Attribute and Fix Alt-Text Fallback

## Priority
Medium-High (accessibility)

## Current Behavior

Images rendered in the generated HTML pages have two accessibility problems:

### Problem 1: No mouse-over tooltip text

All `<img>` tags across the codebase use the `alt` attribute but lack the `title` attribute. The `alt` attribute is read by screen readers and shown when images fail to load, but it does **not** display as a tooltip on mouse hover. The `title` attribute does. Currently, hovering over any image shows nothing — sighted users cannot preview the alt-text without inspecting the HTML.

Current output:
```html
<img src="media/be3cff76bb9cdc11.png" alt="A sketch of a cat sleeping on a keyboard" loading="lazy">
```

Expected output:
```html
<img src="media/be3cff76bb9cdc11.png" alt="A sketch of a cat sleeping on a keyboard" title="A sketch of a cat sleeping on a keyboard" loading="lazy">
```

### Problem 2: Incomplete 9-012 fix — similar/different pages miss alt-text

Issue 9-012 fixed alt-text for chronological pages (Location 1) by adding the `attachment.alt_text` fallback. However, one of the effil worker rendering paths (Location 2) was **not updated** and only checks `attachment.description`, which is not present in the extracted data. This causes images on similar/different pages rendered through `render_attachments` to fall back to the generic "Image attachment" string even when real alt-text exists.

**Location 2** (`flat-html-generator.lua:3253`):
```lua
local alt_text = attachment.description or "Image attachment"
-- ❌ Missing: attachment.alt_text fallback
```

**Location 1** (correctly fixed by 9-012, `flat-html-generator.lua:1266`):
```lua
local alt_text = attachment.description or attachment.alt_text or "Image attachment"
-- ✅ Has attachment.alt_text fallback
```

**Location 3** (`flat-html-generator.lua:3294`):
```lua
local alt_text = attachment.description or attachment.alt_text or "Image attachment"
-- ✅ Has attachment.alt_text fallback
```

### Problem 3: Newlines in alt-text can break HTML attributes

Some ActivityPub alt-text descriptions contain newline characters. When inserted into an HTML attribute like `alt="..."`, a literal newline doesn't technically break the attribute (HTML allows it), but it can cause unexpected rendering in some parsers and makes the HTML harder to inspect. These should be normalized to spaces.

## Intended Behavior

1. **All `<img>` tags include both `alt` and `title` attributes** with the same alt-text content. This provides:
   - Screen reader accessibility (`alt`)
   - Mouse-over tooltip for sighted users (`title`)
   - Fallback text when images fail to load (`alt`)

2. **All three rendering locations use the same fallback chain**: `attachment.description or attachment.alt_text or "Image attachment"`

3. **Newlines in alt-text are replaced with spaces** before insertion into HTML attributes, producing clean single-line attribute values.

### Affected Rendering Locations

| # | File | Line | Context | `title` | `alt_text` fallback |
|---|------|------|---------|---------|---------------------|
| 1 | `src/flat-html-generator.lua` | ~1266-1286 | Chronological page | ❌ Missing | ✅ Correct |
| 2 | `src/flat-html-generator.lua` | ~3252-3262 | Effil worker `render_attachments` | ❌ Missing | ❌ Missing `alt_text` |
| 3 | `src/flat-html-generator.lua` | ~3294-3302 | Effil worker main loop | ❌ Missing | ✅ Correct |

After this fix, all three should have: `title` ✅, `alt_text` fallback ✅, newline normalization ✅.

## Suggested Implementation Steps

1. **Fix Location 2** (`flat-html-generator.lua:~3253`):
   Change:
   ```lua
   local alt_text = attachment.description or "Image attachment"
   ```
   To:
   ```lua
   local alt_text = attachment.description or attachment.alt_text or "Image attachment"
   ```

2. **Add newline normalization** to all three locations, after the alt-text assignment:
   ```lua
   -- Normalize newlines to spaces for clean HTML attributes
   alt_text = alt_text:gsub("\n", " "):gsub("\r", "")
   ```

3. **Add `title` attribute** to all `<img>` format strings in all three locations. Change:
   ```lua
   '<img src="%s" alt="%s" loading="lazy" ...'
   ```
   To:
   ```lua
   '<img src="%s" alt="%s" title="%s" loading="lazy" ...'
   ```
   And add `alt_text` as an additional format argument (it appears twice — once for `alt`, once for `title`).

4. **Verify the fix** by regenerating a few pages and checking:
   - Chronological page: hover over an image, confirm tooltip appears
   - Similar page: hover over an image, confirm tooltip shows real alt-text (not "Image attachment")
   - Different page: same check
   - Image with long alt-text: confirm no newlines in the attribute value
   - Image with no alt-text: confirm "Image attachment" fallback still works

5. **Spot-check screen reader behavior** (optional): Use browser accessibility inspector to verify the `alt` attribute is announced correctly.

## Edge Cases

1. **Images without alt-text**: 40 of 545 attachments (7.3%) have no user-provided alt-text. These correctly fall back to "Image attachment" — this is the best we can do without AI-generated descriptions.

2. **Alt-text with special characters**: The existing `alt_text:gsub('"', '&quot;')` escaping handles quotes. Newline normalization (step 2) handles line breaks. No other special characters need attention — `<` and `>` in alt-text are safe inside quoted HTML attributes.

3. **Very long alt-text**: Some ActivityPub alt-text descriptions are paragraph-length. The `title` tooltip will show this as a long hover popup — this is acceptable and arguably desirable, since the user explicitly wrote that description for their image.

4. **Effil thread serialization**: Location 2 and 3 run inside effil worker threads. String operations like `gsub` work normally in effil threads — no special handling needed.

## Related Documents

- `src/flat-html-generator.lua` — All three `<img>` rendering locations
- `scripts/extract-fediverse.lua:~440-478` — Where `alt_text` is extracted from ActivityPub `name` field
- `issues/completed/9-012-use-activitypub-description-field-for-image-alt-text.md` — Previous partial fix (chronological only)
- `issues/completed/8-005-integrate-images-into-html-output.md` — Image integration system
- `issues/completed/9-011-display-content-warnings-from-activitypub.md` — Related ActivityPub metadata extraction

## Metadata

- **Status**: Completed
- **Created**: 2026-01-26
- **Completed**: 2026-01-26
- **Phase**: 8 (Website Completion)
- **Estimated Complexity**: Very Low
- **Dependencies**: None
- **Affects**: All generated HTML pages with images (chronological, similar, different)
- **Accessibility Impact**: Screen readers + mouse-over tooltips for ~505 images
