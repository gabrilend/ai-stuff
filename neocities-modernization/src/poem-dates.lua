-- poem-dates.lua: a poem's date, as a Unix time. One reader of dates for the
-- whole pipeline: the extractor numbers poems in date order (Issue 8-019)
-- and the chronological pages order them by it (Issue 8-045), so the two
-- can never disagree about which poem came first. Moved here from
-- src/flat-html-generator.lua unchanged, 2026-10-22.

local M = {}

-- {{{ function get_file_creation_timestamp
local function get_file_creation_timestamp(file_path)
    -- Use bash stat command to get file modification time (best approximation)
    local cmd = string.format("stat -c %%Y '%s' 2>/dev/null", file_path)
    local handle = io.popen(cmd)
    
    if handle then
        local result = handle:read("*a")
        handle:close()
        
        if result and result:match("^%d+") then
            return tonumber(result:match("^%d+"))
        end
    end
    
    return nil
end
-- }}}

-- {{{ function extract_post_date_from_poem
local function extract_post_date_from_poem(poem_data)
    -- First, try to use the creation_date metadata field (if available)
    local creation_date = poem_data.creation_date or (poem_data.metadata and poem_data.metadata.creation_date)
    if creation_date then
        -- Parse ISO 8601 format: "2023-04-20T05:22:03" or "2023-04-20T05:22:03Z"
        local year, month, day, hour, min, sec = creation_date:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
        if year and month and day then
            local parsed_time = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour) or 0,
                min = tonumber(min) or 0,
                sec = tonumber(sec) or 0
            })
            if parsed_time then return parsed_time end
        end
        
        -- Fallback: try to extract just date part
        year, month, day = creation_date:match("(%d+)-(%d+)-(%d+)")
        if year and month and day then
            local parsed_time = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = 0, min = 0, sec = 0
            })
            if parsed_time then return parsed_time end
        end
    end
    
    -- Fallback: Look for date patterns in poem content (legacy logic)
    local content = poem_data.content or ""
    
    -- First, try to extract YYYY-MM-DD from the very beginning (processing artifact dates)
    local year, month, day = content:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if year and month and day then
        return os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day)})
    end
    
    -- Try to extract date from first line (other patterns)
    local date_line = content:match("^([^\n]+)")
    if date_line then        
        -- MM/DD/YYYY format  
        local month, day, year = date_line:match("(%d%d)/(%d%d)/(%d%d%d%d)")
        if month and day and year then
            return os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day)})
        end
        
        -- Month DD, YYYY format (like "april 16th 2023")
        local month_name, day_num, year_num = date_line:match("(%w+)%s+(%d+)%w*%s+(%d%d%d%d)")
        if month_name and day_num and year_num then
            local month_map = {
                january=1, february=2, march=3, april=4, may=5, june=6,
                july=7, august=8, september=9, october=10, november=11, december=12
            }
            local month_num = month_map[month_name:lower()]
            if month_num then
                return os.time({year=tonumber(year_num), month=month_num, day=tonumber(day_num)})
            end
        end
    end
    
    -- Fallback to file creation time if available
    if poem_data.filepath then
        local timestamp = get_file_creation_timestamp(poem_data.filepath)
        if timestamp then
            return timestamp
        end
    end
    
    -- Issue 8-045: no date anywhere.  This used to return the poem's id as a
    -- "timestamp" -- a number of seconds after 1970 -- which put the poem at
    -- the very start of the timeline and stretched the timeline's span back to
    -- 1970, squashing every real poem into the last sliver of its bar.  The
    -- caller refuses a nil and names the poem.
    return nil
end
-- }}}

-- {{{ function M.timestamp
-- The poem's date as a Unix time (number), or nil when it has none
-- anywhere; callers stop and name the poem (a guessed date would move it on
-- the timeline).
M.timestamp = extract_post_date_from_poem
-- }}}

return M
