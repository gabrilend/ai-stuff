#!/usr/bin/env lua

-- {{{ Pure HTML Project File Server Generator
-- Generates a pure HTML interface for browsing programming projects.
-- Uses file:// protocol links and native <details>/<summary> for collapsible folders.
-- No CSS. No JavaScript. Just HTML.
--
-- Issue 007 RESOLVED: Converted to pure HTML output.
-- }}}

-- Configure shared library path
local SCRIPT_DIR = "/home/ritz/programming/ai-stuff"
package.path = SCRIPT_DIR .. "/libs/lua/?.lua;" .. package.path

-- Default scan directory - can be overridden via first argument
local DIR = SCRIPT_DIR
if arg and arg[1] then
    DIR = arg[1]
end

-- Output path - can be overridden via second argument
local OUTPUT_PATH = SCRIPT_DIR .. "/project-file-server.html"
if arg and arg[2] then
    OUTPUT_PATH = arg[2]
end

-- {{{ execute_command
local function execute_command(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result:gsub("%s+$", "") -- trim trailing whitespace
end
-- }}}

-- {{{ format_size
local function format_size(bytes)
    if bytes < 1024 then
        return bytes .. "B"
    elseif bytes < 1024 * 1024 then
        return string.format("%.1fK", bytes / 1024)
    elseif bytes < 1024 * 1024 * 1024 then
        return string.format("%.1fM", bytes / (1024 * 1024))
    else
        return string.format("%.1fG", bytes / (1024 * 1024 * 1024))
    end
end
-- }}}

-- {{{ scan_directory_bash
local function scan_directory_bash(path, max_depth, current_depth)
    current_depth = current_depth or 0
    max_depth = max_depth or 3

    if current_depth >= max_depth then
        return {}
    end

    -- Use find command to list directories and files
    local find_cmd = string.format('find "%s" -maxdepth 1 -type d -not -path "%s" -not -name ".*" 2>/dev/null | sort', path, path)
    local dirs_output = execute_command(find_cmd)

    local find_files_cmd = string.format('find "%s" -maxdepth 1 -type f -not -name ".*" 2>/dev/null | sort', path)
    local files_output = execute_command(find_files_cmd)

    local items = {}

    -- Process directories
    for dir_path in dirs_output:gmatch("[^\n]+") do
        local dir_name = dir_path:match("([^/]+)$")
        if dir_name then
            local size_cmd = string.format('du -sb "%s" 2>/dev/null | cut -f1', dir_path)
            local size_str = execute_command(size_cmd)
            -- Clean the string and convert to number
            size_str = size_str:gsub("%s+", "")
            local dir_size = tonumber(size_str) or 0

            local children = scan_directory_bash(dir_path, max_depth, current_depth + 1)
            table.insert(items, {
                name = dir_name,
                path = dir_path,
                type = "directory",
                size = dir_size,
                children = children
            })
        end
    end

    -- Process files
    for file_path in files_output:gmatch("[^\n]+") do
        local file_name = file_path:match("([^/]+)$")
        if file_name then
            local size_cmd = string.format('stat -c%%s "%s" 2>/dev/null || echo "0"', file_path)
            local size_str = execute_command(size_cmd)
            -- Clean the string and convert to number
            size_str = size_str:gsub("%s+", "")
            local file_size = tonumber(size_str) or 0

            table.insert(items, {
                name = file_name,
                path = file_path,
                type = "file",
                size = file_size
            })
        end
    end

    return items
end
-- }}}

-- {{{ get_project_analysis
local function get_project_analysis(path)
    local analysis = {}

    -- Count different file types
    local file_types = {}
    local type_cmd = string.format('find "%s" -type f -name "*.*" 2>/dev/null | sed "s/.*\\.//" | sort | uniq -c | sort -nr | head -15', path)
    local type_output = execute_command(type_cmd)

    for line in type_output:gmatch("[^\n]+") do
        local count, ext = line:match("%s*(%d+)%s+(.+)")
        if count and ext then
            table.insert(file_types, {ext = ext, count = tonumber(count)})
        end
    end

    -- Get total file count
    local file_count_cmd = string.format('find "%s" -type f 2>/dev/null | wc -l', path)
    local file_count = execute_command(file_count_cmd)

    -- Get directory count
    local dir_count_cmd = string.format('find "%s" -type d 2>/dev/null | wc -l', path)
    local dir_count = execute_command(dir_count_cmd)

    -- Get total size
    local size_cmd = string.format('du -sh "%s" 2>/dev/null | cut -f1', path)
    local total_size = execute_command(size_cmd)

    return {
        file_count = tonumber(file_count) or 0,
        dir_count = tonumber(dir_count) or 0,
        file_types = file_types,
        total_size = total_size
    }
end
-- }}}

-- {{{ generate_stats_text
local function generate_stats_text(analysis)
    local lines = {}

    table.insert(lines, "--------------------------------------------------------------------------------")
    table.insert(lines, "                              STATISTICS")
    table.insert(lines, "--------------------------------------------------------------------------------")
    table.insert(lines, "")
    table.insert(lines, string.format("  Total Files:       %d", analysis.file_count))
    table.insert(lines, string.format("  Total Directories: %d", analysis.dir_count))
    table.insert(lines, string.format("  Total Size:        %s", analysis.total_size))
    table.insert(lines, "")
    table.insert(lines, "  Top File Types:")

    for i, ft in ipairs(analysis.file_types) do
        if i <= 10 then
            table.insert(lines, string.format("    .%-12s %5d files", ft.ext, ft.count))
        end
    end

    table.insert(lines, "")

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ generate_tree_html
local function generate_tree_html(items, level)
    level = level or 0
    local html = ""
    local indent = string.rep("    ", level)

    for _, item in ipairs(items) do
        if item.type == "directory" then
            local has_children = item.children and #item.children > 0
            local size_str = format_size(item.size)

            if has_children then
                -- Use <details><summary> for collapsible directories
                html = html .. indent .. "<details>\n"
                html = html .. indent .. "<summary>"
                html = html .. '<a href="file://' .. item.path .. '">' .. item.name .. '/</a>'
                html = html .. " (" .. size_str .. ")"
                html = html .. "</summary>\n"
                html = html .. generate_tree_html(item.children, level + 1)
                html = html .. indent .. "</details>\n"
            else
                -- Empty directory - just a link
                html = html .. indent .. '<a href="file://' .. item.path .. '">' .. item.name .. '/</a>'
                html = html .. " (" .. size_str .. ")<br>\n"
            end
        else
            -- File - simple link
            local size_str = format_size(item.size)
            html = html .. indent .. '<a href="file://' .. item.path .. '">' .. item.name .. '</a>'
            html = html .. " (" .. size_str .. ")<br>\n"
        end
    end

    return html
end
-- }}}

-- {{{ generate_quick_links
local function generate_quick_links()
    local links = {
        {path = "/mnt/mtwo/programming", name = "Programming Root"},
        {path = "/mnt/mtwo/programming/ai-stuff", name = "AI Projects"},
        {path = "/mnt/mtwo/programming/ai-stuff/delta-version", name = "Delta-Version"},
        {path = "/mnt/mtwo/programming/rust", name = "Rust Projects"},
        {path = "/mnt/mtwo/programming/lua", name = "Lua Projects"},
        {path = "/home/ritz/programming/ai-stuff", name = "AI-Stuff (Home)"},
    }

    local html = ""
    for _, link in ipairs(links) do
        html = html .. string.format('  <a href="file://%s">%s</a>\n', link.path, link.name)
    end

    return html
end
-- }}}

-- {{{ generate_html_page
local function generate_html_page(tree_data, root_path, analysis)
    local html = [[
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Project File Server</title>
</head>
<body>
<pre>
================================================================================
                          PROJECT FILE SERVER
================================================================================

  Root Path: ]] .. root_path .. [[

  Generated: ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[


]] .. generate_stats_text(analysis) .. [[
--------------------------------------------------------------------------------
                             QUICK LINKS
--------------------------------------------------------------------------------

]] .. generate_quick_links() .. [[
================================================================================
                            DIRECTORY TREE
================================================================================
</pre>

]] .. generate_tree_html(tree_data) .. [[

<hr>
<pre>
================================================================================
  Use Ctrl+F to search | Click triangles to expand/collapse directories
  Click any link to open in your file manager
================================================================================
</pre>
</body>
</html>
]]

    return html
end
-- }}}

-- {{{ main
local function main()
    local root_path = DIR

    print("Scanning directories from: " .. root_path)
    print("This may take a moment...")

    local tree_data = scan_directory_bash(root_path, 3)

    if not tree_data then
        print("Error: Could not scan directory " .. root_path)
        os.exit(1)
    end

    print("Gathering statistics...")
    local analysis = get_project_analysis(root_path)

    print("Generating pure HTML file server...")
    local html_content = generate_html_page(tree_data, root_path, analysis)

    local file = io.open(OUTPUT_PATH, "w")
    if not file then
        print("Error: Could not create output file " .. OUTPUT_PATH)
        os.exit(1)
    end

    file:write(html_content)
    file:close()

    print("")
    print("Pure HTML file server generated!")
    print("Output: " .. OUTPUT_PATH)
    print("")
    print("To view in Firefox:")
    print("  firefox " .. OUTPUT_PATH)
    print("")
    print("Or start an HTTP server:")
    print("  cd " .. SCRIPT_DIR)
    print("  python3 -m http.server 8080")
    print("  # Then open http://localhost:8080/project-file-server.html")
end
-- }}}

main()
