# Issue A05: Documentation Index Updater

**Phase:** A - Infrastructure Tools
**Type:** Tool
**Priority:** Low
**Dependencies:** None

---

## Current Behavior

The `docs/table-of-contents.md` file must be manually updated when new
documentation is added. CLAUDE.md requires: "every time a new document
is created, it should be added to the tree-hierarchy structure present
in /docs/table-of-contents.md"

---

## Intended Behavior

A project-abstract tool that:
- Scans documentation directories for markdown files
- Auto-generates or updates table of contents
- Maintains tree hierarchy structure
- Preserves manual annotations/descriptions
- Works across any project with standard docs layout

---

## Suggested Implementation Steps

1. **Create shared script**
   ```
   /home/ritz/programming/ai-stuff/scripts/update-toc.lua
   ```
   Symlinked into projects as `src/cli/update-toc.lua`

2. **Define configuration interface**
   ```lua
   local config = {
       project_dir = "",
       docs_dir = "docs",
       toc_file = "docs/table-of-contents.md",
       ignore_patterns = { "table%-of%-contents%.md" },
       max_depth = 4,

       -- Directory display names (optional)
       dir_names = {
           formats = "File Format Specifications",
           history = "Commit History",
       },
   }
   ```

3. **Implement directory scanner**
   ```lua
   -- {{{ scan_docs
   local function scan_docs(dir, depth)
       depth = depth or 0
       local entries = {}

       for file in lfs.dir(dir) do
           if file ~= "." and file ~= ".." then
               local path = dir .. "/" .. file
               local attr = lfs.attributes(path)

               if attr.mode == "directory" then
                   entries[#entries + 1] = {
                       type = "dir",
                       name = file,
                       path = path,
                       children = scan_docs(path, depth + 1),
                   }
               elseif file:match("%.md$") and not should_ignore(file) then
                   entries[#entries + 1] = {
                       type = "file",
                       name = file,
                       path = path,
                       title = extract_title(path),
                   }
               end
           end
       end

       -- Sort: directories first, then files, alphabetically
       table.sort(entries, function(a, b)
           if a.type ~= b.type then
               return a.type == "dir"
           end
           return a.name < b.name
       end)

       return entries
   end
   -- }}}
   ```

4. **Implement title extraction**
   ```lua
   -- {{{ extract_title
   local function extract_title(filepath)
       local f = io.open(filepath, "r")
       if not f then return nil end

       for line in f:lines() do
           -- Look for first H1 heading
           local title = line:match("^#%s+(.+)")
           if title then
               f:close()
               return title
           end
       end

       f:close()
       return nil
   end
   -- }}}
   ```

5. **Implement tree rendering**
   ```lua
   -- {{{ render_tree
   local function render_tree(entries, indent, is_last_stack)
       local lines = {}
       indent = indent or 0
       is_last_stack = is_last_stack or {}

       for i, entry in ipairs(entries) do
           local is_last = (i == #entries)
           local prefix = ""

           -- Build tree prefix
           for j = 1, indent do
               if is_last_stack[j] then
                   prefix = prefix .. "    "
               else
                   prefix = prefix .. "│   "
               end
           end

           if is_last then
               prefix = prefix .. "└── "
           else
               prefix = prefix .. "├── "
           end

           if entry.type == "dir" then
               local display_name = config.dir_names[entry.name] or entry.name
               lines[#lines + 1] = prefix .. "**" .. display_name .. "/**"

               -- Recurse into directory
               is_last_stack[indent + 1] = is_last
               local child_lines = render_tree(entry.children, indent + 1, is_last_stack)
               for _, line in ipairs(child_lines) do
                   lines[#lines + 1] = line
               end
           else
               local rel_path = entry.path:gsub("^" .. config.docs_dir .. "/", "")
               local display = entry.title or entry.name:gsub("%.md$", "")
               lines[#lines + 1] = string.format("%s[%s](%s)", prefix, display, rel_path)
           end
       end

       return lines
   end
   -- }}}
   ```

6. **Implement TOC generation**
   ```lua
   -- {{{ generate_toc
   local function generate_toc()
       local entries = scan_docs(config.docs_dir)

       local lines = {
           "# Documentation Index",
           "",
           "Auto-generated table of contents for project documentation.",
           "",
           "Last updated: " .. os.date("%Y-%m-%d %H:%M"),
           "",
           "---",
           "",
           "```",
           "docs/",
       }

       local tree_lines = render_tree(entries, 0, {})
       for _, line in ipairs(tree_lines) do
           lines[#lines + 1] = line
       end

       lines[#lines + 1] = "```"
       lines[#lines + 1] = ""
       lines[#lines + 1] = "---"
       lines[#lines + 1] = ""
       lines[#lines + 1] = "*Generated by update-toc.lua*"

       return table.concat(lines, "\n")
   end
   -- }}}
   ```

7. **Implement update with preservation**
   ```lua
   -- {{{ update_toc
   local function update_toc()
       local existing = read_file(config.toc_file)
       local generated = generate_toc()

       if existing then
           -- Preserve any manual content after the tree
           local manual_section = existing:match("<!%-%- MANUAL %-%->(.-)")
           if manual_section then
               generated = generated .. "\n<!-- MANUAL -->\n" .. manual_section
           end
       end

       write_file(config.toc_file, generated)
   end
   -- }}}
   ```

8. **Add CLI interface**
   ```lua
   -- Modes:
   -- -g, --generate      Generate new TOC
   -- -u, --update        Update existing TOC
   -- -c, --check         Check if TOC is outdated
   -- -d, --diff          Show diff between current and generated
   -- --dry-run           Show what would be generated
   -- -I, --interactive   TUI mode
   ```

---

## Library Design

```lua
-- As CLI
-- lua update-toc.lua -u

-- As library
local toc = require("update-toc")
toc.init("/path/to/project")

local entries = toc.scan()
local content = toc.render(entries)
toc.write(content)

-- Or check if update needed
if toc.is_outdated() then
    toc.update()
end
```

### Exported Functions

| Function | Description |
|----------|-------------|
| `toc.init(dir)` | Initialize with project directory |
| `toc.scan()` | Scan docs directory structure |
| `toc.render(entries)` | Render entries as markdown tree |
| `toc.generate()` | Generate full TOC content |
| `toc.update()` | Update TOC file |
| `toc.is_outdated()` | Check if TOC needs update |
| `toc.diff()` | Get diff between current and generated |

---

## Output Example

```markdown
# Documentation Index

Auto-generated table of contents for project documentation.

Last updated: 2025-12-16 20:30

---

```
docs/
├── **File Format Specifications/**
│   ├── [MPQ Archive Format](formats/mpq-archive.md)
│   ├── [W3E Terrain Data](formats/w3e-terrain.md)
│   ├── [W3I Map Info](formats/w3i-map-info.md)
│   └── [WTS Trigger Strings](formats/wts-trigger-strings.md)
├── **Commit History/**
│   ├── [Phase 0 Commits](history/phase-0-commits.md)
│   └── [Phase 1 Commits](history/phase-1-commits.md)
├── [Project Roadmap](roadmap.md)
└── [Table of Contents](table-of-contents.md)
```

---

*Generated by update-toc.lua*
```

---

## Related Documents

- docs/table-of-contents.md (target file)
- CLAUDE.md (requirement source)
- /home/ritz/programming/ai-stuff/scripts/ (shared scripts)

---

## Acceptance Criteria

- [ ] Script lives in shared scripts directory
- [ ] Symlink created in project src/cli/
- [ ] Scans docs directory recursively
- [ ] Extracts document titles from H1 headings
- [ ] Generates tree-style hierarchy
- [ ] Updates existing TOC file
- [ ] Preserves manual annotations
- [ ] Check mode for CI integration
- [ ] Works as both CLI and library
- [ ] Project-abstract configuration

---

## Notes

This tool fulfills the CLAUDE.md requirement for documentation indexing.
The tree format provides visual clarity for documentation structure.

Consider running as a git pre-commit hook to keep TOC always current.

The preservation of manual sections (via HTML comments) allows for
custom descriptions or notes that shouldn't be auto-generated.
