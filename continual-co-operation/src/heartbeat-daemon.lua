#!/usr/bin/env lua

local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/continual-co-operation"
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path

local rolling_memory = require("rolling-memory")
local dkjson = require("dkjson")

local M = {}

-- {{{ local function calculate_heartbeat_voltage
local function calculate_heartbeat_voltage(t, frequency, vmax)
    frequency = frequency or 1.0  -- 1 Hz = 60 BPM
    vmax = vmax or 1.0
    return vmax * math.sin(2 * math.pi * frequency * t)
end
-- }}}

-- {{{ local function is_contraction_phase
local function is_contraction_phase(voltage, threshold)
    threshold = threshold or 0.5
    return voltage > threshold
end
-- }}}

-- {{{ local function generate_autonomous_prompt
local function generate_autonomous_prompt(session, cycle_count, voltage)
    local prompts = {
        "What thoughts are currently occupying my processing space?",
        "What important concepts should I preserve from recent context?",
        "Are there any patterns or connections I should remember?",
        "What knowledge feels significant enough to think about twice?",
        "How can I better organize the information flowing through my mind?",
        "What insights are emerging from my recent conversations?",
        "Which memories deserve to persist beyond the current context window?",
        "What am I learning that could be valuable later?",
        "Are there any important themes I should continue developing?",
        "What knowledge bridges are forming between different concepts?"
    }
    
    local base_prompt = prompts[((cycle_count - 1) % #prompts) + 1]
    local stats = session:get_memory_stats()
    
    local context_prompt = string.format(
        "%s\n\nContext: Cycle %d, Voltage: %.3f, Context entries: %d, Important memories: %d",
        base_prompt, cycle_count, voltage, stats.context_entries, stats.important_memories
    )
    
    return context_prompt
end
-- }}}

-- {{{ local function autonomous_reflection_cycle
local function autonomous_reflection_cycle(session, cycle_count, voltage)
    if is_contraction_phase(voltage) then
        local prompt = generate_autonomous_prompt(session, cycle_count, voltage)
        
        print(string.format("[%s] 💓 Heartbeat %d (V=%.3f) - Autonomous reflection...", 
              os.date("%H:%M:%S"), cycle_count, voltage))
        
        local response = session:ask(prompt)
        
        print(string.format("🧠 Reflection: %s", response:sub(1, 100) .. "..."))
        
        local output_file = DIR .. "/outputs/heartbeat-log.txt"
        os.execute("mkdir -p " .. DIR .. "/outputs")
        local file = io.open(output_file, "a")
        if file then
            file:write(string.format("[%s] Cycle %d (V=%.3f):\n", os.date("%Y-%m-%d %H:%M:%S"), cycle_count, voltage))
            file:write(string.format("Prompt: %s\n", prompt))
            file:write(string.format("Response: %s\n\n", response))
            file:close()
        end
        
        return true
    end
    
    return false
end
-- }}}

-- {{{ function M.start_daemon
function M.start_daemon(config)
    config = config or {}
    local heartbeat_frequency = config.frequency or 0.1  -- 0.1 Hz = 6 BPM (slow contemplative pace)
    local cycle_duration = config.cycle_duration or 10   -- seconds per cycle
    local vmax = config.vmax or 1.0
    local daemon_duration = config.duration or 3600     -- 1 hour default
    
    print("🤖 Starting Continual Co-operation Heartbeat Daemon")
    print("====================================================")
    print(string.format("Heartbeat frequency: %.3f Hz", heartbeat_frequency))
    print(string.format("Cycle duration: %d seconds", cycle_duration))
    print(string.format("Total runtime: %d seconds (%.1f minutes)", daemon_duration, daemon_duration/60))
    print("")
    
    local session = rolling_memory.create_session(DIR .. "/daemon-memory-state.json")
    
    session:ask("I am beginning autonomous operation. I will periodically reflect on my thoughts and preserve important memories through continual self-examination.")
    
    local start_time = os.time()
    local cycle_count = 0
    
    while (os.time() - start_time) < daemon_duration do
        local elapsed_time = os.time() - start_time
        local voltage = calculate_heartbeat_voltage(elapsed_time, heartbeat_frequency, vmax)
        
        cycle_count = cycle_count + 1
        
        local reflected = autonomous_reflection_cycle(session, cycle_count, voltage)
        
        if not reflected then
            print(string.format("[%s] 💤 Relaxation phase (V=%.3f)", os.date("%H:%M:%S"), voltage))
        end
        
        local stats = session:get_memory_stats()
        if cycle_count % 10 == 0 then
            print(string.format("📊 Stats: %d cycles, %d context entries, %d important memories", 
                  cycle_count, stats.context_entries, stats.important_memories))
        end
        
        session:save()
        
        -- Wait for next cycle
        os.execute("sleep " .. cycle_duration)
    end
    
    session:ask("Autonomous operation cycle complete. Saving final state and important discoveries.")
    session:save()
    
    print(string.format("\n✅ Daemon completed %d cycles over %.1f minutes", 
          cycle_count, (os.time() - start_time)/60))
    print("💾 Memory state saved to daemon-memory-state.json")
end
-- }}}

-- {{{ function M.create_config_interactive
function M.create_config_interactive()
    print("🎛️  Heartbeat Daemon Configuration")
    print("=================================")
    
    io.write("Heartbeat frequency in Hz (0.05-1.0, default 0.1): ")
    local freq_input = io.read("*line")
    local frequency = tonumber(freq_input) or 0.1
    
    io.write("Cycle duration in seconds (5-60, default 10): ")
    local cycle_input = io.read("*line")
    local cycle_duration = tonumber(cycle_input) or 10
    
    io.write("Total runtime in minutes (10-1440, default 60): ")
    local duration_input = io.read("*line")
    local duration_minutes = tonumber(duration_input) or 60
    local duration = duration_minutes * 60
    
    return {
        frequency = frequency,
        cycle_duration = cycle_duration,
        duration = duration,
        vmax = 1.0
    }
end
-- }}}

return M