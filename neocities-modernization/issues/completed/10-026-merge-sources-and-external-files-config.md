# Issue 10-026: Merge sources and external_files Config Sections

**Status: COMPLETED** (2026-02-18)

## Summary

Merged the `sources` and `external_files` config sections into a unified structure.
External sync info is now embedded directly in each source's directory entries.

## Implementation

### Changes Made

1. **Extended `libs/sources-loader.lua`**:
   - Added `get_directories_with_external()` - returns directories with external sync info
   - Added `get_archives()` - returns ZIP archive entries for a source type
   - Added `get_all_external_syncs()` - collects ALL sync entries in external_files-compatible format
   - Added `has_external_syncs()` - check if any sources have external sync config

2. **Updated `libs/external-sync.lua`**:
   - Now reads from sources-loader first via `get_all_external_syncs()`
   - Falls back to `config.external_files` for backward compatibility (if sources have no entries)
   - Auto-detects archive files by `.zip` extension

3. **Migrated `config.lua`**:
   - Added `external = { source = "..." }` to 7 directory entries
   - Added `archives = [...]` to fediverse and messages sources
   - Deprecated `external_files` section (now empty array with documentation)
   - Fixed syntax error (missing comma on line 122)
   - Fixed path inconsistency: fediverse-stars now correctly points to where sync goes

### Unified Structure (Final)

```lua
sources = {
    fediverse = {
        directories = { ... },
        archives = {
            { name = "fediverse-zip", source = "/path/to.zip", extract_to = "input" }
        }
    },
    images = {
        directories = {
            {
                name = "my-art",
                path = "input/media_attachments/my-art",
                external = { source = "/home/ritz/pictures/my-art" }
            }
        }
    }
}
```

### Testing

Verified both loaders return all 9 expected sync entries:
- 5 image directories (rsync)
- 2 ZIP archives (fediverse, messages)
- 2 directory syncs (notes, bluesky)

---

## Original Analysis

## Current Behavior

The config.lua file has two similar but separate sections for managing input data:

### `sources` (lines 42-134)
Defines **where extractors read from** after data is synced:
```lua
sources = {
    images = {
        enabled = true,
        directories = {
            {
                name = "my-art",
                path = "input/media_attachments/my-art",
                description = "artwork made in kolourpaint",
                optional = false
            },
            -- ...
        },
        supported_formats = {"png", "jpg", ...},
    },
    fediverse = { ... },
    messages = { ... },
    -- ...
}
```
- Used by: `libs/sources-loader.lua`, extractors
- Contains: format metadata, enabled flags, directory listings
- Paths are relative to project root

### `external_files` (lines 136-189)
Defines **where to sync data from** before pipeline runs:
```lua
external_files = {
    {
        name = "my-art",
        source = "/home/ritz/pictures/my-art",
        destination = "media_attachments/my-art",
    },
    {
        name = "fediverse-zip",
        source = "/home/ritz/backups/fediverse/backups/most-recent-29.zip",
        destination = "",
    },
    -- ...
}
```
- Used by: `libs/external-sync.lua`
- Contains: external paths, destination paths
- Destinations relative to `input/`

## The Problem

1. **Conceptual Overlap**: Both describe "named collections of input data"
2. **Redundant Names**: `my-art`, `poem-pictures`, etc. appear in BOTH sections
3. **Path Duplication**: The destination in `external_files` corresponds to the path in `sources`
4. **Maintenance Burden**: Adding a new image source requires edits in TWO places
5. **Config Comment Acknowledges This**: Line 141-142 says "NOTE: image_sync.sources will eventually be merged here. For now, both exist."

### Current Data Flow
```
external_files.source  →  sync  →  external_files.destination
                                            ↓
                          (same as)  sources.directories[].path
                                            ↓
                                     extractors read
```

## Intended Behavior

A unified data structure where each source knows:
- Where to sync FROM (optional external location)
- Where it lives (project-relative path)
- All metadata (format, enabled, etc.)

### Proposed Unified Structure
```lua
sources = {
    images = {
        enabled = true,
        directories = {
            {
                name = "my-art",
                path = "input/media_attachments/my-art",
                description = "artwork made in kolourpaint",
                optional = false,
                -- NEW: external sync info (nil if no sync needed)
                external = {
                    source = "/home/ritz/pictures/my-art",
                    -- 'destination' removed: path already defines it
                },
            },
            {
                name = "fediverse-media",
                path = "input/media_attachments/files",
                description = "Mastodon/ActivityPub media attachments",
                optional = true,
                external = nil,  -- No sync needed, comes from zip extraction
            },
        },
        supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"},
    },
    fediverse = {
        enabled = true,
        format = "activitypub",
        directories = {
            {
                name = "primary",
                path = "input/fediverse",
            },
        },
        -- NEW: archive-based sources (zips)
        archives = {
            {
                name = "fediverse-zip",
                source = "/home/ritz/backups/fediverse/backups/most-recent-29.zip",
                extract_to = "input/fediverse",
            },
        },
    },
    -- ...
}
```

### Design Decisions to Make

1. **Archives vs Directories**: ZIP files behave differently (extract once vs rsync). Should they be:
   - Mixed into `directories` with a `type = "archive"` flag?
   - Separate `archives` array per source?
   - Global `archives` section (current approach with external_files)?

2. **Path Derivation**: Should `external.destination` be derived from `path` automatically, or explicit?

3. **Backward Compatibility**: Deprecation period for `external_files` section?

## Suggested Implementation Steps

### Phase 1: Design Validation
- [x] Review all `external_files` entries and map to corresponding `sources` entries
- [x] Identify entries that don't fit the unified model (e.g., zip files with empty destination)
- [x] Design the final schema and document it

### Phase 2: Extend sources-loader.lua
- [x] Add support for `external` field in directory entries
- [x] Add `get_external_sources(source_type)` function (named `get_all_external_syncs`)
- [x] Add `get_archives(source_type)` function (if separate)

### Phase 3: Migrate external-sync.lua
- [x] Read sync info from `sources` via sources-loader
- [x] Handle both directory sync and archive extraction
- [x] Deprecate direct reading of `external_files` section

### Phase 4: Migrate Config
- [x] Move all `external_files` entries into their corresponding `sources` entries
- [x] Add deprecation warning if `external_files` section still exists
- [x] Update config.lua comments and documentation

### Phase 5: Cleanup
- [x] Remove `external_files` section from config.lua (emptied, kept for reference)
- [x] Backward compatibility code kept for safety (falls back if sources have no entries)
- [ ] Update 10-019 documentation issue (deferred - separate task)

## Analysis: Current external_files Mapping

| external_files name | Corresponds to sources |
|---------------------|----------------------|
| my-art | sources.images.directories[my-art] |
| things-I-almost-posted | sources.images.directories[things-I-almost-posted] |
| poem-pictures | sources.images.directories[poem-pictures] |
| dnd-pictures-from-the-internet | sources.images.directories[dnd-pictures-from-the-internet] |
| fediverse-stars | sources.images.directories[fediverse-stars] |
| fediverse-zip | sources.fediverse (archive, extracts to input/) |
| messages-zip | sources.messages (archive, extracts to input/) |
| notes-dir | sources.notes.directories[primary] |
| bluesky-car | sources.bluesky.directories[primary] |

## Related Documents

- `/config.lua` - Contains both sections
- `/libs/sources-loader.lua` - Reads from `sources`
- `/libs/external-sync.lua` - Reads from `external_files`
- `/issues/completed/10-003-consolidate-config-files-into-single-source.md` - Original consolidation
- `/issues/completed/10-015-unified-input-sources-config.md` - Created sources section
- `/issues/completed/10-003b-external-files-syncing-centralization.md` - Created external_files section

## Priority

Low - Both systems work correctly; this is a cleanup/unification issue.

## Notes

This issue was anticipated in the original design. Line 141-142 of config.lua contains:
> "NOTE: image_sync.sources will eventually be merged here. For now, both exist."

The merge would:
- Reduce config maintenance burden
- Make the relationship between sync sources and extraction paths explicit
- Simplify reasoning about data flow
