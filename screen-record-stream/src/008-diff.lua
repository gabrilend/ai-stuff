-- Frame differencing module for screen-record-stream
-- Detects changes between frames to reduce bandwidth
-- Why: Only transmit data when screen actually changes

local diff = {}

-- {{{ State for tracking changes
local state = {
    last_hash = nil,
    last_size = 0,
    last_data = nil,
    change_count = 0,
    no_change_count = 0,
}
-- }}}

-- {{{ function diff.simple_hash
function diff.simple_hash(data)
    -- Compute a simple hash of binary data
    -- Why: Fast change detection without full comparison
    -- Uses: Sample bytes at regular intervals + total size
    local hash = #data
    local step = math.max(1, math.floor(#data / 256))

    for i = 1, #data, step do
        local byte = data:byte(i)
        -- Simple mixing function
        hash = ((hash * 31) + byte) % 2147483647
    end

    return hash
end
-- }}}

-- {{{ function diff.has_changed
function diff.has_changed(data)
    -- Check if frame has changed from last frame
    -- Returns: true if changed, false if same
    local hash = diff.simple_hash(data)

    if state.last_hash == nil then
        -- First frame always counts as changed
        state.last_hash = hash
        state.last_size = #data
        state.last_data = data
        state.change_count = state.change_count + 1
        return true
    end

    -- Size difference is a quick indicator of change
    local size_diff = math.abs(#data - state.last_size)
    local size_threshold = state.last_size * 0.01  -- 1% size change

    if size_diff > size_threshold or hash ~= state.last_hash then
        state.last_hash = hash
        state.last_size = #data
        state.last_data = data
        state.change_count = state.change_count + 1
        return true
    end

    state.no_change_count = state.no_change_count + 1
    return false
end
-- }}}

-- {{{ function diff.get_last_frame
function diff.get_last_frame()
    -- Get the last stored frame data
    -- Why: Allows serving cached frame when no change
    return state.last_data
end
-- }}}

-- {{{ function diff.get_stats
function diff.get_stats()
    -- Return change detection statistics
    local total = state.change_count + state.no_change_count
    local change_ratio = 0
    if total > 0 then
        change_ratio = state.change_count / total
    end

    return {
        changes = state.change_count,
        no_changes = state.no_change_count,
        change_ratio = change_ratio,
        last_size = state.last_size,
    }
end
-- }}}

-- {{{ function diff.reset
function diff.reset()
    -- Reset change tracking state
    -- Why: Fresh start for new streaming session
    state.last_hash = nil
    state.last_size = 0
    state.last_data = nil
    state.change_count = 0
    state.no_change_count = 0
end
-- }}}

-- {{{ function diff.force_keyframe
function diff.force_keyframe()
    -- Force next frame to be treated as changed
    -- Why: Periodic keyframes ensure client stays in sync
    state.last_hash = nil
end
-- }}}

return diff
