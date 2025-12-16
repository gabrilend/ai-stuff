#!/usr/bin/env lua
-- Poem Context Generator: Randomly selects and orders poems from compiled.txt to fit within a specified context window for LLM personalization

local DIR = "/mnt/mtwo/programming/ai-stuff/words-pdf/input"
local COMPILED_FILE = DIR .. "/compiled.txt"

-- {{{ function print_usage
function print_usage()
    print("Usage: " .. arg[0] .. " [DIR] [OPTIONS]")
    print("  DIR: Directory containing compiled.txt (default: " .. DIR .. ")")
    print("  -s, --size SIZE: Context window size in characters (required)")
    print("  -I, --interactive: Interactive mode")
    print("  -h, --help: Show this help")
end
-- }}}

-- {{{ function parse_args
function parse_args(args)
    local config = {
        interactive = false,
        context_size = nil,
        dir = DIR
    }
    
    local i = 1
    -- Check if first argument is a directory (not a flag)
    if args[1] and not args[1]:match("^-") then
        config.dir = args[1] .. "/input"
        i = 2
    else
        -- Use default directory if no directory provided
        config.dir = DIR
    end
    
    while i <= #args do
        local arg = args[i]
        if arg == "-I" or arg == "--interactive" then
            config.interactive = true
        elseif arg == "-s" or arg == "--size" then
            i = i + 1
            config.context_size = tonumber(args[i])
            if not config.context_size then
                error("Invalid context size: " .. tostring(args[i]))
            end
        elseif arg == "-h" or arg == "--help" then
            print_usage()
            os.exit(0)
        else
            error("Unknown argument: " .. arg)
        end
        i = i + 1
    end
    
    return config
end
-- }}}

-- {{{ function interactive_mode
function interactive_mode()
    print("Poem Context Generator - Interactive Mode")
    print("1. Small context (8000 chars)")
    print("2. Medium context (16000 chars)")
    print("3. Large context (32000 chars)")
    print("4. Custom size")
    print("Enter selection (1-4): ")
    
    local choice = io.read()
    local size
    
    if choice == "1" then
        size = 8000
    elseif choice == "2" then
        size = 16000
    elseif choice == "3" then
        size = 32000
    elseif choice == "4" then
        print("Enter custom size: ")
        size = tonumber(io.read())
        if not size then
            error("Invalid size entered")
        end
    else
        error("Invalid selection")
    end
    
    return { context_size = size, dir = DIR }
end
-- }}}

-- {{{ function extract_poems
function extract_poems(filepath)
    local file = io.open(filepath, "r")
    if not file then
        error("Cannot open file: " .. filepath)
    end
    
    local poems = {}
    local current_poem = {}
    local in_poem = false
    local poem_title = ""
    
    for line in file:lines() do
        if line:match("^%s*%-> file: messages/") then
            -- Save previous poem if exists
            if in_poem and #current_poem > 0 then
                local content = table.concat(current_poem, "\n")
                if #content:gsub("%s", "") > 0 then  -- Only add non-empty poems
                    table.insert(poems, {
                        title = poem_title,
                        content = content,
                        length = #content
                    })
                end
            end
            
            -- Start new poem
            poem_title = line:match("messages/(.+)%.txt") or "unknown"
            current_poem = {}
            in_poem = false  -- Wait for separator before starting content
        elseif line:match("^%-+$") and poem_title ~= "" then
            -- Separator line after header - now we can start collecting content
            in_poem = true
        elseif in_poem then
            -- Skip empty lines at the beginning of poems
            if #current_poem > 0 or not line:match("^%s*$") then
                table.insert(current_poem, line)
            end
        end
    end
    
    -- Add last poem
    if in_poem and #current_poem > 0 then
        local content = table.concat(current_poem, "\n")
        if #content:gsub("%s", "") > 0 then  -- Only add non-empty poems
            table.insert(poems, {
                title = poem_title,
                content = content,
                length = #content
            })
        end
    end
    
    file:close()
    return poems
end
-- }}}

-- {{{ function shuffle_array
function shuffle_array(array)
    math.randomseed(os.time())
    for i = #array, 2, -1 do
        local j = math.random(i)
        array[i], array[j] = array[j], array[i]
    end
    return array
end
-- }}}

-- {{{ function select_poems_for_context
function select_poems_for_context(poems, target_size)
    -- Filter out very short poems (likely just filenames or single words)
    local substantial_poems = {}
    for _, poem in ipairs(poems) do
        -- Only include poems with meaningful content (more than 20 chars of non-whitespace)
        if #poem.content:gsub("%s", "") > 20 then
            table.insert(substantial_poems, poem)
        end
    end
    
    -- If we don't have enough substantial poems, include shorter ones too
    if #substantial_poems < 10 then
        substantial_poems = poems
    end
    
    local shuffled = shuffle_array({table.unpack(substantial_poems)})
    local selected = {}
    local total_length = 0
    
    -- Sort by length for better packing, but prefer medium-length entries
    table.sort(shuffled, function(a, b) 
        -- Prefer poems between 100-2000 chars, then shorter, then longer
        local a_score = math.abs(500 - a.length)
        local b_score = math.abs(500 - b.length)
        return a_score < b_score
    end)
    
    for _, poem in ipairs(shuffled) do
        if total_length + poem.length + 100 <= target_size then  -- 100 chars buffer for separators and headers
            table.insert(selected, poem)
            total_length = total_length + poem.length + 100
        end
    end
    
    return selected, total_length
end
-- }}}

-- {{{ function format_output
function format_output(selected_poems)
    local output = {}
    table.insert(output, "# Personal Context for LLM")
    table.insert(output, "")
    
    for _, poem in ipairs(selected_poems) do
        table.insert(output, "## " .. poem.title)
        table.insert(output, poem.content)
        table.insert(output, "")  -- Empty line separator
    end
    
    return table.concat(output, "\n")
end
-- }}}

-- {{{ function generate_context
function generate_context(context_size, dir_path)
    dir_path = dir_path or DIR
    local compiled_path = dir_path .. "/compiled.txt"
    
    local poems = extract_poems(compiled_path)
    if #poems == 0 then
        return nil, "No poems found in " .. compiled_path
    end
    
    local selected, total_length = select_poems_for_context(poems, context_size)
    if #selected == 0 then
        return nil, "No poems fit within the specified context size"
    end
    
    local output = format_output(selected)
    return output, total_length, #selected
end
-- }}}

-- {{{ function main
function main()
    local config
    
    if #arg == 0 or (arg[1] and arg[1] == "-I") then
        config = interactive_mode()
    else
        config = parse_args(arg)
    end
    
    if not config.context_size then
        error("Context size must be specified with -s or use interactive mode with -I")
    end
    
    local output, total_length, selected_count = generate_context(config.context_size, config.dir)
    
    if not output then
        error(total_length)  -- total_length contains the error message in this case
    end
    
    print(output)
    
    -- Output statistics to stderr
    io.stderr:write(string.format("Selected %d poems, total length: %d chars\n", selected_count, total_length))
end
-- }}}

main()