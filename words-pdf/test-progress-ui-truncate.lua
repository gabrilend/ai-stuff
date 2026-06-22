-- test-progress-ui-truncate.lua
-- Issue 026 follow-up: simulate a tiny terminal (8 rows) and a page
-- that wants to emit far more lines than fit. Verifies the frame is
-- truncated with an indicator and that the redraw region never grows
-- past the cap, so the cursor-up jump in the next page stays within
-- the visible terminal.

package.path = package.path .. ";./?.lua"

local FAKE_TTY_PATH = "/tmp/test-progress-ui-truncate.bytes"
os.remove(FAKE_TTY_PATH)

local real_open = io.open
io.open = function(path, mode)
    if path == "/dev/tty" then
        return real_open(FAKE_TTY_PATH, "w")
    end
    return real_open(path, mode)
end

-- Force a small terminal so the cap kicks in regardless of the host env.
local real_popen = io.popen
io.popen = function(cmd)
    if cmd:match("tput lines") then
        -- Return a faked tput response: 8 rows.
        return real_popen("echo 8")
    end
    return real_popen(cmd)
end

local progress_ui = require "libs/progress-ui"

progress_ui.init(3)

-- Page 1: emit 20 status lines on an 8-row terminal. frame_cap = 7.
-- Expected: bar + 5 visible status lines + 1 "...+15 more" indicator = 7 lines.
progress_ui.start_page(1)
for i = 1, 20 do progress_ui.log("status line " .. i) end
progress_ui.end_page()

-- Page 2: cursor-up should be 7 (not 21), and the same truncation applies.
progress_ui.start_page(2)
for i = 1, 20 do progress_ui.log("status line " .. i) end
progress_ui.end_page()

progress_ui.finish()

local f = real_open(FAKE_TTY_PATH, "rb")
local content = f:read("*a")
f:close()

local cursor_ups = {}
for code in content:gmatch("\27%[(%d+)A") do
    table.insert(cursor_ups, tonumber(code))
end
print("cursor-up escapes: " .. table.concat(cursor_ups, ", "))
print("(expected: 7, since frame_cap = tty_rows - 1 = 8 - 1)")

local has_indicator = content:find("more lines %(see log%)", 1, false)
print("truncation indicator present: " .. tostring(has_indicator ~= nil))

-- Count visible status lines per frame (between the bar and the indicator).
local first_frame = content:match("Processing page 1/3.-more lines")
local _, visible_status_count = first_frame:gsub("status line %d+", "")
print("visible status lines in frame 1: " .. visible_status_count)
print("(expected: 5, since frame layout is bar + 5 + indicator = 7)")
