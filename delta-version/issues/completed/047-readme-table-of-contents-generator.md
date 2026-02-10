# Issue 047: README Table of Contents Generator

## Vision

Create a script that generates a "table of contents" style README.md for GitHub repositories, arranging source code files in **read-order** - the order a human reader should consume them to best understand the codebase. This supports the principle from CLAUDE.md: "code should be written like a story" with indexed filenames.

## Current Behavior

- No automated README generation based on source file ordering
- Developers must manually navigate and understand file relationships
- The CLAUDE.md convention of numeric filename prefixes (e.g., `001-module.lua`, `002-utils.lua`) isn't leveraged for documentation
- GitHub visitors see an alphabetically sorted file list, not a curated reading order

## Intended Behavior

A single command generates a README.md that serves as a "digital book" table of contents:

```bash
./scripts/generate-readme-toc.lua [project-path]
```

### Read-Order Priority

Files are arranged by:

1. **Primary**: Numeric prefix in filename (e.g., `001-`, `02-`, `1_`) - **curated order**
2. **Secondary**: Modification date (newest first) - **fallback for un-indexed files**
3. **Tertiary**: Alphabetical - **last resort**

### Example Output

```markdown
# project-name

Brief description from vision or notes files.

## Table of Contents

### Source Code (Read Order)

| # | File | Description |
|---|------|-------------|
| 1 | [001-main.lua](src/001-main.lua) | Entry point and initialization |
| 2 | [002-config.lua](src/002-config.lua) | Configuration loading and validation |
| 3 | [003-parser.lua](src/003-parser.lua) | Input parsing logic |
| 4 | [010-output.lua](src/010-output.lua) | Output generation |

### Libraries (By Last Modified)

| File | Modified | Description |
|------|----------|-------------|
| [utils.lua](libs/utils.lua) | 2026-02-09 | (Not curated - sorted by date) |
| [helpers.lua](libs/helpers.lua) | 2026-01-15 | (Not curated - sorted by date) |

### Documentation

| File | Description |
|------|-------------|
| [vision.md](notes/vision.md) | Project vision and goals |
| [roadmap.md](docs/roadmap.md) | Development phases |

### Issues

- [Active Issues](issues/)
- [Completed Issues](issues/completed/)
```

## Suggested Implementation Steps

### 1. Create Script Skeleton

```lua
#!/usr/bin/env luajit
-- generate-readme-toc.lua - Generate README.md with source code table of contents
--
-- Arranges files in "read-order" based on numeric prefixes in filenames,
-- falling back to modification date for un-indexed files.

-- {{{ Configuration
local DIR = arg[0]:match("(.*/)")
DIR = DIR and DIR:gsub("/scripts/$", "") or "."
local MONOREPO_ROOT = DIR:match("(.*)/.+$") or "."

local config = {
    output_file = "README.md",
    include_extensions = { "lua", "sh", "py", "c", "h", "js", "ts" },
    exclude_patterns = { "^%.", "%-done$", "%.test%.", "tmp/", "node_modules/" },
    source_dirs = { "src", "libs", "scripts" },
    doc_dirs = { "docs", "notes" },
}
-- }}}
```

### 2. Numeric Prefix Extraction

```lua
-- {{{ extract_read_order
local function extract_read_order(filename)
    -- Match various numeric prefix patterns:
    -- 001-name.lua, 02_name.lua, 1.name.lua, 10-name.lua
    local patterns = {
        "^(%d+)%-",      -- 001-name
        "^(%d+)_",       -- 001_name
        "^(%d+)%.",      -- 001.name
    }

    for _, pattern in ipairs(patterns) do
        local num = filename:match(pattern)
        if num then
            return tonumber(num), true  -- order, is_indexed
        end
    end

    return math.huge, false  -- No index, will sort by date
end
-- }}}
```

### 3. File Discovery and Sorting

```lua
-- {{{ discover_files
local function discover_files(dir, extensions)
    local files = {}

    -- Use find command to discover files
    local cmd = string.format(
        "find %q -type f \\( %s \\) 2>/dev/null",
        dir,
        table.concat(
            vim.tbl_map(function(ext) return "-name '*." .. ext .. "'" end, extensions),
            " -o "
        )
    )

    local handle = io.popen(cmd)
    if handle then
        for line in handle:lines() do
            local filename = line:match("([^/]+)$")
            local order, is_indexed = extract_read_order(filename)
            local mtime = get_modification_time(line)

            table.insert(files, {
                path = line,
                name = filename,
                order = order,
                is_indexed = is_indexed,
                mtime = mtime,
            })
        end
        handle:close()
    end

    -- Sort: indexed files by order, then un-indexed by mtime
    table.sort(files, function(a, b)
        if a.is_indexed and b.is_indexed then
            return a.order < b.order
        elseif a.is_indexed then
            return true  -- indexed files come first
        elseif b.is_indexed then
            return false
        else
            return a.mtime > b.mtime  -- newest first for un-indexed
        end
    end)

    return files
end
-- }}}
```

### 4. Description Extraction

```lua
-- {{{ extract_file_description
local function extract_file_description(filepath)
    -- Try to extract description from:
    -- 1. First comment line after shebang
    -- 2. First line of file if it's a markdown heading
    -- 3. Filename-based fallback

    local handle = io.open(filepath, "r")
    if not handle then return "" end

    local description = ""
    local line_count = 0

    for line in handle:lines() do
        line_count = line_count + 1
        if line_count > 10 then break end

        -- Skip shebang
        if line:match("^#!") then goto continue end

        -- Match comment with description
        local desc = line:match("^%-%-?%s*(.+)$")  -- Lua comment
            or line:match("^#%s*(.+)$")             -- Shell/Python comment
            or line:match("^//%s*(.+)$")            -- C/JS comment
            or line:match("^/%*%s*(.+)")            -- C block comment

        if desc and not desc:match("^{{{") then  -- Skip vim folds
            description = desc
            break
        end

        ::continue::
    end

    handle:close()
    return description
end
-- }}}
```

### 5. README Generation

```lua
-- {{{ generate_readme
local function generate_readme(project_path, project_name)
    local output = {}

    -- Header
    table.insert(output, "# " .. project_name)
    table.insert(output, "")

    -- Try to extract description from vision file
    local vision = read_file(project_path .. "/notes/vision")
    if vision then
        local first_para = vision:match("^(.-)%s*\n\n")
        if first_para then
            table.insert(output, first_para)
            table.insert(output, "")
        end
    end

    -- Table of Contents header
    table.insert(output, "## Table of Contents")
    table.insert(output, "")
    table.insert(output, "_Files arranged in read-order. Indexed files (numbered prefixes) are curated; others sorted by modification date._")
    table.insert(output, "")

    -- Source files section
    for _, src_dir in ipairs(config.source_dirs) do
        local full_path = project_path .. "/" .. src_dir
        if dir_exists(full_path) then
            table.insert(output, "### " .. src_dir:gsub("^%l", string.upper))
            table.insert(output, "")

            local files = discover_files(full_path, config.include_extensions)
            local indexed, unindexed = separate_by_indexed(files)

            if #indexed > 0 then
                table.insert(output, "| # | File | Description |")
                table.insert(output, "|---|------|-------------|")

                for i, file in ipairs(indexed) do
                    local desc = extract_file_description(file.path)
                    table.insert(output, string.format(
                        "| %d | [%s](%s) | %s |",
                        i, file.name, file.path:gsub(project_path .. "/", ""), desc
                    ))
                end
                table.insert(output, "")
            end

            if #unindexed > 0 then
                table.insert(output, "_Unindexed files (sorted by modification date):_")
                table.insert(output, "")
                table.insert(output, "| File | Modified | Description |")
                table.insert(output, "|------|----------|-------------|")

                for _, file in ipairs(unindexed) do
                    local desc = extract_file_description(file.path)
                    table.insert(output, string.format(
                        "| [%s](%s) | %s | %s |",
                        file.name,
                        file.path:gsub(project_path .. "/", ""),
                        os.date("%Y-%m-%d", file.mtime),
                        desc
                    ))
                end
                table.insert(output, "")
            end
        end
    end

    -- Documentation section
    table.insert(output, "### Documentation")
    table.insert(output, "")
    -- ... similar pattern for docs

    -- Footer
    table.insert(output, "---")
    table.insert(output, "")
    table.insert(output, string.format(
        "_Generated by [delta-version/scripts/generate-readme-toc.lua](../delta-version/scripts/generate-readme-toc.lua) on %s_",
        os.date("%Y-%m-%d")
    ))

    return table.concat(output, "\n")
end
-- }}}
```

### 6. CLI Interface

```lua
-- {{{ main
local function main()
    local project_path = arg[1] or "."
    local project_name = project_path:match("([^/]+)$") or "project"

    -- Validate project exists
    if not dir_exists(project_path) then
        io.stderr:write("Error: Directory not found: " .. project_path .. "\n")
        os.exit(1)
    end

    -- Generate README
    local content = generate_readme(project_path, project_name)

    -- Write output
    local output_path = project_path .. "/" .. config.output_file
    local handle = io.open(output_path, "w")
    if handle then
        handle:write(content)
        handle:close()
        print("Generated: " .. output_path)
    else
        io.stderr:write("Error: Could not write to " .. output_path .. "\n")
        os.exit(1)
    end
end

main()
-- }}}
```

## CLI Options

```
Usage: generate-readme-toc.lua [OPTIONS] [PROJECT_PATH]

OPTIONS:
    --dry-run           Print to stdout instead of writing file
    --output FILE       Output filename (default: README.md)
    --include EXT       Include file extension (can repeat)
    --exclude PATTERN   Exclude pattern (can repeat)
    --no-description    Skip extracting descriptions from files
    -h, --help          Show this help

EXAMPLES:
    generate-readme-toc.lua .
        Generate README.md for current project

    generate-readme-toc.lua /path/to/project --dry-run
        Preview README without writing

    generate-readme-toc.lua . --output CONTENTS.md
        Write to custom filename
```

## File Locations

- **Script**: `delta-version/scripts/generate-readme-toc.lua`
- **Output**: `<project>/README.md` (per-project)

## Integration Points

- **Issue 044**: Complements directory tree generator (structure vs. read-order)
- **Issue 023**: Uses `list-projects.sh` for batch generation across all projects
- **CLAUDE.md**: Respects the "code as story" convention with indexed filenames

## Acceptance Criteria

- [ ] Extracts numeric prefixes from filenames (001-, 02_, 1., etc.)
- [ ] Sorts indexed files by numeric order
- [ ] Falls back to modification date for un-indexed files
- [ ] Generates valid GitHub markdown tables
- [ ] Extracts descriptions from first comment line
- [ ] Handles multiple source directories (src, libs, scripts)
- [ ] Includes documentation section
- [ ] Supports --dry-run mode
- [ ] Works on any project in the monorepo
- [ ] Uses vim folds per CLAUDE.md conventions

## Metadata

- **Priority**: Medium
- **Complexity**: Medium
- **Dependencies**: None (standalone utility)
- **Related**: Issue 044 (directory trees), Issue 023 (project discovery)

## Notes

The "read-order" concept treats source code like a book - files with numeric prefixes are chapters meant to be read sequentially, while un-indexed files are supplementary material sorted by recency (what the author worked on most recently is likely most relevant).

This supports the CLAUDE.md principle: "all source-code files must have an index at the beginning of the filename, so they can be read in order."

The modification date fallback ensures all files appear in the table of contents, even if not yet curated, while clearly marking them as "not curated - sorted by date" to encourage developers to add numeric prefixes for better organization.
