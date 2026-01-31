# Issue 7-005: Select Most Recent Archive Per Type

**Priority**: High
**Phase**: 7 (Stabilization and Polish)
**Status**: Completed
**Created**: 2026-01-30
**Completed**: 2026-01-30

---

## Current Behavior

The `scripts/zip-extractor.lua` finds all ZIP archives in `input/`, categorizes them by type (fediverse, messages, notes), and extracts **all** of them. When multiple archives of the same type exist:

1. All are extracted sequentially
2. The `extraction_paths` dictionary overwrites previous entries: `summary.extraction_paths[archive.type] = extraction_path`
3. The **last** archive processed (by filesystem order) is used, not the most recent by date
4. No warning is shown about which archives were skipped

**Example**: If `input/` contains:
- `similar-different.zip` (messages, older)
- `new-messages-export.zip` (messages, newer)

The extractor might use `similar-different.zip` simply because it was found first, ignoring the newer export.

---

## Intended Behavior

1. **Group archives by type**: Collect all archives into buckets (fediverse, messages, notes)
2. **Sort by modification time**: Within each bucket, sort by file mtime (newest first)
3. **Select most recent**: Only extract the newest archive from each type
4. **Warn about skipped archives**: Print a yellow warning (full yellow text, not just icon) showing the full path of each older, unused archive

**Example output**:
```
🔍 Scanning for ZIP archives in: ./input
📦 Found messages archive: new-messages-export (2026-01-28)
📦 Found messages archive: similar-different (2025-12-14)
📦 Found fediverse archive: most-recent-29 (2026-01-15)

📊 Archive selection:
   messages: new-messages-export (selected)
   ⚠️  Skipped older: ./input/similar-different.zip (2025-12-14)
   fediverse: most-recent-29 (selected)
```

---

## Suggested Implementation Steps

### Step 1: Add modification time detection

```lua
-- {{{ local function get_file_mtime
local function get_file_mtime(file_path)
    local stat_cmd = string.format("stat -c %%Y '%s' 2>/dev/null", file_path)
    local handle = io.popen(stat_cmd)
    local result = handle:read("*a")
    handle:close()

    if result and result ~= "" then
        return tonumber(result:gsub("%s+", ""))
    end
    return 0
end
-- }}}
```

### Step 2: Store mtime in archive info

```lua
-- In detect_archives():
table.insert(archives, {
    path = file,
    type = archive_type,
    basename = basename,
    mtime = get_file_mtime(file),  -- Add this
    mtime_date = os.date("%Y-%m-%d", get_file_mtime(file))  -- Human-readable
})
```

### Step 3: Create selection function

```lua
-- {{{ local function select_archives_by_type
-- Groups archives by type, sorts by mtime (newest first), returns selected + skipped
local function select_archives_by_type(archives)
    local by_type = {}

    -- Group by type
    for _, archive in ipairs(archives) do
        if not by_type[archive.type] then
            by_type[archive.type] = {}
        end
        table.insert(by_type[archive.type], archive)
    end

    local selected = {}
    local skipped = {}

    -- Sort each group by mtime (descending) and pick newest
    for archive_type, group in pairs(by_type) do
        table.sort(group, function(a, b) return a.mtime > b.mtime end)

        -- First (newest) is selected
        table.insert(selected, group[1])

        -- Rest are skipped
        for i = 2, #group do
            table.insert(skipped, group[i])
        end
    end

    return selected, skipped
end
-- }}}
```

### Step 4: Update main flow

```lua
-- After detect_archives():
local all_archives = detect_archives(DIR .. "/input")
local selected, skipped = select_archives_by_type(all_archives)

-- Warn about skipped archives (full yellow text)
if #skipped > 0 then
    for _, archive in ipairs(skipped) do
        print(COLOR_YELLOW .. "⚠️  Skipped older: " .. relative_path(archive.path) ..
              " (" .. archive.mtime_date .. ")" .. COLOR_RESET)
    end
end

-- Only extract selected archives
local summary = create_extraction_summary(selected, TEMP_DIR)
```

---

## Success Criteria

- [x] Archives grouped by type before selection
- [x] Most recent archive (by mtime) selected per type
- [x] Older archives in same type category show yellow warning
- [x] Warning includes full path and date
- [x] Only selected archives are extracted
- [x] Extraction summary reflects actual selection

---

## Related Files

- `scripts/zip-extractor.lua:47-61` - `get_file_mtime()` function
- `scripts/zip-extractor.lua:98-137` - `detect_archives()` function with mtime
- `scripts/zip-extractor.lua:139-170` - `select_archives_by_type()` function
- `scripts/zip-extractor.lua:278-303` - Main execution with selection logic
- `issues/7-progress.md` - Phase 7 progress tracking

---

## Notes

- The yellow warning text (not just icon) helps distinguish "attention required" from "info"
- This follows the semantic color scheme from 7-003: yellow = attention
- Consider adding a `--force-all` flag to extract all archives if ever needed

---

## Implementation Notes (2026-01-30)

**Lua gsub gotcha**: The `string.gsub()` function returns two values (string, count). When passed directly to `tonumber()`, the count became the "base" argument. Fixed by wrapping in parentheses: `(result:gsub(...))`.

**Example output with multiple archives of same type:**
```
🔍 Scanning for ZIP archives in: ./input
📦 Found messages archive: new-export (2026-01-28)
📦 Found messages archive: similar-different (2025-12-13)
📦 Found fediverse archive: most-recent-29 (2025-12-10)

📊 Archive selection:
   Total found: 3, Selected: 2, Skipped: 1
   ⚠️  Skipped older: ./input/similar-different.zip (2025-12-13)
```
