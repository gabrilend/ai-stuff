# Issue 107: Build CLI Metadata Dump Tool

**Phase:** 1 - Foundation
**Type:** Tool
**Priority:** Medium
**Dependencies:** 106-design-internal-data-structures

---

## Current Behavior

No way to verify parsing is working correctly. Developers must write
ad-hoc test scripts to inspect parsed data.

---

## Intended Behavior

A command-line tool that:
- Opens a .w3x file and dumps human-readable metadata
- Supports multiple output formats (text, JSON)
- Can selectively dump specific components
- Serves as both a testing tool and utility for users
- Follows project conventions (DIR variable, interactive mode)

---

## Suggested Implementation Steps

1. **Create CLI script**
   ```
   src/
   └── cli/
       └── mapdump.lua      (this issue)
   ```

2. **Implement basic structure**
   ```lua
   #!/usr/bin/env lua
   -- mapdump.lua
   -- Dumps metadata from WC3 map files (.w3x/.w3m)
   --
   -- Usage:
   --   lua mapdump.lua <mapfile> [options]
   --   lua mapdump.lua -I              (interactive mode)
   --
   -- Options:
   --   -f, --format <fmt>    Output format: text, json (default: text)
   --   -c, --component <c>   Dump specific component: info, strings, terrain
   --   -o, --output <file>   Write to file instead of stdout
   --   -I, --interactive     Interactive mode
   --   -h, --help            Show help

   local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
   -- Allow override via first argument if it's a path
   if arg[1] and arg[1]:match("^/") and not arg[1]:match("%.w3[xm]$") then
       DIR = table.remove(arg, 1)
   end

   package.path = DIR .. "/src/?.lua;" .. package.path
   ```

3. **Implement argument parsing**
   ```lua
   -- {{{ parse_args
   local function parse_args(args)
       local options = {
           format = "text",
           component = "all",
           output = nil,
           interactive = false,
           mapfile = nil,
       }

       local i = 1
       while i <= #args do
           local arg = args[i]
           if arg == "-f" or arg == "--format" then
               i = i + 1
               options.format = args[i]
           elseif arg == "-c" or arg == "--component" then
               i = i + 1
               options.component = args[i]
           elseif arg == "-o" or arg == "--output" then
               i = i + 1
               options.output = args[i]
           elseif arg == "-I" or arg == "--interactive" then
               options.interactive = true
           elseif arg == "-h" or arg == "--help" then
               print_help()
               os.exit(0)
           elseif not arg:match("^-") then
               options.mapfile = arg
           end
           i = i + 1
       end

       return options
   end
   -- }}}
   ```

4. **Implement interactive mode**
   ```lua
   -- {{{ interactive_mode
   local function interactive_mode()
       print("=== WC3 Map Dump Tool ===")
       print()

       -- Select map file
       print("Available maps in assets/:")
       local maps = list_maps(DIR .. "/assets")
       for i, map in ipairs(maps) do
           print(string.format("  [%d] %s", i, map))
       end
       print()
       io.write("Select map (number or path): ")
       local choice = io.read()

       local mapfile
       if tonumber(choice) then
           mapfile = DIR .. "/assets/" .. maps[tonumber(choice)]
       else
           mapfile = choice
       end

       -- Select component
       print()
       print("Components:")
       print("  [1] All (default)")
       print("  [2] Info only (map name, author, etc.)")
       print("  [3] Strings only")
       print("  [4] Terrain summary")
       print("  [5] File list")
       io.write("Select component [1]: ")
       local comp = io.read()
       -- ... process selection ...

       -- Select format
       print()
       print("Output format:")
       print("  [1] Text (default)")
       print("  [2] JSON")
       io.write("Select format [1]: ")
       -- ...

       return options
   end
   -- }}}
   ```

5. **Implement dump functions**
   ```lua
   -- {{{ dump_info
   local function dump_info(map, format)
       if format == "json" then
           return json.encode({
               name = map:get_display_name(),
               author = map.author,
               description = map:resolve_string(map.description),
               suggested_players = map.suggested_players,
               dimensions = { map.width, map.height },
           })
       else
           local lines = {
               "=== Map Info ===",
               "Name: " .. map:get_display_name(),
               "Author: " .. map.author,
               "Description: " .. map:resolve_string(map.description),
               "Suggested Players: " .. map.suggested_players,
               "Dimensions: " .. map.width .. " x " .. map.height,
               "Tileset: " .. map.tileset,
               "",
               "=== Players ===",
           }
           for _, player in ipairs(map.players) do
               table.insert(lines, string.format(
                   "  [%d] %s (%s %s) at (%.0f, %.0f)",
                   player.id, player.name, player.type, player.race,
                   player.start_position.x, player.start_position.y
               ))
           end
           return table.concat(lines, "\n")
       end
   end
   -- }}}

   -- {{{ dump_terrain_summary
   local function dump_terrain_summary(map, format)
       local terrain = map.terrain
       local water_count = 0
       local cliff_count = 0

       for y = 0, terrain.height do
           for x = 0, terrain.width do
               local tile = terrain:get_tile(x, y)
               if tile.has_water then water_count = water_count + 1 end
               if tile.cliff_type > 0 then cliff_count = cliff_count + 1 end
           end
       end

       -- ... format and return ...
   end
   -- }}}

   -- {{{ dump_file_list
   local function dump_file_list(archive, format)
       local files = archive:list()
       -- ... format and return ...
   end
   -- }}}
   ```

6. **Main execution**
   ```lua
   -- {{{ main
   local function main()
       local options = parse_args(arg)

       if options.interactive then
           options = interactive_mode()
       end

       if not options.mapfile then
           print("Error: No map file specified")
           print("Use -h for help or -I for interactive mode")
           os.exit(1)
       end

       local map = Map.load(options.mapfile)

       local output
       if options.component == "all" then
           output = dump_all(map, options.format)
       elseif options.component == "info" then
           output = dump_info(map, options.format)
       -- ... etc ...
       end

       if options.output then
           local f = io.open(options.output, "w")
           f:write(output)
           f:close()
       else
           print(output)
       end
   end
   -- }}}

   main()
   ```

---

## Technical Notes

### vim-keybinding Navigation

For interactive mode, consider using a library like `lua-term` for
arrow key / vim keybinding support, or keep it simple with number selection.

### JSON Output

Include a simple JSON encoder or use an existing library. JSON output
is useful for piping to other tools (jq, etc.).

### Error Handling

Provide clear error messages:
```
Error: Could not open 'foo.w3x': File not found
Error: Invalid MPQ archive: Bad magic signature
Error: Unsupported w3i version: 31
```

---

## Related Documents

- issues/106-design-internal-data-structures.md (provides Map.load)
- Global CLAUDE.md conventions (DIR variable, interactive mode)

---

## Acceptance Criteria

- [ ] Can dump info from any test .w3x file
- [ ] Text output is human-readable
- [ ] JSON output is valid JSON
- [ ] Component filtering works (-c flag)
- [ ] Interactive mode works (-I flag)
- [ ] Output to file works (-o flag)
- [ ] Helpful error messages for invalid inputs
- [ ] Help text explains all options

---

## Notes

This tool serves multiple purposes:
1. Verification that parsing is working
2. Quick inspection of map files
3. Example of how to use the parsing API
4. Foundation for future tools (map browser, etc.)

Keep it simple but functional. This is a developer tool first.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-16 00:23*

Looking at this issue, I think it's already well-scoped and **doesn't need to be split into sub-issues**.

Here's my reasoning:

## Why Not Split

1. **Single cohesive deliverable** - This is one CLI tool with a clear purpose. All the "steps" are really just parts of implementing one script file (`mapdump.lua`).

2. **No parallelizable work** - The components are tightly coupled:
   - Argument parsing is useless without the dump functions
   - Interactive mode needs both
   - Output formatting spans all components

3. **Modest scope** - The issue estimates roughly 300-400 lines of Lua code in a single file. This is a reasonable size for one implementation session.

4. **Clear dependency** - It depends on issue 106 (internal data structures) being complete. Once that's done, this tool is straightforward to implement.

5. **The "dump functions" share structure** - `dump_info`, `dump_terrain_summary`, `dump_file_list` are all variations on the same pattern (format data as text or JSON). Splitting them into separate issues would create artificial overhead.

## Alternative Consideration

If you wanted to split it anyway, the only natural boundary would be:

| Sub-issue | Description |
|-----------|-------------|
| **107a** | Core CLI with text output for map info only |
| **107b** | Add JSON output format support |
| **107c** | Add interactive mode |

But even this feels like over-engineering for what is essentially a utility script. The original issue already has good acceptance criteria that can serve as a natural checklist.

## Recommendation

Keep issue 107 as-is. It's a well-defined "tool" type issue that will take a focused implementation session to complete. The suggested implementation steps in the issue are detailed enough to guide development without needing formal sub-issue tracking.
