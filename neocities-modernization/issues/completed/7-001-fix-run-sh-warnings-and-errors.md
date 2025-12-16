# Issue 7-001: Fix run.sh Warnings and Errors

## Current Behavior

Running `run.sh` produces several warnings, errors, and fallbacks that should not occur:

### 1. rsync Failure and Warning
```
rsync: [Receiver] mkdir "/home/ritz/programming/ai-stuff//neocities-modernization/input/images/my-art" failed: No such file or directory (2)
rsync error: error in file IO (code 11) at main.c(791) [Receiver=3.4.1]
Warning: Failed to update input files, continuing anyway...
```
**Cause**: The external `sync-to-projects` script tries to rsync to `input/images/my-art` but the parent directory `input/images` doesn't exist. The script also has a double-slash in the path.

### 2. Shell Syntax Errors in Notes Extraction
```
sh: 1: Syntax error: Unterminated quoted string
sh: 1: Syntax error: Unterminated quoted string
```
**Cause**: The `scripts/extract-notes.lua` uses shell commands with single quotes that break when filenames contain special characters (likely apostrophes in filenames like "wanna-save-the-earth-?").

### 3. Media Attachments Directory Not Found
```
⚠️  Directory not found: /mnt/mtwo/programming/ai-stuff/neocities-modernization/input/media_attachments
❌ No images found in configured directories
[ERROR] Image cataloging failed: false
```
**Cause**: The `scripts/update` script extracts only `outbox.json` from the fediverse ZIP archive, not the `media_attachments` directory. The media files are never extracted to a permanent location.

### 4. Duplicate Validation Output
The validation summary is printed twice - once at the start of main.lua and again when `generate_complete_dataset()` runs. This is redundant output.

## Intended Behavior

- **Zero warnings** during `run.sh` execution
- **Zero errors** during `run.sh` execution
- **Zero fallbacks** - each step should succeed or fail cleanly
- Clean, minimal output showing progress and final status

## Suggested Implementation Steps

### Fix 1: rsync Directory Structure
Modify `/home/ritz/backups/words/sync-to-projects` (external script):
```bash
# Create parent directories before rsync
mkdir -p "${NEOCITIES_DIR}/input/images"

# Fix double-slash in path
rsync -av /home/ritz/pictures/my-art "${NEOCITIES_DIR}/input/images/"
```

**Alternative**: Update `run.sh` to create the directory structure before calling update-words:
```bash
mkdir -p "$DIR/input/images"
```

### Fix 2: Shell-safe Filename Handling in extract-notes.lua
Replace single-quoted shell commands with escaped or alternative approaches:

```lua
-- Current (breaks on special characters):
local find_cmd = string.format("find '%s' -type f", notes_dir)
local stat_cmd = string.format("stat -c %%Y '%s' 2>/dev/null", file_path)

-- Fixed (use printf %q for proper escaping, or avoid shell entirely):
local function shell_escape(str)
    return "'" .. str:gsub("'", "'\\''") .. "'"
end
local find_cmd = string.format("find %s -type f", shell_escape(notes_dir))
```

Or use Lua's `lfs` library to avoid shell commands for file operations entirely.

### Fix 3: Extract Media Attachments from ZIP
Modify `scripts/update` to extract and preserve media_attachments:

```bash
# After extracting outbox.json, also extract media_attachments
if [ -d "${TEMP_EXTRACT_DIR}/fediverse/extract/media_attachments" ]; then
    MEDIA_DEST="${DIR}/input/media_attachments"
    mkdir -p "${MEDIA_DEST}"
    cp -rn "${TEMP_EXTRACT_DIR}/fediverse/extract/media_attachments/"* "${MEDIA_DEST}/" 2>/dev/null || true
fi
```

**Note**: The current implementation already has this code, but the media_attachments aren't being extracted from the ZIP in the first place. The `zip-extractor.lua` only extracts `outbox.json`, not media files.

Update `scripts/zip-extractor.lua` to also extract media_attachments:
```lua
-- Add media_attachments extraction for fediverse archives
if archive_type == "fediverse" then
    -- Extract outbox.json (current behavior)
    -- Also extract media_attachments directory
    local media_cmd = string.format(
        "unzip -o '%s' 'media_attachments/*' -d '%s' 2>/dev/null || true",
        archive_path, extract_dir
    )
    os.execute(media_cmd)
end
```

### Fix 4: Remove Duplicate Validation Output
Modify `src/main.lua` to not run validation twice:

Option A: Remove the initial validation call before generate_complete_dataset()
Option B: Add a flag to skip validation output on second run
Option C: Restructure so validation only happens once

## Quality Assurance Criteria

- [ ] `run.sh` completes with zero warnings
- [ ] `run.sh` completes with zero errors
- [ ] `run.sh` completes with zero fallback messages
- [ ] Image cataloging finds and catalogs media attachments
- [ ] Notes with special characters in filenames are processed correctly
- [ ] Validation summary appears only once per run

## Success Metrics

- **Clean Output**: Only essential progress messages and final summary
- **Full Functionality**: All 7790 poems extracted, validated, and cataloged
- **Image Support**: Media attachments extracted and cataloged (500+ images expected)
- **Robustness**: Handles edge cases like special characters in filenames

## Dependencies

- Access to external script `/home/ritz/backups/words/sync-to-projects` for Fix 1
- Understanding of ZIP archive structure for Fix 3

## Related Issues

- **Issue 6-017**: Image integration system (related to media_attachments)
- **Issue 6-026**: Scripts directory integration (related to extraction pipeline)

## Testing Strategy

1. Run `run.sh` and verify zero warnings/errors in output
2. Verify `input/media_attachments` directory exists and contains images
3. Verify notes with special characters (apostrophes, question marks) are processed
4. Verify validation summary appears exactly once

---

**ISSUE STATUS: COMPLETED**

**Completion Date**: 2025-12-14

**Priority**: High - These issues prevent clean execution of the main pipeline

**Phase**: 7 (Stabilization and Polish)

---

## Implementation Results

### All Issues Fixed:

1. **rsync Directory Structure** (sync-to-projects)
   - Added `mkdir -p "${NEOCITIES_DIR}/input/images"` before rsync
   - Added trailing slashes to rsync source/dest paths to prevent nesting
   - Result: No more rsync failures

2. **Shell-safe Filename Handling** (scripts/extract-notes.lua)
   - Added `shell_escape()` function to properly escape single quotes
   - Updated `find`, `stat`, and `mkdir` commands to use escaped paths
   - Result: No more "Unterminated quoted string" errors

3. **Media Attachments Extraction** (scripts/zip-extractor.lua)
   - Added media_attachments extraction for fediverse archives
   - Used alternative extraction method via `xargs` for wildcard compatibility
   - Result: 532 images now extracted and cataloged

4. **Duplicate Validation Output** (src/poem-validator.lua, src/image-manager.lua)
   - Fixed module auto-execution guards to check `arg[0]` pattern
   - Modules no longer auto-run when `require()`d
   - Result: Validation summary appears exactly once

5. **Unwanted ZIP Cleanup** (scripts/update-words)
   - Added explicit `rm -f` for neocities-ritz-menardi.zip
   - Result: No more "Unknown archive type" warnings

### Files Modified:
- `/home/ritz/backups/words/sync-to-projects` - Fixed directory creation and rsync paths
- `scripts/update-words` - Added cleanup for unwanted ZIP files
- `scripts/extract-notes.lua` - Added shell escaping
- `scripts/zip-extractor.lua` - Added media extraction
- `src/poem-validator.lua` - Fixed module execution guard
- `src/image-manager.lua` - Fixed module execution guard
- `libs/utils.lua` - Fixed `get_file_mtime()` gsub return value handling

### Verification Results:
```
$ bash run.sh 2>&1 | grep -iE "(warning|error|⚠️|❌|failed)"
   🚨 Content warnings: 998
```
(The content warnings line is informational, not an error)

- Zero warnings
- Zero errors
- Zero fallbacks
- 532 images cataloged
- 7790 poems processed
- Single validation summary output
