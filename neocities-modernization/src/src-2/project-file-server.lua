#!/usr/bin/env lua

-- {{{ Project File Server Generator
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
if arg and arg[1] then
    DIR = arg[1]
end

-- Load required libraries
local lfs = require('lfs')
local json = require('libs.dkjson')

-- {{{ scan_directory
local function scan_directory(path, max_depth, current_depth)
-- }}}
    current_depth = current_depth or 0
    max_depth = max_depth or 3
    
    if current_depth >= max_depth then
        return nil
    end
    
    local items = {}
    local attr = lfs.attributes(path)
    
    if not attr or attr.mode ~= "directory" then
        return nil
    end
    
    for entry in lfs.dir(path) do
        if entry ~= "." and entry ~= ".." and not entry:match("^%.") then
            local full_path = path .. "/" .. entry
            local entry_attr = lfs.attributes(full_path)
            
            if entry_attr and entry_attr.mode == "directory" then
                local sub_items = scan_directory(full_path, max_depth, current_depth + 1)
                table.insert(items, {
                    name = entry,
                    path = full_path,
                    type = "directory",
                    modified = entry_attr.modification,
                    children = sub_items or {}
                })
            else
                table.insert(items, {
                    name = entry,
                    path = full_path,
                    type = "file",
                    size = entry_attr and entry_attr.size or 0,
                    modified = entry_attr and entry_attr.modification or 0
                })
            end
        end
    end
    
    -- Sort items: directories first, then by name
    table.sort(items, function(a, b)
        if a.type ~= b.type then
            return a.type == "directory"
        end
        return a.name < b.name
    end)
    
    return items
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
            html = html .. indent .. '    <span class="tree-meta">(' .. #item.children .. ' items)</span>\n'
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
            html = html .. indent .. '  <span class="tree-meta">(' .. math.floor(item.size / 1024) .. ' KB)</span>\n'
            html = html .. indent .. '</div>\n'
        end
    end
    
    return html
end

-- {{{ generate_html_page
local function generate_html_page(tree_data, root_path)
-- }}}
    local html = [[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Project File Server</title>
    <style>
        body {
            font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
            background-color: #1a1a1a;
            color: #e0e0e0;
            margin: 0;
            padding: 20px;
            line-height: 1.6;
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
            margin: 0;
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
            padding: 10px;
            background-color: #1a1a1a;
            border: 1px solid #555;
            border-radius: 4px;
            color: #e0e0e0;
            font-family: inherit;
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
            padding: 5px 10px;
            margin: 2px 0;
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
        }
        
        .tree-item.file {
            margin-left: 20px;
        }
        
        .tree-icon {
            margin-right: 8px;
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
            font-size: 0.9em;
            margin-left: 10px;
        }
        
        .tree-children {
            margin-left: 20px;
            border-left: 1px dotted #555;
            padding-left: 10px;
        }
        
        .footer {
            margin-top: 40px;
            text-align: center;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🗂️ Project File Server</h1>
        <p>Local directory browser for programming projects</p>
        <p><strong>Root Path:</strong> ]] .. root_path .. [[</p>
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
        <p>Generated by neocities-modernization project file server</p>
        <p>Use Ctrl+F to search within the page</p>
    </div>
    
    <script>
        function toggleNode(element) {
            const children = element.nextElementSibling;
            if (children && children.classList.contains('tree-children')) {
                const isVisible = children.style.display !== 'none';
                children.style.display = isVisible ? 'none' : 'block';
                
                // Update folder icon
                const icon = element.querySelector('.tree-icon');
                if (icon) {
                    icon.textContent = isVisible ? '📁' : '📂';
                }
            }
        }
        
        function filterTree() {
            const searchTerm = document.getElementById('searchInput').value.toLowerCase();
            const treeItems = document.querySelectorAll('.tree-item');
            
            treeItems.forEach(item => {
                const text = item.textContent.toLowerCase();
                const matches = text.includes(searchTerm);
                item.style.display = matches ? 'flex' : 'none';
                
                // Show parent directories if child matches
                if (matches) {
                    let parent = item.parentElement;
                    while (parent && parent.classList.contains('tree-children')) {
                        parent.style.display = 'block';
                        parent = parent.parentElement.parentElement;
                    }
                }
            });
        }
        
        // Expand first level on load
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
    local tree_data = scan_directory(programming_root, 3)
    
    if not tree_data then
        print("Error: Could not scan directory " .. programming_root)
        os.exit(1)
    end
    
    print("Generating HTML file server...")
    local html_content = generate_html_page(tree_data, programming_root)
    
    local output_path = DIR .. "/assets/assets-2/project-file-server.html"
    local file = io.open(output_path, "w")
    if not file then
        print("Error: Could not create output file " .. output_path)
        os.exit(1)
    end
    
    file:write(html_content)
    file:close()
    
    print("File server generated successfully!")
    print("Open this file in your browser: " .. output_path)
    print("Or run: python3 -m http.server 8080")
end

-- Run main function
main()