#!/usr/bin/env luajit

-- Background input listener for theme analysis
-- Runs as hidden process, monitors for 'q'/'c' keypresses via Unix socket communication

local socket = require("socket")
local unix = require("socket.unix")

-- Parse command line arguments
local socket_path = arg[1]
if not socket_path then
    -- Silent exit - this process should be invisible
    os.exit(1)
end

-- Main input monitoring loop - blocking is fine since this is dedicated input process
local function monitor_input()
    -- Connect to Unix socket for communication with main process
    local client = unix()
    if not client then
        os.exit(1)
    end
    
    -- Try to connect to the socket (retry with backoff)
    local connected = false
    for attempt = 1, 20 do
        local success, err = client:connect(socket_path)
        if success then
            connected = true
            break
        else
            socket.sleep(0.1)  -- Wait 100ms before retry
        end
    end
    
    if not connected then
        client:close()
        os.exit(1)
    end
    
    -- Simple blocking input loop - dedicated process can afford to block
    while true do
        -- Read single character (blocking)
        local char = io.read(1)
        
        if char then
            if char == 'q' or char == 'Q' or char == 'c' or char == 'C' then
                -- Send quit signal to main process
                local msg = "quit:" .. char
                client:send(msg)
                break
            elseif char == '\003' then  -- Ctrl+C
                local msg = "quit:ctrl_c"
                client:send(msg)
                break
            end
            -- Silently ignore other characters
        else
            -- EOF or error, exit gracefully
            break
        end
    end
    
    client:close()
end

-- Main execution - minimal error handling since this should be invisible
pcall(monitor_input)
os.exit(0)