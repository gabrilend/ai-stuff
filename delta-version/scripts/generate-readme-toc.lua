#!/usr/bin/env luajit
-- generate-readme-toc.lua - Generate README.md with source code table of contents
--
-- Arranges files in "read-order" based on numeric prefixes in filenames,
-- falling back to modification date for un-indexed files. Treats source code
-- like a book with chapters (indexed files) and supplementary material (unindexed).
--
-- Usage: generate-readme-toc.lua [OPTIONS] [PROJECT_PATH]

-- {{{ DIR Configuration
-- Hard-coded path for running from any directory
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
-- Allow override via argument
if arg[1] and arg[1]:match("^%-%-dir=") then
    DIR = arg[1]:match("^%-%-dir=(.+)$")
    table.remove(arg, 1)
end
local MONOREPO_ROOT = DIR:match("(.*)/.+$") or "."
-- }}}

-- {{{ Configuration
local config = {
    output_file = "README.md",
    include_extensions = { "lua", "sh", "py", "c", "h", "js", "ts", "go", "rs" },
    exclude_patterns = {
        "^%.",           -- hidden files
        "%-done$",       -- deprecated files
        "%.test%.",      -- test files
        "%.spec%.",      -- spec files
        "tmp/",          -- temp directories
        "node_modules/", -- npm modules
        "%.min%.",       -- minified files
    },
    source_dirs = { "src", "libs", "scripts" },
    doc_dirs = { "docs", "notes" },
    dry_run = false,
    no_description = false,
}
-- }}}

-- {{{ Utility Functions

-- {{{ dir_exists
local function dir_exists(path)
    local handle = io.popen('test -d ' .. string.format('%q', path) .. ' && echo yes || echo no')
    if not handle then return false end
    local result = handle:read("*a"):gsub("%s+", "")
    handle:close()
    return result == "yes"
end
-- }}}

-- {{{ file_exists
local function file_exists(path)
    local handle = io.open(path, "r")
    if handle then
        handle:close()
        return true
    end
    return false
end
-- }}}

-- {{{ read_file
local function read_file(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local content = handle:read("*a")
    handle:close()
    return content
end
-- }}}

-- {{{ get_modification_time
local function get_modification_time(filepath)
    -- Use stat to get modification time as epoch
    local cmd = string.format("stat -c %%Y %q 2>/dev/null", filepath)
    local handle = io.popen(cmd)
    if not handle then return 0 end
    local result = handle:read("*a"):gsub("%s+", "")
    handle:close()
    return tonumber(result) or 0
end
-- }}}

-- {{{ matches_exclude_pattern
local function matches_exclude_pattern(filepath)
    for _, pattern in ipairs(config.exclude_patterns) do
        if filepath:match(pattern) then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ escape_markdown
local function escape_markdown(text)
    -- Escape pipe characters for markdown tables
    return text:gsub("|", "\\|"):gsub("\n", " ")
end
-- }}}

-- {{{ escape_pattern
-- Escapes Lua pattern special characters in a string
local function escape_pattern(str)
    -- Pattern special chars: ^$()%.[]*+-?
    return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end
-- }}}

-- {{{ make_relative_path
-- Converts an absolute path to a relative path from a base directory
local function make_relative_path(filepath, base_path)
    local escaped_base = escape_pattern(base_path)
    return filepath:gsub("^" .. escaped_base .. "/", "")
end
-- }}}

-- }}}

-- {{{ extract_read_order
-- Extracts the numeric read-order from a filename
-- Returns: order_number, is_indexed
local function extract_read_order(filename)
    -- Match various numeric prefix patterns:
    -- 001-name.lua, 02_name.lua, 1.name.lua, 10-name.lua
    local patterns = {
        "^(%d+)%-",      -- 001-name
        "^(%d+)_",       -- 001_name
        "^(%d+)%.",      -- 001.name (but not extension)
    }

    -- Extract just the filename without path
    local base = filename:match("([^/]+)$") or filename

    for _, pattern in ipairs(patterns) do
        local num = base:match(pattern)
        if num then
            return tonumber(num), true  -- order, is_indexed
        end
    end

    return math.huge, false  -- No index, will sort by date
end
-- }}}

-- {{{ extract_file_description
-- Extracts a description from the first meaningful comment in a file
local function extract_file_description(filepath)
    if config.no_description then
        return ""
    end

    local handle = io.open(filepath, "r")
    if not handle then return "" end

    local description = ""
    local line_count = 0

    for line in handle:lines() do
        line_count = line_count + 1
        if line_count > 15 then break end  -- only check first 15 lines

        -- Skip shebang
        if line:match("^#!") then goto continue end

        -- Skip empty lines
        if line:match("^%s*$") then goto continue end

        -- Skip vim fold markers
        if line:match("{{{") or line:match("}}}") then goto continue end

        -- Match comment with description
        local desc = line:match("^%-%-+%s*(.+)$")        -- Lua comment: --
            or line:match("^#%s+(.+)$")                   -- Shell/Python comment: # (with space)
            or line:match("^//%s*(.+)$")                  -- C/JS comment: //
            or line:match("^/%*%s*(.+)%s*%*?/?$")        -- C block comment: /* ... */
            or line:match("^%-%-%[%[%s*(.+)")            -- Lua multiline: --[[
            or line:match("^'''%s*(.+)")                  -- Python docstring: '''
            or line:match('^"""%s*(.+)')                  -- Python docstring: """

        if desc then
            -- Clean up the description
            desc = desc:gsub("^%-+%s*", "")  -- Remove leading dashes
            desc = desc:gsub("%s+$", "")      -- Trim trailing whitespace

            -- Skip if it's just a separator line
            if not desc:match("^[-=_]+$") and #desc > 3 then
                description = desc
                break
            end
        end

        ::continue::
    end

    handle:close()
    return escape_markdown(description)
end
-- }}}

-- {{{ discover_files
-- Discovers all relevant files in a directory
local function discover_files(dir, extensions)
    local files = {}

    if not dir_exists(dir) then
        return files
    end

    -- Build find command for extensions
    local ext_patterns = {}
    for _, ext in ipairs(extensions) do
        table.insert(ext_patterns, "-name '*." .. ext .. "'")
    end
    local ext_clause = "\\( " .. table.concat(ext_patterns, " -o ") .. " \\)"

    local cmd = string.format(
        "find %q -type f %s 2>/dev/null",
        dir,
        ext_clause
    )

    local handle = io.popen(cmd)
    if handle then
        for line in handle:lines() do
            -- Skip excluded patterns
            if not matches_exclude_pattern(line) then
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
        end
        handle:close()
    end

    -- Sort: indexed files by order, then un-indexed by mtime (newest first)
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

-- {{{ separate_by_indexed
-- Separates files into indexed and unindexed groups
local function separate_by_indexed(files)
    local indexed = {}
    local unindexed = {}

    for _, file in ipairs(files) do
        if file.is_indexed then
            table.insert(indexed, file)
        else
            table.insert(unindexed, file)
        end
    end

    return indexed, unindexed
end
-- }}}

-- {{{ extract_project_description
-- Tries to extract a project description from vision or notes files
local function extract_project_description(project_path)
    -- Try common vision/description locations
    local candidates = {
        project_path .. "/notes/vision",
        project_path .. "/notes/vision.md",
        project_path .. "/docs/vision.md",
        project_path .. "/DESCRIPTION",
        project_path .. "/notes/README.md",
    }

    for _, path in ipairs(candidates) do
        local content = read_file(path)
        if content then
            -- Extract first paragraph (up to double newline)
            local first_para = content:match("^(.-)%s*\n\n")
            if first_para then
                -- Clean up markdown headers
                first_para = first_para:gsub("^#+%s*", "")
                return first_para:gsub("\n", " ")
            end
        end
    end

    return nil
end
-- }}}

-- {{{ generate_readme
-- Generates the README.md content for a project
local function generate_readme(project_path, project_name)
    local output = {}

    -- Header
    table.insert(output, "# " .. project_name)
    table.insert(output, "")

    -- Try to extract description from vision file
    local desc = extract_project_description(project_path)
    if desc then
        table.insert(output, desc)
        table.insert(output, "")
    end

    -- Table of Contents header
    table.insert(output, "## Table of Contents")
    table.insert(output, "")
    table.insert(output, "_Files arranged in read-order. Indexed files (with numeric prefixes) are curated; unindexed files are sorted by modification date._")
    table.insert(output, "")

    -- Process each source directory
    local has_source_content = false
    for _, src_dir in ipairs(config.source_dirs) do
        local full_path = project_path .. "/" .. src_dir
        if dir_exists(full_path) then
            local files = discover_files(full_path, config.include_extensions)

            if #files > 0 then
                has_source_content = true
                -- Capitalize first letter for header
                local header = src_dir:gsub("^%l", string.upper)
                table.insert(output, "### " .. header)
                table.insert(output, "")

                local indexed, unindexed = separate_by_indexed(files)

                -- Indexed files (curated order)
                if #indexed > 0 then
                    table.insert(output, "| # | File | Description |")
                    table.insert(output, "|---|------|-------------|")

                    for i, file in ipairs(indexed) do
                        local file_desc = extract_file_description(file.path)
                        local rel_path = make_relative_path(file.path, project_path)
                        table.insert(output, string.format(
                            "| %d | [%s](%s) | %s |",
                            i, file.name, rel_path, file_desc
                        ))
                    end
                    table.insert(output, "")
                end

                -- Unindexed files (sorted by modification date)
                if #unindexed > 0 then
                    if #indexed > 0 then
                        table.insert(output, "_Unindexed files (sorted by modification date):_")
                        table.insert(output, "")
                    end
                    table.insert(output, "| File | Modified | Description |")
                    table.insert(output, "|------|----------|-------------|")

                    for _, file in ipairs(unindexed) do
                        local file_desc = extract_file_description(file.path)
                        local rel_path = make_relative_path(file.path, project_path)
                        table.insert(output, string.format(
                            "| [%s](%s) | %s | %s |",
                            file.name,
                            rel_path,
                            os.date("%Y-%m-%d", file.mtime),
                            file_desc
                        ))
                    end
                    table.insert(output, "")
                end
            end
        end
    end

    if not has_source_content then
        table.insert(output, "_No source files found in standard directories (src, libs, scripts)._")
        table.insert(output, "")
    end

    -- Documentation section
    local has_docs = false
    local doc_files = {}

    for _, doc_dir in ipairs(config.doc_dirs) do
        local full_path = project_path .. "/" .. doc_dir
        if dir_exists(full_path) then
            -- Look for markdown files
            local cmd = string.format("find %q -name '*.md' -type f 2>/dev/null | head -20", full_path)
            local handle = io.popen(cmd)
            if handle then
                for line in handle:lines() do
                    if not matches_exclude_pattern(line) then
                        local filename = line:match("([^/]+)$")
                        local rel_path = make_relative_path(line, project_path)
                        table.insert(doc_files, {
                            name = filename,
                            path = rel_path,
                            dir = doc_dir,
                        })
                        has_docs = true
                    end
                end
                handle:close()
            end
        end
    end

    if has_docs then
        table.insert(output, "### Documentation")
        table.insert(output, "")
        table.insert(output, "| File | Location |")
        table.insert(output, "|------|----------|")

        for _, doc in ipairs(doc_files) do
            table.insert(output, string.format(
                "| [%s](%s) | %s |",
                doc.name, doc.path, doc.dir
            ))
        end
        table.insert(output, "")
    end

    -- Issues section (if exists)
    if dir_exists(project_path .. "/issues") then
        table.insert(output, "### Issues")
        table.insert(output, "")
        table.insert(output, "- [Active Issues](issues/)")
        if dir_exists(project_path .. "/issues/completed") then
            table.insert(output, "- [Completed Issues](issues/completed/)")
        end
        table.insert(output, "")
    end

    -- Footer
    table.insert(output, "---")
    table.insert(output, "")
    table.insert(output, string.format(
        "_Generated by [generate-readme-toc.lua](https://github.com/gabrilend/ai-stuff/blob/master/delta-version/scripts/generate-readme-toc.lua) on %s_",
        os.date("%Y-%m-%d")
    ))

    return table.concat(output, "\n")
end
-- }}}

-- {{{ print_usage
local function print_usage()
    print([[
Usage: generate-readme-toc.lua [OPTIONS] [PROJECT_PATH]

Generates a README.md with source code table of contents arranged in "read-order".
Files with numeric prefixes (e.g., 001-main.lua) are sorted by that order;
unindexed files fall back to modification date (newest first).

OPTIONS:
    --dry-run           Print to stdout instead of writing file
    --output FILE       Output filename (default: README.md)
    --no-description    Skip extracting descriptions from source files
    --dir=PATH          Override delta-version directory path
    -h, --help          Show this help

EXAMPLES:
    generate-readme-toc.lua .
        Generate README.md for current directory

    generate-readme-toc.lua /path/to/project --dry-run
        Preview README without writing to file

    generate-readme-toc.lua . --output CONTENTS.md
        Write to custom filename

READ-ORDER PRIORITY:
    1. Numeric prefix in filename (001-, 02_, 1.) - curated order
    2. Modification date (newest first) - fallback for unindexed
    3. Alphabetical - last resort
]])
end
-- }}}

-- {{{ parse_args
local function parse_args()
    local project_path = "."

    local i = 1
    while i <= #arg do
        local a = arg[i]

        if a == "-h" or a == "--help" then
            print_usage()
            os.exit(0)
        elseif a == "--dry-run" then
            config.dry_run = true
        elseif a == "--no-description" then
            config.no_description = true
        elseif a:match("^%-%-output=") then
            config.output_file = a:match("^%-%-output=(.+)$")
        elseif a:match("^%-%-output$") then
            i = i + 1
            config.output_file = arg[i]
        elseif not a:match("^%-") then
            project_path = a
        else
            io.stderr:write("Unknown option: " .. a .. "\n")
            print_usage()
            os.exit(1)
        end

        i = i + 1
    end

    return project_path
end
-- }}}

-- {{{ normalize_path
-- Resolves a path to absolute and cleans up /./ and trailing slashes
local function normalize_path(path)
    -- Resolve to absolute path if relative
    if not path:match("^/") then
        local handle = io.popen("pwd")
        if handle then
            local pwd = handle:read("*a"):gsub("%s+$", "")
            handle:close()
            path = pwd .. "/" .. path
        end
    end

    -- Clean up path: remove /. and trailing slashes
    path = path:gsub("/%.$", "")     -- Remove trailing /.
    path = path:gsub("/%.%f[/]", "") -- Remove /. in middle of path
    path = path:gsub("/$", "")       -- Remove trailing slash

    return path
end
-- }}}

-- {{{ main
local function main()
    local project_path = parse_args()

    -- Normalize the path
    project_path = normalize_path(project_path)

    -- Extract project name from path
    local project_name = project_path:match("([^/]+)$") or "project"

    -- Validate project exists
    if not dir_exists(project_path) then
        io.stderr:write("Error: Directory not found: " .. project_path .. "\n")
        os.exit(1)
    end

    -- Generate README content
    local content = generate_readme(project_path, project_name)

    if config.dry_run then
        -- Print to stdout
        print(content)
    else
        -- Write to file
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
end

main()
-- }}}
