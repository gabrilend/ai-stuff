#!/usr/bin/env lua

local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/continual-co-operation"

package.path = DIR .. "/src/?.lua;" .. package.path

local rolling_memory = require("rolling-memory")

-- {{{ local function print_banner
local function print_banner()
    print("🤖 Continual Co-operation Rolling Memory Chat")
    print("============================================")
    print("Commands:")
    print("  help     - Show this help")
    print("  stats    - Show memory statistics")
    print("  save     - Save current session")
    print("  quit     - Exit chat")
    print("  /remember <text> - Force remember important text")
    print("")
end
-- }}}

-- {{{ local function print_stats
local function print_stats(session)
    local stats = session:get_memory_stats()
    print("\n📊 Memory Statistics:")
    print(string.format("  Context entries: %d", stats.context_entries))
    print(string.format("  Context size: %d chars", stats.context_size))
    print(string.format("  Important memories: %d", stats.important_memories))
    print(string.format("  Session ID: %s", stats.session_id))
    print("")
end
-- }}}

-- {{{ local function interactive_mode
local function interactive_mode()
    print_banner()
    
    local session = rolling_memory.create_session()
    print("✅ Session initialized. Type 'help' for commands.\n")
    
    while true do
        io.write("You: ")
        io.flush()
        local input = io.read("*line")
        
        if not input then break end
        
        input = input:gsub("^%s+", ""):gsub("%s+$", "")
        
        if input == "quit" or input == "exit" then
            session:save()
            print("👋 Session saved. Goodbye!")
            break
        elseif input == "help" then
            print_banner()
        elseif input == "stats" then
            print_stats(session)
        elseif input == "save" then
            if session:save() then
                print("💾 Session saved successfully!")
            else
                print("❌ Failed to save session")
            end
        elseif input:match("^/remember%s+(.+)") then
            local text = input:match("^/remember%s+(.+)")
            -- Force add to important memories
            table.insert(session.memory_state.important_memories, {
                text = text,
                timestamp = os.time(),
                importance = 100,
                remember_count = 2
            })
            print("✅ Forced to remember: " .. text)
        elseif input ~= "" then
            print("🤖 Thinking...")
            local response = session:ask(input)
            print("Assistant: " .. response)
            print("")
        end
    end
end
-- }}}

-- {{{ main execution
if arg and arg[1] == "-I" then
    print("🎛️  Interactive mode configuration:")
    print("1. Standard chat mode")
    print("2. Debug mode (show context)")
    print("3. Memory exploration mode")
    io.write("Select mode (1-3): ")
    local mode = io.read("*line")
    if mode == "2" or mode == "3" then
        print("Debug/exploration modes not yet implemented")
    end
end

interactive_mode()
-- }}}