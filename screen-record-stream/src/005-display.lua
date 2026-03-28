-- Display module for screen-record-stream
-- Handles saving and viewing received screen data

local display = {}

-- {{{ function display.save
function display.save(data, path)
    -- Save binary data to file
    -- Returns: true or nil, error
    local file, err = io.open(path, "wb")
    if not file then
        return nil, "failed to open " .. path .. ": " .. tostring(err)
    end

    file:write(data)
    file:close()

    return true
end
-- }}}

-- {{{ function display.open_viewer
function display.open_viewer(path, viewer)
    -- Open image in external viewer (non-blocking)
    -- Why: Allows viewing received screen without blocking server
    viewer = viewer or "feh"

    -- Run in background
    local cmd = viewer .. " " .. path .. " &"
    os.execute(cmd)

    return true
end
-- }}}

-- {{{ function display.ascii_preview
function display.ascii_preview(jpeg_path, width, height)
    -- Convert image to ASCII art for terminal display
    -- Uses jp2a if available, falls back to dimensions only
    width = width or 80
    height = height or 24

    local cmd = string.format(
        "jp2a --width=%d --height=%d %s 2>/dev/null",
        width, height, jpeg_path
    )

    local handle = io.popen(cmd)
    if not handle then
        return "[ASCII preview unavailable - jp2a not installed]"
    end

    local output = handle:read("*a")
    handle:close()

    if output and #output > 0 then
        return output
    else
        return "[ASCII preview failed]"
    end
end
-- }}}

-- {{{ function display.terminal_preview
function display.terminal_preview(data, encode_module)
    -- Show a preview in terminal using hex dump and stats
    -- encode_module: the encode module for hex_dump function
    local lines = {}

    local info = encode_module.jpeg_info(data)
    if info then
        table.insert(lines, string.format(
            "JPEG: %dx%d, %s",
            info.width or 0,
            info.height or 0,
            encode_module.format_bytes(info.size)
        ))
    else
        table.insert(lines, string.format("Binary data: %s", encode_module.format_bytes(#data)))
    end

    table.insert(lines, "")
    table.insert(lines, "First 128 bytes:")
    table.insert(lines, encode_module.hex_dump(data, 16, 128))

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ function display.update_live
function display.update_live(path, viewer_pid)
    -- Update a live viewer (feh can reload on signal)
    -- Returns: new pid if viewer was started, or existing pid
    if viewer_pid then
        -- Send SIGUSR1 to feh to reload
        os.execute("kill -USR1 " .. viewer_pid .. " 2>/dev/null")
        return viewer_pid
    else
        -- Start new viewer with auto-reload
        local cmd = string.format("feh --reload 1 %s &", path)
        os.execute(cmd)

        -- Get PID of feh (rough approach)
        local handle = io.popen("pgrep -n feh")
        if handle then
            local pid = handle:read("*l")
            handle:close()
            return pid
        end
        return nil
    end
end
-- }}}

return display
