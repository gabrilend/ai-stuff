-- Byte encoding and statistics module for screen-record-stream
-- Handles hex dumps, byte visualization, and transfer statistics

local encode = {}

-- {{{ function encode.hex_dump
function encode.hex_dump(data, bytes_per_line, max_bytes)
    -- Create a hex dump of binary data
    -- Returns: formatted string showing hex and ASCII
    bytes_per_line = bytes_per_line or 16
    max_bytes = max_bytes or 256

    local result = {}
    local len = math.min(#data, max_bytes)

    for i = 1, len, bytes_per_line do
        local hex_part = {}
        local ascii_part = {}

        for j = 0, bytes_per_line - 1 do
            local pos = i + j
            if pos <= len then
                local byte = data:byte(pos)
                table.insert(hex_part, string.format("%02x", byte))

                -- Printable ASCII range
                if byte >= 32 and byte <= 126 then
                    table.insert(ascii_part, string.char(byte))
                else
                    table.insert(ascii_part, ".")
                end
            else
                table.insert(hex_part, "  ")
                table.insert(ascii_part, " ")
            end
        end

        table.insert(result, string.format(
            "%08x  %-48s |%s|",
            i - 1,
            table.concat(hex_part, " "),
            table.concat(ascii_part)
        ))
    end

    if len < #data then
        table.insert(result, string.format("... (%d more bytes)", #data - len))
    end

    return table.concat(result, "\n")
end
-- }}}

-- {{{ function encode.format_bytes
function encode.format_bytes(bytes)
    -- Format byte count as human-readable string
    -- Why: Easier to read "1.5 MB" than "1572864"
    if bytes < 1024 then
        return string.format("%d B", bytes)
    elseif bytes < 1024 * 1024 then
        return string.format("%.1f KB", bytes / 1024)
    else
        return string.format("%.2f MB", bytes / (1024 * 1024))
    end
end
-- }}}

-- {{{ function encode.stats_string
function encode.stats_string(config)
    -- Format current statistics as a string
    local stats = config.stats
    return string.format(
        "=== Transfer Statistics ===\n" ..
        "Bytes sent:     %s (%d frames)\n" ..
        "Bytes received: %s (%d frames)\n" ..
        "Last capture:   %.3f sec\n" ..
        "Last receive:   %.3f sec\n",
        encode.format_bytes(stats.bytes_sent),
        stats.frames_sent,
        encode.format_bytes(stats.bytes_received),
        stats.frames_received,
        stats.last_capture_time,
        stats.last_receive_time
    )
end
-- }}}

-- {{{ function encode.jpeg_info
function encode.jpeg_info(data)
    -- Extract basic info from JPEG data
    -- Returns: table with width, height, etc. or nil
    if #data < 4 then
        return nil
    end

    -- Check JPEG magic bytes (FFD8FF)
    if data:byte(1) ~= 0xFF or data:byte(2) ~= 0xD8 or data:byte(3) ~= 0xFF then
        return nil
    end

    local info = {
        is_jpeg = true,
        size = #data,
        width = nil,
        height = nil,
    }

    -- Parse JPEG markers to find SOF (Start Of Frame)
    local pos = 3
    while pos < #data - 8 do
        if data:byte(pos) ~= 0xFF then
            pos = pos + 1
        else
            local marker = data:byte(pos + 1)
            -- SOF0, SOF1, SOF2 markers contain dimensions
            if marker >= 0xC0 and marker <= 0xC3 then
                -- Skip marker (2) + length (2) + precision (1)
                info.height = data:byte(pos + 5) * 256 + data:byte(pos + 6)
                info.width = data:byte(pos + 7) * 256 + data:byte(pos + 8)
                break
            elseif marker == 0xD9 then
                -- End of image
                break
            elseif marker == 0xD8 then
                -- Start of image (skip)
                pos = pos + 2
            elseif marker >= 0xD0 and marker <= 0xD7 then
                -- RST markers (skip)
                pos = pos + 2
            else
                -- Skip this segment
                if pos + 3 <= #data then
                    local seg_len = data:byte(pos + 2) * 256 + data:byte(pos + 3)
                    pos = pos + 2 + seg_len
                else
                    break
                end
            end
        end
    end

    return info
end
-- }}}

-- {{{ function encode.header_bytes
function encode.header_bytes(data, count)
    -- Return first N bytes as hex string for debugging
    count = count or 16
    local bytes = {}
    for i = 1, math.min(count, #data) do
        table.insert(bytes, string.format("%02x", data:byte(i)))
    end
    return table.concat(bytes, " ")
end
-- }}}

return encode
