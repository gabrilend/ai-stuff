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
    -- Phase divider configuration
    divider_width = 80,
    divider_char = "=",
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

-- {{{ Phase Divider Functions

-- {{{ generate_phase_divider
-- Generates a centered phase divider string with equal sign padding
-- Example: "============================= phase 4 issue files =============================="
local function generate_phase_divider(phase_num)
    local text = string.format("phase %d issue files", phase_num)
    local text_with_spaces = " " .. text .. " "
    local remaining = config.divider_width - #text_with_spaces
    local left_pad = math.floor(remaining / 2)
    local right_pad = remaining - left_pad

    return string.rep(config.divider_char, left_pad) ..
           text_with_spaces ..
           string.rep(config.divider_char, right_pad)
end
-- }}}

-- {{{ parse_phase_divider
-- Parses a line to detect if it's a phase divider, returns phase number or nil
-- Matches patterns like: "===== phase 4 issue files =====" (with optional comment prefix)
local function parse_phase_divider(line)
    -- Strip common comment prefixes
    local stripped = line
        :gsub("^%s*%-%-+%s*", "")   -- Lua: --
        :gsub("^%s*#%s*", "")        -- Shell/Python: #
        :gsub("^%s*//%s*", "")       -- C/JS: //
        :gsub("^%s*/%*%s*", "")      -- C block: /*
        :gsub("%s*%*/%s*$", "")      -- C block end: */
        :gsub("^%s*", "")            -- Leading whitespace
        :gsub("%s*$", "")            -- Trailing whitespace

    -- Match the divider pattern: =+ phase N issue files =+
    local phase_num = stripped:match("^=+%s*phase%s+(%d+)%s+issue%s+files%s*=+$")
    if phase_num then
        return tonumber(phase_num)
    end

    return nil
end
-- }}}

-- {{{ get_issue_phase
-- Determines the phase number from an issue ID
--
-- Supports two naming conventions:
--   1. Dash-separated: P-NNN-desc.md (e.g., "10-001" = phase 10, issue 1)
--   2. Numeric prefix: PNN-desc.md (e.g., "047" = phase 0, issue 47; "101" = phase 1, issue 1)
--
-- For numeric prefix format: first digit = phase, last two digits = issue
--   - 001-099: phase 0, issues 1-99
--   - 100-199: phase 1, issues 0-99
--   - 800-899: phase 8, issues 0-99
--
-- Also handles sub-issues like 101a, 101b, etc.
local function get_issue_phase(issue_id)
    -- First check for dash-separated format: "10-001" or "1-005"
    local explicit_phase = issue_id:match("^(%d+)%-")
    if explicit_phase then
        -- Check if this looks like explicit phase-issue format
        -- by seeing if there's another number after the dash
        local after_dash = issue_id:match("^%d+%-(%d)")
        if after_dash then
            return tonumber(explicit_phase)
        end
    end

    -- Extract just the numeric part (strip trailing letters for sub-issues)
    local num_part = issue_id:match("^(%d+)")
    if not num_part then return nil end

    local num = tonumber(num_part)
    if not num then return nil end

    -- Numeric prefix format: first digit = phase, last two digits = issue
    -- 047 = phase 0, issue 47
    -- 101 = phase 1, issue 01
    -- 800 = phase 8, issue 00
    return math.floor(num / 100)
end
-- }}}

-- {{{ discover_phase_issues
-- Discovers all issue files for a given phase number in a project
-- Returns a sorted list of issue file info: {path, name, id, title}
local function discover_phase_issues(project_path, phase_num)
    local issues = {}
    local issues_dir = project_path .. "/issues"

    if not dir_exists(issues_dir) then
        return issues
    end

    -- Search both active and completed issues
    local search_dirs = {
        issues_dir,
        issues_dir .. "/completed",
    }

    for _, search_dir in ipairs(search_dirs) do
        if dir_exists(search_dir) then
            -- Find all .md files with numeric prefixes
            local cmd = string.format("find %q -maxdepth 1 -name '[0-9]*.md' -type f 2>/dev/null",
                search_dir)
            local handle = io.popen(cmd)
            if handle then
                for filepath in handle:lines() do
                    local filename = filepath:match("([^/]+)$")
                    -- Parse issue ID and description from filename
                    -- Format: {ID}-{description}.md or {ID}{letter}-{description}.md
                    local issue_id, descr = filename:match("^(%d+[a-z]?)%-(.+)%.md$")

                    if issue_id then
                        local issue_phase = get_issue_phase(issue_id)
                        -- Verify this issue belongs to the requested phase
                        if issue_phase == phase_num then
                            -- Try to extract title from first heading in file
                            local title = descr:gsub("%-", " "):gsub("^%l", string.upper)
                            local file_handle = io.open(filepath, "r")
                            if file_handle then
                                for file_line in file_handle:lines() do
                                    local heading = file_line:match("^#%s+(.+)$")
                                    if heading then
                                        -- Clean up "Issue XXX:" prefix if present
                                        title = heading:gsub("^Issue%s+%d+:%s*", "")
                                        break
                                    end
                                end
                                file_handle:close()
                            end

                            local is_completed = filepath:match("/completed/") ~= nil
                            table.insert(issues, {
                                path = filepath,
                                name = filename,
                                id = issue_id,
                                title = title,
                                completed = is_completed,
                            })
                        end
                    end
                end
                handle:close()
            end
        end
    end

    -- Sort by issue ID (numeric part first, then letter suffix)
    table.sort(issues, function(a, b)
        local a_num = tonumber(a.id:match("^(%d+)")) or 0
        local b_num = tonumber(b.id:match("^(%d+)")) or 0
        if a_num ~= b_num then
            return a_num < b_num
        end
        -- Same number, sort by letter suffix
        local a_suffix = a.id:match("^%d+([a-z]*)$") or ""
        local b_suffix = b.id:match("^%d+([a-z]*)$") or ""
        return a_suffix < b_suffix
    end)

    return issues
end
-- }}}

-- {{{ scan_file_for_dividers
-- Scans a source file for phase dividers, returns list of {line_num, phase_num}
local function scan_file_for_dividers(filepath)
    local dividers = {}
    local handle = io.open(filepath, "r")
    if not handle then return dividers end

    local line_num = 0
    for line in handle:lines() do
        line_num = line_num + 1
        local phase = parse_phase_divider(line)
        if phase then
            table.insert(dividers, {
                line = line_num,
                phase = phase,
            })
        end
    end

    handle:close()
    return dividers
end
-- }}}

-- {{{ format_phase_issues_markdown
-- Formats a list of phase issues as markdown for insertion
local function format_phase_issues_markdown(issues, project_path, phase_num)
    local output = {}

    table.insert(output, "")
    table.insert(output, string.format("#### Phase %d Issues", phase_num))
    table.insert(output, "")

    if #issues == 0 then
        table.insert(output, string.format("_No phase %d issues found._", phase_num))
    else
        table.insert(output, "| ID | Issue | Status |")
        table.insert(output, "|----|-------|--------|")

        for _, issue in ipairs(issues) do
            local rel_path = make_relative_path(issue.path, project_path)
            local status = issue.completed and "✅ Completed" or "⏳ Active"
            table.insert(output, string.format(
                "| %s | [%s](%s) | %s |",
                issue.id, issue.title, rel_path, status
            ))
        end
    end

    table.insert(output, "")
    return output
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

                -- Scan for phase dividers in this file
                local dividers = scan_file_for_dividers(line)

                table.insert(files, {
                    path = line,
                    name = filename,
                    order = order,
                    is_indexed = is_indexed,
                    mtime = mtime,
                    dividers = dividers,  -- List of {line, phase} found in file
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

                        -- Add divider indicator if file contains phase dividers
                        local divider_note = ""
                        if file.dividers and #file.dividers > 0 then
                            local phases = {}
                            for _, div in ipairs(file.dividers) do
                                table.insert(phases, tostring(div.phase))
                            end
                            divider_note = " 📚"
                        end

                        table.insert(output, string.format(
                            "| %d | [%s](%s)%s | %s |",
                            i, file.name, rel_path, divider_note, file_desc
                        ))

                        -- Insert phase issues after the file row if dividers found
                        if file.dividers and #file.dividers > 0 then
                            table.insert(output, "")
                            for _, div in ipairs(file.dividers) do
                                local phase_issues = discover_phase_issues(project_path, div.phase)
                                local phase_md = format_phase_issues_markdown(phase_issues, project_path, div.phase)
                                for _, md_line in ipairs(phase_md) do
                                    table.insert(output, md_line)
                                end
                            end
                            -- Resume the main table if more files follow
                            if i < #indexed then
                                table.insert(output, "| # | File | Description |")
                                table.insert(output, "|---|------|-------------|")
                            end
                        end
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

                    for idx, file in ipairs(unindexed) do
                        local file_desc = extract_file_description(file.path)
                        local rel_path = make_relative_path(file.path, project_path)

                        -- Add divider indicator if file contains phase dividers
                        local divider_note = ""
                        if file.dividers and #file.dividers > 0 then
                            divider_note = " 📚"
                        end

                        table.insert(output, string.format(
                            "| [%s](%s)%s | %s | %s |",
                            file.name,
                            rel_path,
                            divider_note,
                            os.date("%Y-%m-%d", file.mtime),
                            file_desc
                        ))

                        -- Insert phase issues after the file row if dividers found
                        if file.dividers and #file.dividers > 0 then
                            table.insert(output, "")
                            for _, div in ipairs(file.dividers) do
                                local phase_issues = discover_phase_issues(project_path, div.phase)
                                local phase_md = format_phase_issues_markdown(phase_issues, project_path, div.phase)
                                for _, md_line in ipairs(phase_md) do
                                    table.insert(output, md_line)
                                end
                            end
                            -- Resume the main table if more files follow
                            if idx < #unindexed then
                                table.insert(output, "| File | Modified | Description |")
                                table.insert(output, "|------|----------|-------------|")
                            end
                        end
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
    --divider N         Generate a phase N divider string to copy into source files
    -h, --help          Show this help

EXAMPLES:
    generate-readme-toc.lua .
        Generate README.md for current directory

    generate-readme-toc.lua /path/to/project --dry-run
        Preview README without writing to file

    generate-readme-toc.lua . --output CONTENTS.md
        Write to custom filename

    generate-readme-toc.lua --divider 4
        Generate: ============================= phase 4 issue files ==============================

READ-ORDER PRIORITY:
    1. Numeric prefix in filename (001-, 02_, 1.) - curated order
    2. Modification date (newest first) - fallback for unindexed
    3. Alphabetical - last resort

PHASE DIVIDERS:
    Insert a divider comment in source files to automatically include phase issues.
    The divider format is: ===== phase N issue files ===== (centered in 80 chars)

    Example in Lua:
        -- ============================= phase 4 issue files ==============================

    Example in Shell:
        # ============================= phase 4 issue files ==============================

    When the script finds these dividers, it inserts a table of phase N issues
    at that point in the generated README, creating an interleaved narrative.
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
        elseif a:match("^%-%-divider=") then
            local phase = tonumber(a:match("^%-%-divider=(%d+)$"))
            if phase then
                print("Phase divider (copy into your source file):")
                print("")
                print("  Lua:    -- " .. generate_phase_divider(phase))
                print("  Shell:  # " .. generate_phase_divider(phase))
                print("  C/JS:   // " .. generate_phase_divider(phase))
                print("")
                print("Raw:      " .. generate_phase_divider(phase))
            else
                io.stderr:write("Error: --divider requires a phase number\n")
            end
            os.exit(0)
        elseif a:match("^%-%-divider$") then
            i = i + 1
            local phase = tonumber(arg[i])
            if phase then
                print("Phase divider (copy into your source file):")
                print("")
                print("  Lua:    -- " .. generate_phase_divider(phase))
                print("  Shell:  # " .. generate_phase_divider(phase))
                print("  C/JS:   // " .. generate_phase_divider(phase))
                print("")
                print("Raw:      " .. generate_phase_divider(phase))
            else
                io.stderr:write("Error: --divider requires a phase number\n")
            end
            os.exit(0)
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
