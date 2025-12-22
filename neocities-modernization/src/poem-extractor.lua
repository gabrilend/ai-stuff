#!/usr/bin/env lua

-- {{{ local function setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Script configuration
local DIR = setup_dir_path(arg and arg[1])

-- Load required libraries
package.path = DIR .. "/libs/?.lua;" .. package.path
local dkjson = require("dkjson")
local utils = require("utils")

-- Initialize asset path configuration for standalone execution
utils.init_assets_root(arg)

-- {{{ local function relative_path
local function relative_path(absolute_path)
    if absolute_path:sub(1, #DIR) == DIR then
        local rel = absolute_path:sub(#DIR + 1)
        if rel:sub(1, 1) == "/" then rel = rel:sub(2) end
        return "./" .. rel
    end
    return absolute_path
end
-- }}}

local M = {}

-- {{{ function load_json_file
local function load_json_file(filepath)
    local file = io.open(filepath, "r")
    if not file then
        return nil
    end
    
    local content = file:read("*a")
    file:close()
    
    local data, pos, err = dkjson.decode(content, 1, nil)
    if err then
        print("Warning: Failed to parse JSON file " .. filepath .. ": " .. err)
        return nil
    end
    
    return data
end
-- }}}

-- {{{ local function extract_poem_info
local function extract_poem_info(header_line)
    -- Extract info from lines like: " -> file: messages/0767.txt", " -> file: fediverse/1234.txt", etc.
    local path = header_line:match("%->%s*file:%s*(.+)")
    if not path then
        return nil, nil, nil
    end
    
    -- Try to extract numeric ID from filename
    local id = path:match("(%d+)%.txt$")
    id = id and tonumber(id) or nil
    
    -- Determine category
    local category = path:match("^([^/]+)/")
    
    return path, id, category
end
-- }}}

-- {{{ local function parse_compiled_file  
local function parse_compiled_file(filepath)
    local file = io.open(filepath, "r")
    if not file then
        error("Could not open file: " .. filepath)
    end
    
    local poems = {}
    local current_poem = nil
    local content_lines = {}
    local in_poem_content = false
    
    for line in file:lines() do
        -- Check for poem header
        if line:match("^%s*%->%s*file:") then
            -- Save previous poem if exists
            if current_poem then
                current_poem.content = table.concat(content_lines, "\n"):gsub("^%s*", ""):gsub("%s*$", "")
                current_poem.length = #current_poem.content
                table.insert(poems, current_poem)
            end
            
            -- Start new poem
            local filepath, id, category = extract_poem_info(line)
            if filepath then
                current_poem = {
                    id = id,
                    filepath = filepath,
                    category = category,
                    content = "",
                    length = 0
                }
                content_lines = {}
                in_poem_content = false
            end
        elseif line:match("^%-%-%-%-%-%-%-%-%-") then
            -- Separator line - next content belongs to current poem
            in_poem_content = true
        elseif current_poem and in_poem_content then
            -- Collect poem content
            table.insert(content_lines, line)
        end
    end
    
    -- Don't forget the last poem
    if current_poem then
        current_poem.content = table.concat(content_lines, "\n"):gsub("^%s*", ""):gsub("%s*$", "")
        current_poem.length = #current_poem.content
        table.insert(poems, current_poem)
    end
    
    file:close()
    return poems
end
-- }}}

-- {{{ function M.load_extracted_json
function M.load_extracted_json(input_directory)
    local poems = {}
    
    -- Load fediverse poems
    local fediverse_file = input_directory .. "/fediverse/files/poems.json"
    local fediverse_data = load_json_file(fediverse_file)
    local attachment_count = 0
    if fediverse_data and fediverse_data.poems then
        print("Loading " .. #fediverse_data.poems .. " fediverse poems from JSON")
        for _, poem in ipairs(fediverse_data.poems) do
            local poem_entry = {
                id = tonumber(poem.id),
                filepath = poem.category .. "/" .. poem.id .. ".txt", -- Reconstruct legacy path format
                category = poem.category,
                content = poem.content,
                raw_content = poem.raw_content,
                creation_date = poem.creation_date,
                content_warning = poem.content_warning,
                length = poem.metadata and poem.metadata.character_count or #(poem.content or ""),
                metadata = poem.metadata
            }
            -- Preserve media attachments if present (from ActivityPub extraction)
            -- Attachments contain image/video metadata that can be used for HTML generation
            if poem.attachments then
                poem_entry.attachments = poem.attachments
                attachment_count = attachment_count + #poem.attachments
            end
            table.insert(poems, poem_entry)
        end
        if attachment_count > 0 then
            print("  Found " .. attachment_count .. " media attachments in fediverse poems")
        end
    else
        print("No fediverse poems found at: " .. fediverse_file)
    end
    
    -- Load messages poems  
    local messages_file = input_directory .. "/messages/files/poems.json"
    local messages_data = load_json_file(messages_file)
    if messages_data and messages_data.poems then
        print("Loading " .. #messages_data.poems .. " messages poems from JSON")
        for _, poem in ipairs(messages_data.poems) do
            table.insert(poems, {
                id = tonumber(poem.id),
                filepath = poem.category .. "/" .. poem.id .. ".txt", -- Reconstruct legacy path format
                category = poem.category,
                content = poem.content,
                creation_date = poem.creation_date,
                length = poem.metadata and poem.metadata.character_count or #(poem.content or ""),
                metadata = poem.metadata
            })
        end
    else
        print("No messages poems found at: " .. messages_file)
    end
    
    -- Load notes poems  
    local notes_file = input_directory .. "/notes/files/poems.json"
    local notes_data = load_json_file(notes_file)
    if notes_data and notes_data.poems then
        print("Loading " .. #notes_data.poems .. " notes poems from JSON")
        for _, poem in ipairs(notes_data.poems) do
            table.insert(poems, {
                id = tonumber(poem.id),
                filepath = poem.category .. "/" .. poem.id .. ".txt", -- Reconstruct legacy path format
                category = poem.category,
                content = poem.content,
                creation_date = poem.creation_date,
                content_warning = poem.content_warning,
                length = poem.metadata and poem.metadata.character_count or #(poem.content or ""),
                metadata = poem.metadata
            })
        end
    else
        print("No notes poems found at: " .. notes_file)
    end
    
    return poems
end
-- }}}

-- {{{ function M.detect_input_mode
function M.detect_input_mode(base_directory)
    local input_dir = base_directory .. "/input"
    local compiled_file = base_directory .. "/compiled.txt"
    
    -- Check for modern JSON extraction
    local fediverse_json = input_dir .. "/fediverse/files/poems.json"
    local messages_json = input_dir .. "/messages/files/poems.json"
    local notes_json = input_dir .. "/notes/files/poems.json"
    
    -- Check if any JSON file exists
    local fediverse_file = io.open(fediverse_json, "r")
    local messages_file = io.open(messages_json, "r")
    local notes_file = io.open(notes_json, "r")
    
    if fediverse_file or messages_file or notes_file then
        if fediverse_file then io.close(fediverse_file) end
        if messages_file then io.close(messages_file) end
        if notes_file then io.close(notes_file) end
        return "json", input_dir
    end
    
    local compiled_handle = io.open(compiled_file, "r")
    if compiled_handle then
        io.close(compiled_handle)
        return "compiled", compiled_file
    else
        return "none", nil
    end
end
-- }}}

-- {{{ function M.extract_poems_auto
function M.extract_poems_auto(base_directory, output_file)
    local mode, source_path = M.detect_input_mode(base_directory)
    
    local poems
    if mode == "json" then
        print("Using modern JSON extraction from: " .. relative_path(source_path))
        poems = M.load_extracted_json(source_path)
    elseif mode == "compiled" then
        print("Using legacy compiled.txt extraction from: " .. relative_path(source_path))
        poems = parse_compiled_file(source_path)
    else
        error("No valid input found: neither JSON extracts nor compiled.txt available in " .. base_directory)
    end
    
    print("Found " .. #poems .. " poems")
    
    -- Sort poems by category, then by ID for consistent ordering
    table.sort(poems, function(a, b) 
        if a.category ~= b.category then
            return (a.category or "") < (b.category or "")
        end
        return (a.id or 0) < (b.id or 0) 
    end)
    
    -- Create output structure
    local output_data = {
        metadata = {
            source_mode = mode,
            source_path = source_path,
            extracted_at = os.date("%Y-%m-%d %H:%M:%S"),
            total_poems = #poems,
            extraction_version = "2.0"
        },
        poems = poems
    }
    
    if output_file then
        -- Save to JSON file
        local json_output = dkjson.encode(output_data, { indent = true })
        
        local output = io.open(output_file, "w")
        if not output then
            error("Could not create output file: " .. output_file)
        end
        
        output:write(json_output)
        output:close()
        
        print("Poems extracted and saved to: " .. relative_path(output_file))
    end

    return output_data
end
-- }}}

-- {{{ function M.extract_poems
function M.extract_poems(input_file, output_file)
    print("Extracting poems from: " .. relative_path(input_file))
    
    local poems = parse_compiled_file(input_file)
    
    print("Found " .. #poems .. " poems")
    
    -- Sort poems by category, then by ID for consistent ordering
    table.sort(poems, function(a, b) 
        if a.category ~= b.category then
            return (a.category or "") < (b.category or "")
        end
        return (a.id or 0) < (b.id or 0) 
    end)
    
    -- Create output structure
    local output_data = {
        metadata = {
            source_file = input_file,
            extracted_at = os.date("%Y-%m-%d %H:%M:%S"),
            total_poems = #poems,
            extraction_version = "1.0"
        },
        poems = poems
    }
    
    -- Save to JSON file
    local json_output = dkjson.encode(output_data, { indent = true })
    
    local output = io.open(output_file, "w")
    if not output then
        error("Could not create output file: " .. output_file)
    end
    
    output:write(json_output)
    output:close()
    
    print("Poems extracted and saved to: " .. relative_path(output_file))
    return output_data
end
-- }}}

-- {{{ function M.main
function M.main(interactive_mode)
    if interactive_mode then
        print("=== Poem Extraction Tool ===")
        print("1. Auto-detect input source (JSON or compiled.txt)")
        print("2. Force extract from compiled.txt")
        print("3. Force extract from custom file")
        io.write("Select option (1-3): ")
        local choice = io.read()
        
        local output_file = utils.asset_path("poems.json")

        if choice == "1" then
            M.extract_poems_auto(DIR, output_file)
        elseif choice == "2" then
            local input_file = DIR .. "/compiled.txt"
            M.extract_poems(input_file, output_file)
        elseif choice == "3" then
            io.write("Enter input file path: ")
            local input_file = io.read()
            io.write("Enter output file path: ")
            output_file = io.read()
            M.extract_poems(input_file, output_file)
        else
            print("Invalid choice")
            return
        end
    else
        -- Default non-interactive mode - use auto-detection
        local output_file = utils.asset_path("poems.json")
        M.extract_poems_auto(DIR, output_file)
    end
end
-- }}}

-- Command line execution (only when run directly, not when required)
if arg and #arg > 0 and debug.getinfo(3) == nil then
    local interactive_mode = false
    for i, arg_val in ipairs(arg) do
        if arg_val == "-I" then
            interactive_mode = true
            break
        end
    end
    
    M.main(interactive_mode)
end

-- {{{ function remove_reply_syntax
local function remove_reply_syntax(content)
    -- Remove reply syntax from content for embedding generation
    -- This removes @username and @username@server.domain patterns to improve embedding quality
    
    -- Remove @username@server.domain patterns (federated mentions) first
    content = content:gsub("@[%w%.%-_]+@[%w%.%-]+%.%w+", "")
    
    -- Remove @username patterns (local mentions) - handle multiple consecutive mentions
    -- Use a loop to handle multiple consecutive mentions like "@user1 @user2 @user3"
    local prev_content
    repeat
        prev_content = content
        -- Pattern 1: @username at start of line or after whitespace
        content = content:gsub("^@[%w%.%-_]+%s*", "")
        content = content:gsub("(%s)@[%w%.%-_]+%s*", "%1")
        content = content:gsub("(%s)@[%w%.%-_]+$", "%1")
        content = content:gsub("(%s)@[%w%.%-_]+([%p])", "%1%2")
    until content == prev_content
    
    -- Final cleanup: remove any remaining isolated @ mentions
    content = content:gsub("@[%w%.%-_]+", "")
    
    -- Clean up extra whitespace left behind
    content = content:gsub("%s+", " "):gsub("^%s*", ""):gsub("%s*$", "")
    
    return content
end
-- }}}

-- {{{ function M.extract_pure_poem_content
function M.extract_pure_poem_content(processed_content)
    local content = processed_content or ""
    
    -- Remove date stamp (YYYY-MM-DD\n)
    content = content:gsub("^%d%d%d%d%-%d%d%-%d%d\n", "")
    
    -- Extract content warning text (without "CW: " prefix)
    local cw_text = ""
    local cw_pattern = "CW:%s*([^\n]*)\n"
    local cw_match = content:match(cw_pattern)
    if cw_match then
        cw_text = cw_match:gsub("^%s*", ""):gsub("%s*$", "") -- trim whitespace
        content = content:gsub(cw_pattern, "") -- remove entire CW line
    end
    
    -- NEW: Remove reply syntax from both content warning and main content
    if cw_text ~= "" then
        cw_text = remove_reply_syntax(cw_text)
    end
    content = remove_reply_syntax(content)
    
    -- Remove extra formatting newlines (multiple consecutive newlines)
    content = content:gsub("\n\n+", "\n"):gsub("^\n", ""):gsub("\n$", "")
    
    -- Remove any title/ID/separator artifacts if present
    -- (These shouldn't be in poem.content but safety check)
    content = content:gsub("^%s*%->%s*file:.-\n", "") -- file headers
    content = content:gsub("^%-%-%-%-+\n", "") -- separator lines
    content = content:gsub("\n%-%-%-%-+$", "") -- trailing separators
    
    -- Combine pure content: cleaned content warning + cleaned poem content
    local pure_content = ""
    if cw_text ~= "" and content ~= "" then
        pure_content = cw_text .. "\n" .. content
    elseif cw_text ~= "" then
        pure_content = cw_text
    else
        pure_content = content
    end
    
    return pure_content
end
-- }}}

return M