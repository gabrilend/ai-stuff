# Issue 7-004: Add Ignored Archives Configuration

## Status: COMPLETED (2026-01-30)

## Problem

During Stage 2 ZIP extraction, the zip-extractor script scans all `.zip` files in `input/` and attempts to classify them by type (fediverse, messages, notes). When it encounters a ZIP file that doesn't match any known content type, it prints a warning:

```
⚠️  Unknown archive type: neocities-ritz-menardi
```

The `neocities-ritz-menardi.zip` file is a Neocities site backup embedded within the fediverse export's `media_attachments/` folder. It's not content data and should never be extracted.

### Root Cause Analysis

1. **Data flow**: The fediverse ZIP archive includes a `media_attachments/` folder which is extracted to `input/media_attachments/` in Stage 2
2. **Embedded backup**: Inside this folder is `neocities-ritz-menardi.zip` - a site backup that was uploaded as a media attachment
3. **Timing issue**: Previous cleanup in `scripts/update-words` targeted the wrong path (`input/images/poem-pictures/`) and ran in Stage 1, before the file was extracted in Stage 2

## Solution

Add a configurable `ignored_archives` list to `config.lua` that tells zip-extractor which ZIP files to skip silently during scanning.

### Changes Made

**config.lua** - Added `extraction.ignored_archives` list:
```lua
extraction = {
    -- ...existing settings...
    -- Issue 7-003: ZIP files to ignore during archive scanning.
    -- These are ZIPs that appear in input/ but aren't content archives
    -- (e.g., site backups embedded in media_attachments from fediverse export).
    ignored_archives = {
        "neocities-ritz-menardi"  -- Neocities site backup, not content data
    }
}
```

**scripts/zip-extractor.lua** - Added config loading and ignore check:
```lua
-- Load config for ignored_archives list
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local config = config_loader.load()
local ignored_archives = (config.extraction and config.extraction.ignored_archives) or {}

-- Helper function to check if archive should be skipped
local function is_ignored_archive(basename)
    for _, ignored in ipairs(ignored_archives) do
        if basename == ignored then
            return true
        end
    end
    return false
end

-- In detect_archives(), check before type detection:
if is_ignored_archive(basename) then
    -- Silently skip - these are known non-content ZIPs
else
    -- ... existing type detection logic
end
```

**scripts/update-words** - Removed obsolete cleanup line:
```bash
# This was targeting the wrong path and ran in the wrong stage
# rm -f "${DIR}/input/images/poem-pictures/neocities-ritz-menardi.zip"
```

## Testing

Run the pipeline and verify no "Unknown archive type" warning appears:

```bash
./run.sh --stages 1,2
# Should NOT see: ⚠️  Unknown archive type: neocities-ritz-menardi
# Should see: 📦 Found fediverse archive: most-recent-29
# Should see: 📦 Found messages archive: similar-different
```

## Design Notes

- **Silent skip**: Ignored archives are skipped silently rather than with a message, because they are explicitly configured as "not content" - there's nothing notable about skipping them
- **Config-driven**: Using config.lua allows easy addition of future ignored archives without code changes
- **Basename matching**: The ignore list uses basenames (without `.zip` extension) for cleaner config syntax

## Related Files

- `config.lua:64-66` - ignored_archives list
- `scripts/zip-extractor.lua:22-37` - config loading and is_ignored_archive()
- `scripts/zip-extractor.lua:94-112` - archive scanning with ignore check

## Related Issues

- 7-003: Parent issue for run.sh output cleanup
