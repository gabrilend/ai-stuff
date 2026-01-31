# Issue 10-015a: Migrate image-manager to sources-loader

**Priority**: Medium
**Phase**: 10 (Developer Experience & Tooling)
**Status**: Open
**Created**: 2026-01-30
**Parent Issue**: 10-015

---

## Current Behavior

`src/image-manager.lua` reads image directories from the legacy `input_sources` config:

```lua
-- Lines 44-57 of image-manager.lua
local function load_config()
    local config = unified_config.image_integration or {}
    local media_path = unified_config.input_sources and unified_config.input_sources.media_attachments_path
    if media_path then
        config.image_directories = {media_path}
    else
        config.image_directories = {"input/media_attachments"}  -- fallback
    end
    return config
end
```

This is the **only remaining dependency** on `input_sources` in the codebase, blocking full completion of 10-015.

---

## Intended Behavior

`image-manager.lua` should use `sources-loader` to get image directories from the unified `sources.images` config:

```lua
sources = {
    images = {
        enabled = true,
        directories = {
            { name = "my-art", path = "input/media_attachments/my-art" },
            { name = "things-I-almost-posted", path = "input/media_attachments/things-i-almost-posted" },
            { name = "poem-pictures", path = "input/media_attachments/poem-pictures" },
        },
        supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"},
        max_file_size_mb = 100,
    },
}
```

Benefits:
1. **No fallbacks** - Errors clearly if config is missing (follows "no fallbacks" design principle)
2. **Multi-directory support** - Already supports multiple named directories
3. **Unified config** - All source paths in one place
4. **Enables removal** of legacy `input_sources` section

---

## Suggested Implementation Steps

1. [x] Add sources-loader require to image-manager.lua
2. [x] Update load_config() to use sources-loader.get_directories("images")
3. [x] Use sources.images settings for supported_formats and max_file_size_mb
4. [x] Remove fallback logic - error if sources.images not configured
5. [x] Test image discovery with updated config
6. [x] Remove input_sources section from config.lua

---

## Related Documents

- `/issues/10-015-unified-input-sources-config.md` - Parent issue
- `/src/image-manager.lua` - Image cataloging system
- `/libs/sources-loader.lua` - Sources config reader module
- `/config.lua` - Unified configuration

---

## Implementation Notes (2026-01-30)

### Files Modified

- `src/image-manager.lua` - Added sources-loader require, rewrote load_config() to use sources-loader
- `config.lua` - Removed `input_sources` section, added fediverse-media directory to sources.images
- `scripts/extract-fediverse.lua` - Removed fallback to input_sources, errors if sources.fediverse not configured
- `scripts/extract-messages.lua` - Removed fallback to input_sources, errors if sources.messages not configured
- `scripts/extract-notes.lua` - Removed fallback to input_sources, errors if sources.notes not configured

### Key Changes

1. **image-manager.lua load_config()**:
   - Now uses `sources_loader.get_source("images")` and `sources_loader.get_directories("images")`
   - Errors clearly if sources.images not configured (no fallback)
   - Reads supported_formats and max_file_size_mb from sources.images

2. **config.lua sources.images**:
   - Added `fediverse-media` directory pointing to `input/media_attachments/files`
   - Marked user image directories (my-art, things-i-almost-posted, poem-pictures) as optional

3. **All extractors**:
   - Removed `config.input_sources.*` fallback code
   - Now error with clear message if sources section not configured
   - Follow "no fallbacks" design principle

### Design Decisions

1. **No fallbacks**: Following user's "no fallbacks" preference, all scripts now error clearly if sources config is missing rather than silently using defaults
2. **Optional directories**: User image directories marked as optional (warn on missing, don't error)
3. **Fediverse media path**: Added `input/media_attachments/files` to match actual Mastodon archive structure

**ISSUE STATUS: ✅ COMPLETE**
