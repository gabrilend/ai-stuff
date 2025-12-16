#!/usr/bin/env lua
-- Poem Context Generator (Simple): Uses view-random script to collect random poems for LLM personalization

local DIR = "/mnt/mtwo/programming/ai-stuff/words-pdf/input"
local VIEW_RANDOM_SCRIPT = "/home/ritz/words/view-random"

-- {{{ function print_usage
function print_usage()
    print("Usage: " .. arg[0] .. " [OPTIONS]")
    print("  -s, --size SIZE: Target context window size in characters (required)")
    print("  -I, --interactive: Interactive mode")
    print("  -h, --help: Show this help")
end
-- }}}

-- {{{ function parse_args
function parse_args(args)
    local config = {
        interactive = false,
        context_size = nil
    }
    
    local i = 1
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
    
    return { context_size = size }
end
-- }}}

-- {{{ function get_random_poem
-- FIXME: please build in functionality to also instead take in a neocities-modernization context file
function get_random_poem()
    local handle = io.popen(VIEW_RANDOM_SCRIPT .. " 2>/dev/null")
    if not handle then
        return nil, "Cannot run view-random script"
    end
    
    local content = handle:read("*a")
    handle:close()
    
    if not content or #content == 0 then
        return nil, "No content returned from view-random"
    end
    
    return content
end
-- }}}

-- {{{ function collect_poems
function collect_poems(target_size)
    local poems = {}
    local total_length = 0
    local attempts = 0
    local max_attempts = 100
    
    while total_length < target_size and attempts < max_attempts do
        attempts = attempts + 1
        
        local poem_content, err = get_random_poem()
        if poem_content then
            local poem_length = #poem_content
            
            -- Only add if it fits and adds meaningful content
            if total_length + poem_length + 200 <= target_size and poem_length > 50 then
                table.insert(poems, {
                    content = poem_content,
                    length = poem_length,
                    index = #poems + 1
                })
                total_length = total_length + poem_length + 200  -- Buffer for separators
            end
        end
        
        -- Small delay to avoid overwhelming the system
        os.execute("sleep 0.1")
    end
    
    return poems, total_length
end
-- }}}

-- {{{ function format_output
function format_output(poems)
    local output = {}
    table.insert(output, "# Personal Context for LLM")
    table.insert(output, "")
    
    for i, poem in ipairs(poems) do
        table.insert(output, "## Random Entry " .. i)
        table.insert(output, poem.content)
        table.insert(output, "")
    end
    
    return table.concat(output, "\n")
end
-- }}}

-- {{{ function generate_context
function generate_context(context_size)
    local poems, total_length = collect_poems(context_size)
    
    if #poems == 0 then
        return nil, "No poems collected"
    end
    
    local output = format_output(poems)
    return output, total_length, #poems
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
    
    local output, total_length, poem_count = generate_context(config.context_size)
    
    if not output then
        error(total_length)  -- total_length contains the error message in this case
    end
    
    print(output)
    
    -- Output statistics to stderr
    io.stderr:write(string.format("Collected %d poems, total length: %d chars\n", poem_count, total_length))
end
-- }}}

main()