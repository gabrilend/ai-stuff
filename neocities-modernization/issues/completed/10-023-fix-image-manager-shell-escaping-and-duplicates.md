# Issue 10-023: Fix Image Manager Shell Escaping and Duplicate Resolution

## Status: COMPLETED

## Current Behavior

### Shell Escaping Issue

When scanning directories, files with single quotes in their names (e.g., `Statua-di-Sant'Azraphel.png`) cause shell errors:

```
sh: 1: Syntax error: Unterminated quoted string
sh: 1: Syntax error: Unterminated quoted string
sh: 1: Syntax error: Unterminated quoted string
sh: 1: Syntax error: Unterminated quoted string
```

The shell commands use single-quoted paths like:
```bash
stat -c %s 'Statua-di-Sant'Azraphel.png'
```

The `'` in `Sant'` prematurely ends the shell string.

### Duplicate Handling Issue

Duplicate images (same MD5 hash) are detected and reported as warnings, but not resolved:

```
Duplicate Groups: 39
```

User must manually decide which duplicate to keep.

## Intended Behavior

1. Shell commands should properly escape filenames containing special characters
2. Duplicates should be automatically resolved by keeping the newest file (by modification time)
3. Duplicate resolution should be reported, not warned

## Implementation

### Shell Escaping (image-manager.lua)

Added `shell_escape()` function that replaces single quotes with `'\''`:

```lua
-- {{{ local function shell_escape
-- Escape single quotes in paths for safe shell execution
-- e.g., "Sant'Azraphel.png" -> "Sant'\''Azraphel.png"
local function shell_escape(path)
    return path:gsub("'", "'\\''")
end
-- }}}
```

Applied to all 6 shell commands:
- `get_file_size()` - stat command
- `get_file_mtime()` - stat command
- `extract_image_dimensions()` - identify command
- `generate_image_hash()` - md5sum command
- `scan_directory_for_images()` - test -d and find commands

### Duplicate Resolution (image-manager.lua)

Modified `generate_catalog()` to:

1. Group images by hash (as before)
2. For groups with multiple files, sort by modification_time descending
3. Keep only the newest file (first after sorting)
4. Filter original image list to only include kept files
5. Report resolution count: `"Resolved 39 duplicates (kept newest of each group)"`

Catalog structure updated:
- `images` now contains de-duplicated list
- `resolved_duplicates` replaces `duplicates`, includes `kept` and `removed` paths
- `metadata.unique_images` added to show final count

Statistics updated:
- `stats.unique_images` = filtered count (after deduplication)
- `stats.total_images` = original count (before deduplication)

Output changed from warning to informational:
```
Resolved 39 duplicate groups (kept newest):
   (use --verbose to see details)
```

## Files Modified

- `src/image-manager.lua`
  - Added `shell_escape()` function
  - Applied escape to all io.popen shell commands
  - Rewrote duplicate handling in `generate_catalog()`
  - Updated `show_statistics()` for new catalog structure

## Lessons Learned

1. Shell single-quote escaping: Replace `'` with `'\''` (end quote, escaped quote, start new quote)
2. Automatic resolution of duplicates by timestamp is more user-friendly than manual warnings
3. Keeping resolution records in the catalog preserves auditability

## Related Issues

- 10-015a: Migrate image-manager to sources-loader
- 6-017: Implement image integration system

## Completed

2026-02-10
