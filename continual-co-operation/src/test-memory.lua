#!/usr/bin/env lua

local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/continual-co-operation"

package.path = DIR .. "/src/?.lua;" .. package.path

local rolling_memory = require("rolling-memory")

-- {{{ local function test_rolling_memory
local function test_rolling_memory()
    print("🧪 Testing Rolling Memory System")
    print("================================")
    
    local session = rolling_memory.create_session(DIR .. "/test-memory-state.json")
    
    local test_interactions = {
        "Hello, I'm testing the rolling memory system",
        "Can you remember that I like pizza?",
        "I like pizza", -- Say it again to trigger "think twice" 
        "What's 2+2?",
        "Tell me about the weather",
        "Remember that my favorite color is blue",
        "My favorite color is blue", -- Say it again
        "What did I tell you about pizza?",
        "What's my favorite color?"
    }
    
    for i, prompt in ipairs(test_interactions) do
        print(string.format("\n--- Test %d ---", i))
        print("Input: " .. prompt)
        
        local response = session:ask(prompt)
        print("Output: " .. response)
        
        local stats = session:get_memory_stats()
        print(string.format("Stats: %d context entries, %d important memories", 
              stats.context_entries, stats.important_memories))
    end
    
    print("\n🎯 Final Memory Analysis:")
    local final_stats = session:get_memory_stats()
    print("Context entries:", final_stats.context_entries)
    print("Important memories:", final_stats.important_memories)
    print("Session ID:", final_stats.session_id)
    
    if #session.memory_state.important_memories > 0 then
        print("\nImportant memories captured:")
        for i, memory in ipairs(session.memory_state.important_memories) do
            print(string.format("  %d. [%d times] %s", 
                  i, memory.remember_count, memory.text:sub(1, 50)))
        end
    end
    
    session:save()
    print("\n✅ Test completed and saved!")
end
-- }}}

test_rolling_memory()