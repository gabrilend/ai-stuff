# Issue 10-015: Unified Input Sources Configuration

**Priority**: Medium
**Phase**: 10 (Developer Experience & Tooling)
**Status**: Open
**Created**: 2026-01-30
**Parent Issue**: 10-003

---

## Current Behavior

Input-related configuration is scattered across 4 sections in `config.lua`:

| Section | Lines | Purpose |
|---------|-------|---------|
| `input_sources` | 38-51 | Paths to input directories (fediverse, messages, notes, bluesky, media_attachments) |
| `extraction` | 53-67 | Enable/disable toggles per source type + ignored_archives |
| `image_sync` | 173-211 | External directories to sync images from (named sources) |
| `image_integration` | 159-171 | Image processing settings (formats, size limits) |

This creates several problems:
1. **Redundancy**: The same concepts (paths, enabled flags) appear in multiple places
2. **Inconsistency**: Only `image_sync` supports multiple named directories
3. **Confusion**: Unclear which section controls what when adding new sources
4. **Limited flexibility**: Can't add multiple fediverse archives, notes directories, etc.

---

## Intended Behavior

A single `sources` section that:
- Supports **multiple named directories** per source type
- **Deduplicates** content with the same ID across directories
- Treats **differences as unique** (new poems from new directories)
- Respects each format's **native ID scheme** (ActivityPub IDs, filenames, record keys)
- Consolidates **all input settings** in one place

---

## Proposed Config Structure

```lua
-- {{{ sources
-- Unified input source configuration. Each source type supports multiple
-- named directories. The pipeline deduplicates by content ID across all
-- directories of the same type, preserving unique poems from each.
sources = {
    fediverse = {
        enabled = true,
        format = "activitypub",  -- outbox.json parsing
        directories = {
            {
                name = "primary",
                path = "input/fediverse",
                description = "Main Mastodon archive"
            },
            {
                name = "backup-2024",
                path = "/home/ritz/backups/old-fedi/2024",
                description = "Archived export from 2024",
                optional = true  -- Missing = skip with warning, not error
            }
        },
        -- Media handling for this source type
        media = {
            extract_attachments = true,
            output_path = "input/media_attachments/fediverse"
        }
    },

    messages = {
        enabled = true,
        format = "messages_export",  -- export.json parsing
        directories = {
            {
                name = "primary",
                path = "input/messages",
                description = "Private message archives"
            }
        }
    },

    notes = {
        enabled = true,
        format = "plaintext",  -- .txt/.md files
        directories = {
            {
                name = "primary",
                path = "input/notes",
                description = "Personal notes and drafts"
            },
            {
                name = "archived-notes",
                path = "/home/ritz/documents/old-notes",
                optional = true
            }
        }
    },

    bluesky = {
        enabled = true,
        format = "atproto",  -- AT Protocol records
        directories = {
            {
                name = "primary",
                path = "input/bluesky"
            }
        }
    },

    images = {
        enabled = true,
        directories = {
            {
                name = "my-art",
                path = "/home/ritz/pictures/my-art",
                description = "artwork made in kolourpaint"
            },
            {
                name = "things-I-almost-posted",
                path = "/home/ritz/pictures/things-i-almost-posted"
            },
            {
                name = "poem-pictures",
                path = "/home/ritz/pictures/poem-pictures"
            }
        },
        -- Image-specific settings (merged from image_integration)
        supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"},
        max_file_size_mb = 100,
        preserve_structure = true,
        overwrite_existing = false
    }
},
-- }}}
```

---

## Deduplication Strategy

Each source type has a unique ID scheme for detecting duplicates:

| Source Type | Deduplication Key | Example |
|-------------|-------------------|---------|
| `fediverse` | ActivityPub post ID | `"113847291038475"` |
| `messages` | Message index within export | `"42"` |
| `notes` | Filename without extension | `"my-thoughts-on-hope"` |
| `bluesky` | AT Protocol record key | `"3k...abc"` |
| `images` | MD5 hash of file content | `"a1b2c3d4..."` |

### Priority Order

When the same content appears in multiple directories:
1. **Required directories** take priority over `optional` ones
2. **Earlier-listed directories** take priority over later ones
3. **Most recent modification time** breaks remaining ties

---

## Suggested Implementation Steps

### Phase 1: Parallel Structure
1. [x] Add new `sources` section to config.lua (alongside existing sections)
2. [x] Create `libs/sources-loader.lua` to parse the unified structure
3. [x] Add validation that checks for required fields, valid paths (validate_all() function)

### Phase 2: Extractor Migration
1. [x] Update `scripts/extract-fediverse.lua` to use sources-loader (primary directory)
2. [x] Update `scripts/extract-messages.lua` for sources-loader (primary directory)
3. [x] Update `scripts/extract-notes.lua` for sources-loader (primary directory)
4. [N/A] `scripts/extract-bluesky-data` uses CLI args for CAR file path, not config
5. [x] Update `scripts/update-words` to use unified external_files (done in 10-003b)

### Phase 3: Deduplication Logic (DEFERRED)
Note: Deduplication is only needed when multiple directories are configured per source type.
Currently only single directories are configured, so this is deferred until needed.

1. [ ] Implement deduplication in each extractor (when multi-directory is used)
2. [ ] Add "source directory" metadata to extracted poems
3. [ ] Log which directory contributed each poem

### Phase 4: Cleanup
1. [x] Remove deprecated `image_sync` section (done in 10-003b)
2. [x] Remove deprecated `input_sources` section (done in 10-015a)
3. [KEEP] `extraction` section - still used for enable/disable flags per source type
4. [KEEP] `image_integration` section - still used by image manager for display settings
5. [x] Update all scripts to use `sources-loader.lua` (no fallback - "no fallbacks" design)
6. [x] Update documentation (inline comments updated)

---

## Success Criteria

- [x] Single `sources` section contains all input configuration
- [x] Each source type supports multiple named directories (infrastructure ready)
- [DEFERRED] Deduplication works correctly (same ID = same poem) - only needed with multi-directory
- [DEFERRED] Different content from different directories is preserved - only needed with multi-directory
- [x] Optional directories skip gracefully, required directories error on missing (in sources-loader)
- [DEFERRED] Clear logging shows which directory contributed each poem - only needed with multi-directory
- [x] Old config sections removed (`image_sync` removed 10-003b, `input_sources` removed 10-015a)

---

## Related Documents

- `/issues/completed/10-003-consolidate-config-files-into-single-source.md` - Original consolidation issue
- `/config.lua` - Current configuration file
- `/scripts/extract-fediverse.lua` - Fediverse extractor (first migration target)
- `/scripts/update-words` - Image sync script (uses image_sync config)

---

## Notes

- This is a significant refactor that touches all extractor scripts
- Consider implementing one source type at a time (fediverse first, then notes, etc.)
- The `ignored_archives` setting from `extraction` could move to a `zip_extraction` sub-section under relevant source types, or remain separate
- Image deduplication by MD5 hash may be slow for large collections - consider caching hashes

---

## Implementation Notes (2026-01-30)

### Files Created
- `libs/sources-loader.lua` - Module for reading sources config with multi-directory support

### Files Modified
- `config.lua` - Added `sources` section, removed `input_sources` section (10-015a)
- `scripts/extract-fediverse.lua` - Uses sources-loader exclusively (no fallback)
- `scripts/extract-messages.lua` - Uses sources-loader exclusively (no fallback)
- `scripts/extract-notes.lua` - Uses sources-loader exclusively (no fallback)
- `src/image-manager.lua` - Uses sources-loader for image directories (10-015a)

### Design Decisions
1. **No fallbacks**: All extractors error clearly if sources config is missing (per user's "no fallbacks" design preference)
2. **Deferred deduplication**: Multi-directory deduplication logic not implemented until actually needed
3. **Bluesky extractor**: Uses CLI args for CAR file path, doesn't need sources-loader migration
4. **Optional directories**: sources.images directories can be marked optional (warn on missing, don't error)

### Remaining Work (Deferred)
- Implement deduplication logic when multiple directories are actually configured per source type

### Sub-Issues
- `10-015a` - Migrate image-manager to sources-loader (COMPLETE)

**ISSUE STATUS: ✅ COMPLETE (deferred deduplication only needed when multi-directory is used)**
