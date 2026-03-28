-- Screen capture module for screen-record-stream
-- Uses ffmpeg to grab X11 display and encode as JPEG

local capture = {}

-- {{{ function capture.screenshot
function capture.screenshot(config)
    -- Capture current screen to JPEG bytes
    -- Returns: raw JPEG bytes, capture time in seconds
    local start_time = os.clock()

    local output_path = config.tmp_dir .. "screen.jpg"

    -- Build ffmpeg command
    -- -f x11grab: capture from X11
    -- -video_size: capture resolution
    -- -i: input display
    -- -vframes 1: single frame
    -- -q:v: JPEG quality (2-31, lower = better, we map 100->2, 1->31)
    -- -y: overwrite output
    local quality = math.floor(31 - (config.capture_quality / 100 * 29))
    if quality < 2 then quality = 2 end
    if quality > 31 then quality = 31 end

    local cmd = string.format(
        "ffmpeg -f x11grab -video_size %dx%d -i %s -vframes 1 -q:v %d -y %s 2>/dev/null",
        config.capture_width,
        config.capture_height,
        config.capture_display,
        quality,
        output_path
    )

    local result = os.execute(cmd)

    if result ~= 0 and result ~= true then
        -- Why: os.execute returns different values in different Lua versions
        -- LuaJIT returns status code, Lua 5.2+ returns true/nil
        return nil, "ffmpeg capture failed"
    end

    -- Read the captured file
    local file = io.open(output_path, "rb")
    if not file then
        return nil, "failed to open captured file"
    end

    local bytes = file:read("*a")
    file:close()

    local elapsed = os.clock() - start_time
    config.stats.last_capture_time = elapsed

    return bytes, elapsed
end
-- }}}

-- {{{ function capture.screenshot_region
function capture.screenshot_region(config, x, y, w, h)
    -- Capture a specific region of the screen
    -- For future use with frame differencing
    local start_time = os.clock()

    local output_path = config.tmp_dir .. "region.jpg"

    local quality = math.floor(31 - (config.capture_quality / 100 * 29))
    if quality < 2 then quality = 2 end

    local cmd = string.format(
        "ffmpeg -f x11grab -video_size %dx%d -grab_x %d -grab_y %d -i %s -vframes 1 -q:v %d -y %s 2>/dev/null",
        w, h, x, y,
        config.capture_display,
        quality,
        output_path
    )

    local result = os.execute(cmd)

    if result ~= 0 and result ~= true then
        return nil, "ffmpeg region capture failed"
    end

    local file = io.open(output_path, "rb")
    if not file then
        return nil, "failed to open captured region file"
    end

    local bytes = file:read("*a")
    file:close()

    return bytes, os.clock() - start_time
end
-- }}}

-- {{{ function capture.get_display_size
function capture.get_display_size(display)
    -- Query X11 for display dimensions
    -- Returns: width, height or nil, error
    display = display or ":0"

    local handle = io.popen("xdpyinfo -display " .. display .. " 2>/dev/null | grep dimensions")
    if not handle then
        return nil, "failed to run xdpyinfo"
    end

    local output = handle:read("*a")
    handle:close()

    local width, height = output:match("(%d+)x(%d+)")
    if width and height then
        return tonumber(width), tonumber(height)
    end

    return nil, "could not parse display dimensions"
end
-- }}}

return capture
