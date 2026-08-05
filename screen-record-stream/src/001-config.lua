-- Configuration module for screen-record-stream
-- Holds all configurable values and paths for the application

-- Hardcoded project directory
-- Why: Reliable path regardless of how script is invoked
-- Can be overridden via --dir= argument
local DIR = "/mnt/mtwo/programming/ai-stuff/screen-record-stream/"

-- Ensure DIR ends with /
-- Why: Consistent path concatenation throughout the application
if DIR:sub(-1) ~= "/" then
    DIR = DIR .. "/"
end

local config = {
    -- Project root directory
    DIR = DIR,

    -- Server settings
    port = 8080,
    bind_address = "0.0.0.0",

    -- Peer settings (the other machine to share screens with)
    peer_host = nil,  -- Set via command line: --peer=192.168.1.100
    peer_port = 8080,

    -- Capture settings
    capture_quality = 80,      -- JPEG quality (1-100)
    capture_width = 1920,      -- Max width (0 = native)
    capture_height = 1080,     -- Max height (0 = native)
    capture_display = ":0",    -- X11 display

    -- Timing
    poll_interval = 1.0,       -- Seconds between fetching peer's screen
    capture_interval = 0.5,    -- Seconds between captures

    -- Streaming settings (Phase 2)
    target_fps = 10,           -- Target frames per second
    keyframe_interval = 30,    -- Force keyframe every N frames
    stream_timeout = 60,       -- Max seconds for streaming connection

    -- Paths
    tmp_dir = DIR .. "tmp/",
    output_dir = DIR .. "output/",

    -- Library paths (luasocket)
    luasocket_cpath = "/home/ritz/programming/ai-stuff/libs/lua/luasocket/lib/lua/5.1/?.so",
    luasocket_path = "/home/ritz/programming/ai-stuff/libs/lua/luasocket/share/lua/5.1/?.lua",

    -- Statistics (updated at runtime)
    stats = {
        bytes_sent = 0,
        bytes_received = 0,
        frames_sent = 0,
        frames_received = 0,
        last_capture_time = 0,
        last_receive_time = 0,
    }
}

-- {{{ function config.parse_args
function config.parse_args(args)
    -- Parse command line arguments and update config
    -- Args like --port=8081 --peer=192.168.1.100
    for i, arg in ipairs(args) do
        local key, value = arg:match("^%-%-([^=]+)=(.+)$")
        if key == "port" then
            config.port = tonumber(value)
        elseif key == "peer" then
            config.peer_host = value
        elseif key == "peer-port" then
            config.peer_port = tonumber(value)
        elseif key == "quality" then
            config.capture_quality = tonumber(value)
        elseif key == "display" then
            config.capture_display = value
        elseif key == "fps" then
            config.target_fps = tonumber(value)
        elseif key == "dir" then
            config.DIR = value
            if config.DIR:sub(-1) ~= "/" then
                config.DIR = config.DIR .. "/"
            end
            config.tmp_dir = config.DIR .. "tmp/"
            config.output_dir = config.DIR .. "output/"
        end
    end
    return config
end
-- }}}

-- {{{ function config.setup_paths
function config.setup_paths()
    -- Add luasocket to package paths
    -- Why: luasocket is in a non-standard location
    package.cpath = config.luasocket_cpath .. ";" .. package.cpath
    package.path = config.luasocket_path .. ";" .. package.path
end
-- }}}

return config
