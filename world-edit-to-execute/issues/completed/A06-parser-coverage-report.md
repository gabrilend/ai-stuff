# Issue A06: Parser Coverage Report

**Phase:** A - Infrastructure Tools
**Type:** Tool
**Priority:** Medium
**Dependencies:** None (uses existing parsers)

---

## Current Behavior

*Where this issue lives:* it moved to the shared `scripts/issues/` folder
with the other Phase A tools in December 2025, and came back here in
September 2026. Every part of it -- the test maps, the parsers, the file
types -- belongs to this project, and no other project could run it; a
shared tool that only one project can use is this project's tool.

No visibility into which file types in test maps have parsers and which
don't. Parser success/failure across test maps isn't aggregated into a
single view.

---

## Intended Behavior

A project-specific tool that:
- Lists all files contained in test map archives
- Shows which files have parsers implemented
- Reports parser success/failure per map
- Generates a compatibility matrix
- Identifies files without parsers (future work)

Note: This tool is more project-specific than others in Phase A, but the
pattern can be abstracted for similar archive-based projects.

---

## Suggested Implementation Steps

1. **Create project script**
   ```
   src/cli/parser-coverage.lua
   ```
   (May be promoted to shared scripts if pattern proves reusable)

2. **Define configuration**
   ```lua
   local config = {
       project_dir = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute",
       assets_dir = "assets",
       map_pattern = "%.w3x$",

       -- Map file types to parsers
       parsers = {
           ["war3map.w3i"] = "parsers.w3i",
           ["war3map.wts"] = "parsers.wts",
           ["war3map.w3e"] = "parsers.w3e",
           ["war3map.w3r"] = "parsers.w3r",
           ["war3map.w3c"] = "parsers.w3c",
           ["war3map.w3s"] = "parsers.w3s",
           ["war3map.doo"] = nil,  -- Not yet implemented
           ["war3mapUnits.doo"] = nil,
           ["war3map.wtg"] = nil,
           ["war3map.wct"] = nil,
           ["war3map.j"] = nil,
       },
   }
   ```

3. **Implement map file scanner**
   ```lua
   -- {{{ scan_map_files
   local function scan_map_files(map_path)
       local mpq = require("mpq")
       local archive = mpq.open(map_path)
       if not archive then
           return nil, "Failed to open archive"
       end

       local info = archive:info()
       local files = {}

       for _, filename in ipairs(info.file_list) do
           files[#files + 1] = {
               name = filename,
               has_parser = config.parsers[filename] ~= nil,
               parser_module = config.parsers[filename],
           }
       end

       archive:close()
       return files
   end
   -- }}}
   ```

4. **Implement parser testing**
   ```lua
   -- {{{ test_parser
   local function test_parser(map_path, filename, parser_module)
       local mpq = require("mpq")
       local archive = mpq.open(map_path)
       if not archive then
           return "error", "Cannot open archive"
       end

       -- Check if file exists
       if not archive:has(filename) then
           archive:close()
           return "missing", "File not in archive"
       end

       -- Extract file
       local data, err = archive:extract(filename)
       if not data then
           archive:close()
           return "extract_error", err
       end

       -- Load and run parser
       local ok, parser = pcall(require, parser_module)
       if not ok then
           archive:close()
           return "parser_error", "Cannot load parser: " .. parser
       end

       local result, parse_err = parser.parse(data)
       archive:close()

       if result then
           return "success", result
       else
           return "parse_error", parse_err
       end
   end
   -- }}}
   ```

5. **Implement coverage matrix**
   ```lua
   -- {{{ generate_matrix
   local function generate_matrix(results)
       -- results[map_name][file_name] = status

       local lines = {}

       -- Header row
       local file_types = get_unique_files(results)
       local header = "| Map |"
       for _, ft in ipairs(file_types) do
           header = header .. " " .. ft:sub(1, 6) .. " |"
       end
       lines[#lines + 1] = header

       -- Separator
       local sep = "|-----|"
       for _ in ipairs(file_types) do
           sep = sep .. "--------|"
       end
       lines[#lines + 1] = sep

       -- Data rows
       for map_name, files in pairs(results) do
           local row = "| " .. map_name:sub(1, 20) .. " |"
           for _, ft in ipairs(file_types) do
               local status = files[ft] or "N/A"
               local symbol = status_symbol(status)
               row = row .. " " .. symbol .. " |"
           end
           lines[#lines + 1] = row
       end

       return table.concat(lines, "\n")
   end

   local function status_symbol(status)
       if status == "success" then return "✓"
       elseif status == "missing" then return "○"
       elseif status == "no_parser" then return "—"
       else return "✗"
       end
   end
   -- }}}
   ```

6. **Implement summary report**
   ```lua
   -- {{{ generate_report
   local function generate_report(results)
       local lines = {
           "# Parser Coverage Report",
           "",
           "Generated: " .. os.date("%Y-%m-%d %H:%M"),
           "",
           "## Summary",
           "",
       }

       -- Count by file type
       local by_file = {}
       for _, files in pairs(results) do
           for filename, status in pairs(files) do
               by_file[filename] = by_file[filename] or { success = 0, fail = 0, missing = 0, no_parser = 0 }
               if status == "success" then
                   by_file[filename].success = by_file[filename].success + 1
               elseif status == "missing" then
                   by_file[filename].missing = by_file[filename].missing + 1
               elseif status == "no_parser" then
                   by_file[filename].no_parser = by_file[filename].no_parser + 1
               else
                   by_file[filename].fail = by_file[filename].fail + 1
               end
           end
       end

       lines[#lines + 1] = "| File Type | Parser | Success | Fail | Missing |"
       lines[#lines + 1] = "|-----------|--------|---------|------|---------|"

       for filename, stats in pairs(by_file) do
           local parser = config.parsers[filename] and "✓" or "—"
           lines[#lines + 1] = string.format("| %s | %s | %d | %d | %d |",
               filename, parser, stats.success, stats.fail, stats.missing)
       end

       lines[#lines + 1] = ""
       lines[#lines + 1] = "## Compatibility Matrix"
       lines[#lines + 1] = ""
       lines[#lines + 1] = generate_matrix(results)

       return table.concat(lines, "\n")
   end
   -- }}}
   ```

7. **Add CLI interface**
   ```lua
   -- Modes:
   -- -a, --all           Test all maps
   -- -m, --map FILE      Test specific map
   -- -f, --file TYPE     Test specific file type
   -- -v, --verbose       Show detailed errors
   -- --matrix            Output only matrix
   -- --json              Output JSON
   -- --markdown FILE     Save markdown report
   ```

---

## Output Example

### Terminal Output

```
╔════════════════════════════════════════════════════════════╗
║              PARSER COVERAGE REPORT                        ║
╠════════════════════════════════════════════════════════════╣
║ File Type         │ Parser │ Maps Success │ Maps Fail     ║
╠═══════════════════╪════════╪══════════════╪═══════════════╣
║ war3map.w3i       │   ✓    │     15/16    │     1/16      ║
║ war3map.wts       │   ✓    │     16/16    │     0/16      ║
║ war3map.w3e       │   ✓    │     15/16    │     1/16      ║
║ war3map.w3r       │   ✓    │     16/16    │     0/16      ║
║ war3map.w3c       │   ✓    │     0/16     │     0/16 (○)  ║
║ war3map.doo       │   —    │      —       │       —       ║
║ war3mapUnits.doo  │   —    │      —       │       —       ║
╚════════════════════════════════════════════════════════════╝

Legend: ✓ = success, ✗ = fail, ○ = file not in map, — = no parser
```

### Markdown Matrix

```markdown
| Map | w3i | wts | w3e | w3r | w3c | doo |
|-----|-----|-----|-----|-----|-----|-----|
| DAoW-2.1 | ✓ | ✓ | ✓ | ✓ | ○ | — |
| DAoW-5.2 | ✓ | ✓ | ✓ | ✓ | ○ | — |
| DAoW-5.3 | ✓ | ✓ | ✓ | ✓ | ○ | — |
...
```

---

## Related Documents

- src/parsers/ (parser modules)
- src/tests/ (individual parser tests)
- assets/ (test maps)

---

## Acceptance Criteria

- [x] Scans all test map archives
- [x] Lists files present in each map
- [x] Tests parsers against map files
- [x] Generates coverage matrix
- [x] Shows success/fail per parser per map
- [x] Identifies files without parsers
- [x] Terminal and markdown output
- [x] JSON output option
- [x] Verbose mode shows error details
- [x] Summary statistics

---

## Notes

This tool provides visibility into parser completeness. Use it to:
- Track Phase 2/3 progress on new parsers
- Identify edge cases (maps that fail specific parsers)
- Guide prioritization (files common across maps but lacking parsers)

The "missing" status (file not in map) is useful for understanding
which file types are optional vs. universal.

Consider extending to show file sizes and parsing times for performance
analysis.

---

## Implementation Notes

**Date:** 2026-11-02

Built as `src/cli/parser-coverage.lua`, with `src/cli/parser-coverage.info.md`
and `src/tests/test_parser_coverage.lua` (26 tests, about a second, on two
of the test maps).

### What it found (all 16 test maps, 30 seconds)

- 33 kinds of file, 27 with a reader and 6 without; 2,759 files, of which
  2,665 read with no failure and 94 have no reader.
- **Read in every map that has them:** map info, strings, terrain,
  doodads, placed units (5 maps have them), the seven object data files,
  the script (`scripts\war3map.j`), `war3mapMisc.txt` and
  `war3mapSkin.txt`, 1,222 BLP textures, 1,185 MDX models, 7 TGA images,
  11 imported SLK tables and 15 imported profile text files.
- **No reader yet:** the shadow map (`war3map.shd`), the pathing map
  (`war3map.wpm`) and the minimap icons (`war3map.mmp`), all present in
  every map; one MP3; and 45 unnamed files StormLib couldn't guess a type
  for.
- **In none of the 16 maps:** regions, cameras, sounds, the World
  Editor's trigger files (`.wtg`, `.wct`), a root-level `war3map.j` and
  `war3map.imp`. The DAoW maps are protected, and protecting a map strips
  the files the game doesn't need. Those readers are tested by their own
  test files instead.
- Most of the read time is the BLP textures (about 15 of 22 seconds of
  reading), then terrain and models (about 3 seconds each).

### Changes from the design above

- **Kinds, not only named files.** The design listed map files by name;
  but most files in the test maps are imports (textures, models), so every
  other file is counted by extension and unnamed ones by their first
  bytes. The readers for images, models, SLK and profile text are in the
  table beside the map files.
- **The design's `parsers = { ["war3map.doo"] = nil ... }` was out of
  date:** every map data file it marked as having no reader has one now.
- **`war3map.shd`, `.wpm`, `.mmp` and `.imp` are listed with no reader.**
  The editor and the building-footprint code write or read `.wpm` for
  their own needs, and the archive code reads the import list from `.imp`,
  but there is no reader module for them under `src/parsers/` to point the
  tool at.
- **`--dir DIR` comes first,** as in the other tools in `src/cli/`
  (`mpq-extract.lua`, `patch-notes-build.lua`).

### Decisions made while building

1. **A failure is an error or a reader that returns nothing.** Some
   readers raise errors (most), and the object data reader returns nil and
   a message; both count.
2. **A map's status for a kind is a failure if any file of that kind
   failed** (a map holds hundreds of textures), and the per-kind file
   counts show how many.
3. **Only the first three failures of a kind are printed without `-v`,**
   so a reader broken on every texture doesn't bury the rest of the report.
4. **Exit status 1 only when a map won't open,** not when a file fails to
   read: the report is how failures are seen, and a script running the
   tool shouldn't stop on what it is there to show.
