#!/usr/bin/env lua

-- {{{ Enhanced Project File Server Generator
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
if arg and arg[1] then
    DIR = arg[1]
end

-- Load required libraries
local json = require('libs.dkjson')

-- {{{ execute_command
local function execute_command(cmd)
-- }}}
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result:gsub("%s+$", "") -- trim trailing whitespace
end

-- {{{ scan_directory_bash
local function scan_directory_bash(path, max_depth, current_depth)
-- }}}
    current_depth = current_depth or 0
    max_depth = max_depth or 2
    
    if current_depth >= max_depth then
        return {}
    end
    
    -- Use find command to list directories and files
    local find_cmd = string.format('find "%s" -maxdepth 1 -type d -not -path "%s" -not -name ".*" | sort', path, path)
    local dirs_output = execute_command(find_cmd)
    
    local find_files_cmd = string.format('find "%s" -maxdepth 1 -type f -not -name ".*" | sort', path)
    local files_output = execute_command(find_files_cmd)
    
    local items = {}
    
    -- Process directories
    for dir_path in dirs_output:gmatch("[^\n]+") do
        local dir_name = dir_path:match("([^/]+)$")
        if dir_name then
            local size_cmd = string.format('du -sh "%s" 2>/dev/null | cut -f1', dir_path)
            local dir_size = execute_command(size_cmd)
            
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
            local size_output = execute_command(size_cmd)
            local file_size = tonumber(size_output) or 0
            
            table.insert(items, {
                name = file_name,
                path = file_path,
                type = "file",
                size = math.floor(file_size / 1024) .. " KB"
            })
        end
    end
    
    return items
end

-- {{{ get_project_analysis
local function get_project_analysis(path)
-- }}}
    local analysis = {}
    
    -- Count different file types
    local file_types = {}
    local type_cmd = string.format('find "%s" -type f -name "*.*" | sed "s/.*\\.//" | sort | uniq -c | sort -nr', path)
    local type_output = execute_command(type_cmd)
    
    for line in type_output:gmatch("[^\n]+") do
        local count, ext = line:match("%s*(%d+)%s+(.+)")
        if count and ext then
            table.insert(file_types, {ext = ext, count = tonumber(count)})
        end
    end
    
    -- Get total file count
    local file_count_cmd = string.format('find "%s" -type f | wc -l', path)
    local file_count = execute_command(file_count_cmd)
    
    -- Get directory count
    local dir_count_cmd = string.format('find "%s" -type d | wc -l', path)
    local dir_count = execute_command(dir_count_cmd)
    
    -- Look for common project files
    local project_files = {"README.md", "package.json", "Cargo.toml", "CMakeLists.txt", "Makefile", ".gitignore", "LICENSE"}
    local found_files = {}
    
    for _, file in ipairs(project_files) do
        local check_cmd = string.format('find "%s" -maxdepth 2 -name "%s" | head -1', path, file)
        local found = execute_command(check_cmd)
        if found and found ~= "" then
            table.insert(found_files, file)
        end
    end
    
    return {
        file_count = tonumber(file_count) or 0,
        dir_count = tonumber(dir_count) or 0,
        file_types = file_types,
        project_files = found_files
    }
end

-- {{{ get_related_directories
local function get_related_directories(current_path)
-- }}}
    local related = {}
    local base_programming = "/mnt/mtwo/programming"
    
    -- Find directories with similar names
    local current_name = current_path:match("([^/]+)$")
    if current_name then
        local similar_cmd = string.format('find "%s" -maxdepth 2 -type d -iname "*%s*" -not -path "%s"', 
                                        base_programming, current_name, current_path)
        local similar_output = execute_command(similar_cmd)
        
        for dir_path in similar_output:gmatch("[^\n]+") do
            local dir_name = dir_path:match("([^/]+)$")
            if dir_name then
                table.insert(related, {name = dir_name, path = dir_path})
            end
        end
    end
    
    -- Add commonly related project types
    local common_related = {
        {pattern = "ai%-", desc = "AI/ML Projects"},
        {pattern = "web%-", desc = "Web Development"},
        {pattern = "game%-", desc = "Game Development"},
        {pattern = "tool", desc = "Development Tools"}
    }
    
    for _, rel in ipairs(common_related) do
        local pattern_cmd = string.format('find "%s" -maxdepth 2 -type d -iname "*%s*"', base_programming, rel.pattern)
        local pattern_output = execute_command(pattern_cmd)
        
        if pattern_output and pattern_output ~= "" then
            table.insert(related, {name = rel.desc, path = "category", dirs = {}})
            for dir_path in pattern_output:gmatch("[^\n]+") do
                local dir_name = dir_path:match("([^/]+)$")
                if dir_name then
                    table.insert(related[#related].dirs, {name = dir_name, path = dir_path})
                end
            end
        end
    end
    
    return related
end

-- {{{ generate_sidebar_html
local function generate_sidebar_html()
-- }}}
    local programming_root = "/mnt/mtwo/programming"
    local analysis = get_project_analysis(programming_root)
    local related = get_related_directories(programming_root)
    
    local sidebar = [[
        <div class="sidebar">
            <div class="sidebar-section">
                <h3>📊 Project Statistics</h3>
                <div class="stat-item">
                    <span class="stat-label">Total Files:</span>
                    <span class="stat-value">]] .. analysis.file_count .. [[</span>
                </div>
                <div class="stat-item">
                    <span class="stat-label">Directories:</span>
                    <span class="stat-value">]] .. analysis.dir_count .. [[</span>
                </div>
            </div>
            
            <div class="sidebar-section">
                <h3>📁 File Types</h3>
                <div class="file-types">
    ]]
    
    for i, ft in ipairs(analysis.file_types) do
        if i <= 10 then -- Show top 10 file types
            sidebar = sidebar .. string.format([[
                    <div class="file-type-item">
                        <span class="file-ext">.%s</span>
                        <span class="file-count">%d</span>
                    </div>
            ]], ft.ext, ft.count)
        end
    end
    
    sidebar = sidebar .. [[
                </div>
            </div>
            
            <div class="sidebar-section">
                <h3>🛠️ Quick Tools</h3>
                <div class="tool-links">
                    <a href="#" onclick="expandAll()" class="tool-link">Expand All</a>
                    <a href="#" onclick="collapseAll()" class="tool-link">Collapse All</a>
                    <a href="#" onclick="showLargeFiles()" class="tool-link">Find Large Files</a>
                    <a href="#" onclick="showRecentFiles()" class="tool-link">Recent Files</a>
                </div>
            </div>
            
            <div class="sidebar-section">
                <h3>🔗 Quick Access</h3>
                <div class="quick-links">
                    <a href="file:///mnt/mtwo/programming" class="quick-link">Programming Root</a>
                    <a href="file:///mnt/mtwo/programming/ai-stuff" class="quick-link">AI Projects</a>
                    <a href="file:///mnt/mtwo/programming/rust" class="quick-link">Rust Projects</a>
                    <a href="file:///mnt/mtwo/programming/lua" class="quick-link">Lua Projects</a>
                    <a href="file:///mnt/mtwo/programming/python" class="quick-link">Python Projects</a>
                </div>
            </div>
            
            <div class="sidebar-section">
                <h3>📋 Project Files Found</h3>
                <div class="project-files">
    ]]
    
    for _, file in ipairs(analysis.project_files) do
        sidebar = sidebar .. string.format([[
                    <div class="project-file">%s</div>
        ]], file)
    end
    
    sidebar = sidebar .. [[
                </div>
            </div>
        </div>
    ]]
    
    return sidebar
end

-- {{{ generate_tree_html
local function generate_tree_html(items, level)
-- }}}
    level = level or 0
    local html = ""
    local indent = string.rep("  ", level)
    
    for _, item in ipairs(items) do
        if item.type == "directory" then
            local has_children = #item.children > 0
            html = html .. indent .. '<div class="tree-node">\n'
            html = html .. indent .. '  <div class="tree-item directory" onclick="toggleNode(this)">\n'
            html = html .. indent .. '    <span class="tree-icon">' .. (has_children and "📁" or "📂") .. '</span>\n'
            html = html .. indent .. '    <a href="file://' .. item.path .. '" class="tree-link">' .. item.name .. '</a>\n'
            html = html .. indent .. '    <span class="tree-meta">(' .. (item.size or "0") .. ')</span>\n'
            html = html .. indent .. '  </div>\n'
            
            if has_children then
                html = html .. indent .. '  <div class="tree-children" style="display: none;">\n'
                html = html .. generate_tree_html(item.children, level + 2)
                html = html .. indent .. '  </div>\n'
            end
            html = html .. indent .. '</div>\n'
        else
            html = html .. indent .. '<div class="tree-item file">\n'
            html = html .. indent .. '  <span class="tree-icon">📄</span>\n'
            html = html .. indent .. '  <a href="file://' .. item.path .. '" class="tree-link">' .. item.name .. '</a>\n'
            html = html .. indent .. '  <span class="tree-meta">(' .. (item.size or "0") .. ')</span>\n'
            html = html .. indent .. '</div>\n'
        end
    end
    
    return html
end

-- {{{ generate_html_page
local function generate_html_page(tree_data, root_path)
-- }}}
    local sidebar_html = generate_sidebar_html()
    
    local html = [[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enhanced Project File Server</title>
    <style>
        body {
            font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
            background-color: #1a1a1a;
            color: #e0e0e0;
            margin: 0;
            padding: 0;
            line-height: 1.6;
            display: flex;
            min-height: 100vh;
        }
        
        .sidebar {
            width: 300px;
            background-color: #2a2a2a;
            padding: 20px;
            border-right: 1px solid #444;
            overflow-y: auto;
            position: fixed;
            height: 100vh;
            left: 0;
            top: 0;
        }
        
        .main-content {
            margin-left: 300px;
            flex: 1;
            padding: 20px;
        }
        
        .sidebar-section {
            margin-bottom: 25px;
            background-color: #1a1a1a;
            padding: 15px;
            border-radius: 8px;
            border-left: 3px solid #00ff88;
        }
        
        .sidebar-section h3 {
            margin: 0 0 15px 0;
            color: #00ff88;
            font-size: 1.1em;
        }
        
        .stat-item {
            display: flex;
            justify-content: space-between;
            margin: 8px 0;
            padding: 5px;
            background-color: #2a2a2a;
            border-radius: 4px;
        }
        
        .stat-label {
            color: #b0b0b0;
        }
        
        .stat-value {
            color: #00ff88;
            font-weight: bold;
        }
        
        .file-type-item {
            display: flex;
            justify-content: space-between;
            margin: 5px 0;
            padding: 3px 8px;
            background-color: #2a2a2a;
            border-radius: 3px;
            font-size: 0.9em;
        }
        
        .file-ext {
            color: #ff9500;
        }
        
        .file-count {
            color: #00ff88;
        }
        
        .tool-links, .quick-links {
            display: flex;
            flex-direction: column;
            gap: 8px;
        }
        
        .tool-link, .quick-link {
            color: #00ff88;
            text-decoration: none;
            padding: 8px 12px;
            background-color: #1a1a1a;
            border-radius: 4px;
            text-align: center;
            transition: background-color 0.2s;
            border: 1px solid #333;
        }
        
        .tool-link:hover, .quick-link:hover {
            background-color: #3a3a3a;
            text-decoration: none;
        }
        
        .project-file {
            padding: 4px 8px;
            margin: 3px 0;
            background-color: #2a2a2a;
            border-radius: 3px;
            color: #ff9500;
            font-size: 0.9em;
        }
        
        .header {
            background-color: #2a2a2a;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            border-left: 4px solid #00ff88;
        }
        
        .header h1 {
            margin: 0 0 10px 0;
            color: #00ff88;
            font-size: 2em;
        }
        
        .header p {
            margin: 5px 0;
            color: #b0b0b0;
        }
        
        .search-box {
            background-color: #2a2a2a;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        
        .search-box input {
            width: 100%;
            padding: 12px;
            background-color: #1a1a1a;
            border: 1px solid #555;
            border-radius: 4px;
            color: #e0e0e0;
            font-family: inherit;
            font-size: 1em;
        }
        
        .tree-container {
            background-color: #2a2a2a;
            padding: 20px;
            border-radius: 8px;
            overflow-x: auto;
        }
        
        .tree-node {
            margin-left: 0;
        }
        
        .tree-item {
            padding: 8px 12px;
            margin: 3px 0;
            border-radius: 4px;
            display: flex;
            align-items: center;
            transition: background-color 0.2s;
        }
        
        .tree-item:hover {
            background-color: #3a3a3a;
        }
        
        .tree-item.directory {
            cursor: pointer;
            font-weight: bold;
            background-color: #1a1a1a;
        }
        
        .tree-item.file {
            margin-left: 20px;
            background-color: #1f1f1f;
        }
        
        .tree-icon {
            margin-right: 10px;
            font-size: 1.2em;
        }
        
        .tree-link {
            color: #00ff88;
            text-decoration: none;
            flex-grow: 1;
        }
        
        .tree-link:hover {
            text-decoration: underline;
        }
        
        .tree-meta {
            color: #888;
            font-size: 0.85em;
            margin-left: 10px;
        }
        
        .tree-children {
            margin-left: 25px;
            border-left: 2px dotted #555;
            padding-left: 15px;
        }
        
        .footer {
            margin-top: 40px;
            text-align: center;
            color: #666;
            font-size: 0.9em;
            border-top: 1px solid #333;
            padding-top: 20px;
        }
        
        @media (max-width: 768px) {
            .sidebar {
                width: 100%;
                position: relative;
                height: auto;
            }
            
            .main-content {
                margin-left: 0;
            }
        }
    </style>
</head>
<body>
    ]] .. sidebar_html .. [[
    
    <div class="main-content">
        <div class="header">
            <h1>🗂️ Enhanced Project File Server</h1>
            <p>Local directory browser with analysis tools</p>
            <p><strong>Root Path:</strong> ]] .. root_path .. [[</p>
            <p><strong>Generated:</strong> ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[</p>
        </div>
        
        <div class="search-box">
            <input type="text" id="searchInput" placeholder="Search projects and files..." onkeyup="filterTree()">
        </div>
        
        <div class="tree-container">
            <div id="fileTree">
]] .. generate_tree_html(tree_data) .. [[
            </div>
        </div>
        
        <div class="footer">
            <p>Enhanced Project File Server - neocities-modernization</p>
            <p>Use Ctrl+F to search • Click folders to expand/collapse • Use sidebar tools for analysis</p>
        </div>
    </div>
    
    <script>
        function toggleNode(element) {
            const children = element.nextElementSibling;
            if (children && children.classList.contains('tree-children')) {
                const isVisible = children.style.display !== 'none';
                children.style.display = isVisible ? 'none' : 'block';
                
                const icon = element.querySelector('.tree-icon');
                if (icon) {
                    icon.textContent = isVisible ? '📁' : '📂';
                }
            }
        }
        
        function expandAll() {
            const allChildren = document.querySelectorAll('.tree-children');
            allChildren.forEach(child => {
                child.style.display = 'block';
            });
            
            const allIcons = document.querySelectorAll('.tree-item.directory .tree-icon');
            allIcons.forEach(icon => {
                icon.textContent = '📂';
            });
        }
        
        function collapseAll() {
            const allChildren = document.querySelectorAll('.tree-children');
            allChildren.forEach(child => {
                child.style.display = 'none';
            });
            
            const allIcons = document.querySelectorAll('.tree-item.directory .tree-icon');
            allIcons.forEach(icon => {
                icon.textContent = '📁';
            });
        }
        
        function showLargeFiles() {
            alert('Large files feature would scan for files > 100MB');
        }
        
        function showRecentFiles() {
            alert('Recent files feature would show files modified in last 7 days');
        }
        
        function filterTree() {
            const searchTerm = document.getElementById('searchInput').value.toLowerCase();
            const treeItems = document.querySelectorAll('.tree-item');
            
            treeItems.forEach(item => {
                const text = item.textContent.toLowerCase();
                const matches = searchTerm === '' || text.includes(searchTerm);
                item.style.display = matches ? 'flex' : 'none';
                
                if (matches && searchTerm !== '') {
                    let parent = item.parentElement;
                    while (parent && parent.classList.contains('tree-children')) {
                        parent.style.display = 'block';
                        parent = parent.parentElement.parentElement;
                    }
                }
            });
        }
        
        document.addEventListener('DOMContentLoaded', function() {
            const firstLevelDirs = document.querySelectorAll('.tree-node > .tree-item.directory');
            firstLevelDirs.forEach(dir => {
                const children = dir.nextElementSibling;
                if (children) {
                    children.style.display = 'block';
                    const icon = dir.querySelector('.tree-icon');
                    if (icon) icon.textContent = '📂';
                }
            });
        });
    </script>
</body>
</html>
]]
    
    return html
end

-- {{{ main
local function main()
-- }}}
    local programming_root = "/mnt/mtwo/programming"
    
    print("Scanning programming directories...")
    local tree_data = scan_directory_bash(programming_root, 2)
    
    if not tree_data then
        print("Error: Could not scan directory " .. programming_root)
        os.exit(1)
    end
    
    print("Generating enhanced HTML file server...")
    local html_content = generate_html_page(tree_data, programming_root)
    
    local output_path = DIR .. "/assets/assets-2/enhanced-project-file-server.html"
    local file = io.open(output_path, "w")
    if not file then
        print("Error: Could not create output file " .. output_path)
        os.exit(1)
    end
    
    file:write(html_content)
    file:close()
    
    print("Enhanced file server generated successfully!")
    print("Open this file in your browser: " .. output_path)
    print("Features:")
    print("  - Sidebar with project statistics and file type analysis")
    print("  - Quick navigation tools (expand all, collapse all)")
    print("  - Project files detection (README, package.json, etc.)")
    print("  - Quick access links to common directories")
    print("  - Search functionality")
    print("  - Responsive design")
end

main()