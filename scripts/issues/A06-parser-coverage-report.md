# Issue A06: Parser Coverage Report

**Phase:** A - Infrastructure Tools
**Type:** Tool
**Priority:** Medium
**Dependencies:** None (uses existing parsers)

---

## Current Behavior

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

- [ ] Scans all test map archives
- [ ] Lists files present in each map
- [ ] Tests parsers against map files
- [ ] Generates coverage matrix
- [ ] Shows success/fail per parser per map
- [ ] Identifies files without parsers
- [ ] Terminal and markdown output
- [ ] JSON output option
- [ ] Verbose mode shows error details
- [ ] Summary statistics

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
