# Issue 8-042: Sync Images From Configurable Source Directories

## Priority
Medium

## Current Behavior

The `update-words` pipeline stage (Stage 1) syncs text content from the words repository via an external script (`/home/ritz/backups/words/sync-to-projects`), but **does not handle image syncing**.

Images currently live in `input/media_attachments/` and are expected to be manually placed or synced by external processes. The source directories for images are hardcoded or implicit rather than configurable.

**Current image-related config** (in `config/input-sources.json`):
```json
"image_integration": {
    "enabled": true,
    "image_directories": ["input/media_attachments"],
    ...
}
```

This only specifies where images are *read from* during cataloging, not where they should be *synced from*.

## Intended Behavior

The `update-words` stage (or a new dedicated stage) should:
1. Read a list of source directories from the config file
2. Sync images from each source directory to the project's `input/media_attachments/` (or other configured destination)
3. Support multiple source directories (fediverse archive, local photos, etc.)
4. Preserve directory structure from source

**Example config structure:**
```lua
image_sync = {
    enabled = true,
    destination = "input/media_attachments",
    sources = {
        {
            name = "fediverse_media",
            path = "/home/ritz/backups/words/fediverse/media_attachments",
            description = "Mastodon media attachments"
        },
        {
            name = "local_photos",
            path = "/home/ritz/pictures/poetry-images",
            description = "Manually added images for poems"
        },
        {
            name = "bluesky_media",
            path = "/home/ritz/backups/bluesky/media",
            description = "Bluesky post images"
        }
    },
    -- Sync options
    preserve_structure = true,  -- Keep subdirectory structure from source
    overwrite_existing = false, -- Skip files that already exist
    supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"}
}
```

## Suggested Implementation Steps

1. **Add `image_sync` section to config**:
   - Define source directories with absolute paths
   - Each source has name, path, and description
   - Include sync behavior options

2. **Create image sync function** in `scripts/update-words` or new script:
   ```bash
   # {{{ sync_images
   sync_images() {
       # Read source directories from config
       # For each source:
       #   - Verify source exists
       #   - rsync or cp to destination
       #   - Report files synced
   }
   # }}}
   ```

3. **Integrate into pipeline**:
   - Option A: Add to existing `update-words` stage
   - Option B: Create new `--sync-images` stage
   - Recommendation: Add to `update-words` since it's conceptually "sync input files"

4. **Handle missing sources gracefully**:
   - Warn if a configured source doesn't exist
   - Continue with other sources
   - Don't fail the entire pipeline

5. **Add dry-run support**:
   - Show what would be synced without copying
   - Useful for verifying config before large syncs

## Integration with Poem Cataloging Pipeline

**Critical requirement**: Synced images must be associated with poems and included in chronological.html at their correct timestamp locations.

The current pipeline flow:
1. **Stage 1 (update-words)**: Syncs text content from words repository
2. **Stage 5 (image-manager)**: Catalogs images and associates them with poems
3. **Stage 9 (html-generation)**: Generates chronological/similar/different pages

**How images are currently associated with poems:**

1. **Fediverse images (ActivityPub)**: Attachments are pre-associated with poems in `input/fediverse/files/poems.json` during the ActivityPub extraction process. The JSON includes an `attachments` array with `relative_path` pointing to files in `input/media_attachments/`.

2. **Other sources (notes, local photos, bluesky)**: Currently no automatic association mechanism. Images synced from these sources would need:
   - A manifest file mapping images to poems (e.g., `source_name/image-manifest.json`)
   - Or naming convention matching (image filename matches poem ID)
   - Or manual metadata in poem files

3. **Timestamp preservation**: When syncing from multiple sources, original creation/modification timestamps should be preserved for correct chronological ordering.

4. **Catalog regeneration**: After syncing new images, Stage 5 (`--catalog-images`) should run to update `assets/image-catalog.json`.

**Sync-to-catalog flow:**
```
image_sync sources → input/media_attachments/ → image-manager.lua → image-catalog.json → html-generator
```

**Implementation consideration**: The `update-words` stage should trigger a re-catalog of images when new files are synced. This can be done by:
- Setting a flag when files are copied
- Checking file counts before/after sync
- Letting run.sh always run Stage 5 after Stage 1

## Integration with Config Consolidation (Issue 10-003)

This issue should be coordinated with Issue 10-003 (Consolidate Config Files). The `image_sync` configuration should be added to the unified config file.

**Proposed addition to `/config/main.lua`:**
```lua
-- Image sync configuration (new section)
image_sync = {
    enabled = true,
    destination = "input/media_attachments",
    sources = {
        {
            name = "fediverse_media",
            path = "/home/ritz/backups/words/fediverse/media_attachments",
            description = "Mastodon/ActivityPub media attachments"
        }
        -- Additional sources can be added here
    },
    preserve_structure = true,
    overwrite_existing = false,
    supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"}
},

-- Existing image_integration section (for cataloging/display)
image_integration = {
    enabled = true,
    image_directories = {"input/media_attachments"},
    supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"},
    max_file_size_mb = 10,
    output_path = "assets/images",
    catalog_file = "assets/image-catalog.json"
}
```

**Distinction:**
- `image_sync`: Where to copy images FROM (source directories)
- `image_integration`: Where to read images FROM for cataloging/display (destination after sync)

## Example Usage

```bash
# Sync all input files including images
./run.sh --update-words

# Output:
# 📁 Stage 1/10: Updating input files from words repository
#    💾 Preserved 3 generated file directories
#    📷 Syncing images from 2 configured sources...
#       - fediverse_media: 532 files synced
#       - local_photos: 47 files synced
#    ♻️  Restored 3 generated file directories
```

## Related Documents

- `scripts/update-words` - Current sync script (needs modification)
- `run.sh` - Pipeline orchestration
- `issues/10-003-consolidate-config-files-into-single-source.md` - Config consolidation
- `config/input-sources.json` - Current config location
- `src/image-manager.lua` - Image cataloging (Stage 5)

## Metadata

- **Status**: Open
- **Created**: 2026-01-20
- **Phase**: 8 (Website Completion / Pipeline)
- **Estimated Complexity**: Medium
- **Dependencies**: Coordinates with Issue 10-003 (config consolidation)
- **Affects**: Stage 1 (update-words), image availability for all pages
