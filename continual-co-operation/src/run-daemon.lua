#!/usr/bin/env lua

local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/continual-co-operation"
local mode = arg and arg[2] or "standard"

package.path = DIR .. "/src/?.lua;" .. package.path

local heartbeat_daemon = require("heartbeat-daemon")

-- {{{ local function get_config_by_mode
local function get_config_by_mode(mode)
    local configs = {
        quick = {
            frequency = 0.2,      -- 0.2 Hz = 12 BPM (quick thoughts)
            cycle_duration = 5,   -- 5 seconds per cycle
            duration = 600,       -- 10 minutes
            vmax = 1.0
        },
        standard = {
            frequency = 0.1,      -- 0.1 Hz = 6 BPM (contemplative)
            cycle_duration = 10,  -- 10 seconds per cycle
            duration = 3600,      -- 1 hour
            vmax = 1.0
        },
        extended = {
            frequency = 0.05,     -- 0.05 Hz = 3 BPM (deep contemplation)
            cycle_duration = 20,  -- 20 seconds per cycle
            duration = 14400,     -- 4 hours
            vmax = 1.0
        },
        background = {
            frequency = 0.033,    -- 0.033 Hz = 2 BPM (very slow, background processing)
            cycle_duration = 30,  -- 30 seconds per cycle
            duration = 86400,     -- 24 hours
            vmax = 1.0
        }
    }
    
    return configs[mode]
end
-- }}}

-- {{{ main execution
local function main()
    local config
    
    if mode == "custom" then
        config = heartbeat_daemon.create_config_interactive()
    else
        config = get_config_by_mode(mode)
        if not config then
            print("Error: Unknown mode '" .. mode .. "'")
            print("Available modes: quick, standard, extended, background, custom")
            os.exit(1)
        end
    end
    
    print("Configuration:")
    print(string.format("  Mode: %s", mode))
    print(string.format("  Frequency: %.3f Hz (%.1f BPM)", config.frequency, config.frequency * 60))
    print(string.format("  Cycle duration: %d seconds", config.cycle_duration))
    print(string.format("  Total duration: %.1f minutes", config.duration / 60))
    print("")
    
    heartbeat_daemon.start_daemon(config)
end
-- }}}

main()