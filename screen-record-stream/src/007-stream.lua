-- Streaming module for screen-record-stream
-- Manages continuous capture and frame buffering
-- Why: Decouples capture rate from request rate for smoother streaming

local stream = {}

-- {{{ Frame buffer (ring buffer)
-- Stores recent frames for serving to clients
-- Why: Allows multiple clients to get frames without re-capturing
local frame_buffer = {
    frames = {},      -- Array of {data, timestamp, index}
    capacity = 10,    -- Keep last N frames
    head = 0,         -- Next write position
    count = 0,        -- Number of valid frames
    frame_index = 0,  -- Global frame counter
}
-- }}}

-- {{{ function stream.init
function stream.init(config)
    -- Initialize streaming state
    -- Why: Reset buffer and set up capture parameters
    frame_buffer.frames = {}
    frame_buffer.head = 0
    frame_buffer.count = 0
    frame_buffer.frame_index = 0

    -- Pre-allocate buffer slots
    for i = 1, frame_buffer.capacity do
        frame_buffer.frames[i] = nil
    end

    stream.config = config
    stream.running = false
    stream.last_capture = 0
    stream.capture_errors = 0

    return stream
end
-- }}}

-- {{{ function stream.push_frame
function stream.push_frame(data, timestamp)
    -- Add a frame to the ring buffer
    -- Why: Ring buffer provides constant memory usage
    frame_buffer.frame_index = frame_buffer.frame_index + 1
    frame_buffer.head = (frame_buffer.head % frame_buffer.capacity) + 1

    frame_buffer.frames[frame_buffer.head] = {
        data = data,
        timestamp = timestamp,
        index = frame_buffer.frame_index,
    }

    if frame_buffer.count < frame_buffer.capacity then
        frame_buffer.count = frame_buffer.count + 1
    end
end
-- }}}

-- {{{ function stream.get_latest
function stream.get_latest()
    -- Get the most recent frame
    -- Returns: frame table {data, timestamp, index} or nil
    if frame_buffer.count == 0 then
        return nil
    end
    return frame_buffer.frames[frame_buffer.head]
end
-- }}}

-- {{{ function stream.get_frame_after
function stream.get_frame_after(after_index)
    -- Get the first frame with index > after_index
    -- Why: Allows clients to request "next frame" for streaming
    -- Returns: frame table or nil if no newer frame
    if frame_buffer.count == 0 then
        return nil
    end

    -- Search buffer for frame with index > after_index
    -- Start from oldest and find first valid newer frame
    for i = 1, frame_buffer.count do
        local pos = ((frame_buffer.head - frame_buffer.count + i - 1) % frame_buffer.capacity) + 1
        local frame = frame_buffer.frames[pos]
        if frame and frame.index > after_index then
            return frame
        end
    end

    return nil
end
-- }}}

-- {{{ function stream.capture_once
function stream.capture_once(capture_module, config)
    -- Capture a single frame and add to buffer
    -- Returns: frame table or nil, error
    local socket = require("socket")
    local timestamp = socket.gettime()

    local data, err = capture_module.screenshot(config)
    if not data then
        stream.capture_errors = stream.capture_errors + 1
        return nil, err
    end

    stream.push_frame(data, timestamp)
    stream.last_capture = timestamp

    return stream.get_latest()
end
-- }}}

-- {{{ function stream.get_stats
function stream.get_stats()
    -- Return streaming statistics
    return {
        buffer_count = frame_buffer.count,
        buffer_capacity = frame_buffer.capacity,
        total_frames = frame_buffer.frame_index,
        capture_errors = stream.capture_errors,
        running = stream.running,
    }
end
-- }}}

-- {{{ function stream.should_capture
function stream.should_capture(config)
    -- Check if enough time has passed for next capture
    -- Why: Rate limiting to target FPS
    local socket = require("socket")
    local now = socket.gettime()
    local interval = 1.0 / (config.target_fps or 10)

    return (now - stream.last_capture) >= interval
end
-- }}}

return stream
