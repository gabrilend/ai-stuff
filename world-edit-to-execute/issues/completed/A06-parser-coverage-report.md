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

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #323 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- A protected map lists a duplicated file once by name and again as numbered copies (`File00000131.w3d`), so duplicates are counted more than once and appear under extensions with "no parser". The first run's totals (3,416 files, 146 unparsed) include these.
- Listing a map's files is not protected: one map with a damaged file table stops the whole report with a traceback and leaves the archive open.
- A map that won't open gets the status "error", which the summary never counts, so every standard file kind then looks "present in at least one map" and clutters the matrix.
- A map path ending in `/` crashes before the map is opened (the short-name match finds nothing).
- Standard names are matched with exact case and `\` separators, but archive names ignore case; `War3map.j` is filed as "no parser yet" and the script is never parsed.
- The JSON writer turns every empty table into `[]`, so `status` and `summary` flip between object and array from run to run.
- `--help` prints only a one-line usage to stderr and exits 2, the same as a usage error.
- A third hand-written JSON encoder, beside `dkjson` and `cli/mapdump.lua`'s.
- Maps are scanned one after another on one thread although each is independent (house rule: parallel batch work).
- The branch moved this issue to completed while its "Still open" section lists deferred work, and the 8 parser failures it found were not written into the parser issues.

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

**Date:** 2026-11-06 (built by Claude in the background; the owner reviews
the draft pull request)

### Files

- `src/data/parser_coverage.lua` (+ `.info.md`): the scan, the summary, and
  the text, Markdown and JSON outputs.
- `src/cli/parser-coverage.lua` (+ `.info.md`): the command line, with the
  flags step 7 lists (`-a`, `-m`, `-f`, `-v`, `--matrix`, `--json`,
  `--markdown FILE`) and `--dir DIR` as the other tools in `src/cli/` take it.
- `src/tests/test_parser_coverage.lua` (+ `.info.md`): 80 checks.

### Decisions (2026-11-06)

- **Where the code lives:** a library in `src/data/` and a thin tool in
  `src/cli/`, the way `gamedata/route_b.lua` and `cli/route-b-report.lua`
  split, so the test can call the library directly. The design above
  sketched one script.
- **Which files count as a kind:** each name in `mpq/standard_names.lua`
  is its own kind (that list replaces the design's hand-written table);
  every other stored file counts under its extension (`*.mdx`), so a map's
  hundreds of imports give one row each, counted file by file.
- **Readers:** whatever the project already has for each kind, including
  readers outside `src/parsers/`: `demo.wc3map.footprint.parse_wpm` for the
  pathing map, `parsers.profile_txt` for `war3mapMisc/Skin/Extra.txt`, and
  the image decoders for the minimap and preview. `war3map.shd`,
  `war3map.mmp`, `war3map.imp`, `(listfile)` and `(attributes)` have none.
- **What failed means:** the reader raised, or returned nil/false; the
  message is kept for `-v`, the Markdown report and JSON.
- **A matrix cell** is the map's verdict for that kind: `FAIL` if any file
  of the kind failed. Kinds no map holds are left out of the matrix.
- **Plain ASCII in the terminal** (`ok`, `FAIL`, `.`, `-`) rather than the
  design's box drawing and check marks, so the output lines up in any
  terminal and greps cleanly.
- **Exit codes:** 0 when nothing failed, 1 when a file failed or a map
  would not open, 2 on a usage error, so a script can use it as a check.

### First run (2026-11-06, the 19 maps in `assets/`, 21 s)

19 maps, all open; 3,416 stored files: 3,262 read, 8 failed, 146 with no
parser. Every map's w3i, w3e, wts, script, doo, wpm, w3u, w3d, w3a and
Misc.txt read. The eight failures, all in the three non-DAoW maps:

- `war3mapUnits.doo`: Conquest-v8-fix and Master-Crafters-Final-Conquest
  (the reader runs past the end of the data).
- `war3map.wtg` and `war3map.wct`: the same two maps ("too short", "Empty
  WCT data", a wrong `WTG!` magic and a string length past the data);
  both look like protected maps that blank or replace these files.
- One imported `.blp` in Conquest-v8-fix ("not a BLP1 texture") and one
  imported `.mdx` in War-in-the-Plaguelands ("read past the end").

These are findings for the parser issues; nothing here changes a parser.

### Still open

- Parsing times and file sizes per kind (the Notes' suggestion): sizes are
  in the JSON per file; times are not measured.

### Note (2026-11-06)

Three of the first run's eight failures were a protected map's
placeholder trigger files (issue 302a). A06a reports such files as
protected, apart from failures.
