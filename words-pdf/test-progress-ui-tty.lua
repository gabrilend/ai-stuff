-- test-progress-ui-tty.lua
-- Issue 026: exercise the interactive (tty-bound) code path by monkey-
-- patching io.open so /dev/tty resolves to a temp file we can inspect
-- afterwards. Verifies cursor-positioning escapes fire in the right
-- spots and that padding is applied on under-height pages.

package.path = package.path .. ";./?.lua"

local FAKE_TTY_PATH = "/tmp/test-progress-ui-tty.bytes"
os.remove(FAKE_TTY_PATH)

local real_open = io.open
io.open = function(path, mode)
    if path == "/dev/tty" then
        return real_open(FAKE_TTY_PATH, "w")
    end
    return real_open(path, mode)
end

local progress_ui = require "libs/progress-ui"

local TOTAL = 5
progress_ui.init(TOTAL)

-- Page 1: 3 status lines → buffer height 4 (bar + 3)
progress_ui.start_page(1)
progress_ui.log("line A")
progress_ui.log("line B")
progress_ui.log("line C")
progress_ui.end_page()

-- Page 2: 6 status lines → buffer height 7, grows the high-water mark
progress_ui.start_page(2)
for i = 1, 6 do progress_ui.log("line " .. i) end
progress_ui.end_page()

-- Page 3: 2 status lines → buffer height 3, should pad with 4 blank lines
progress_ui.start_page(3)
progress_ui.log("short A")
progress_ui.log("short B")
progress_ui.end_page()

progress_ui.finish()

-- Inspect the captured bytes.
local f = real_open(FAKE_TTY_PATH, "rb")
local content = f:read("*a")
f:close()

-- Look for the cursor-up escape before page 2 and page 3.
local cursor_ups = {}
for code in content:gmatch("\27%[(%d+)A") do
    table.insert(cursor_ups, tonumber(code))
end
print("cursor-up escapes (by lines): " .. table.concat(cursor_ups, ", "))

local clears = 0
for _ in content:gmatch("\27%[0J") do clears = clears + 1 end
print("clear-to-eos escapes: " .. clears)

-- Count trailing blank lines after the page-3 frame to confirm padding.
-- Page 3 wrote: bar + "short A" + "short B" = 3 lines, max_region_height = 7
-- → should pad with 4 newlines.
local last_idx = content:match(".*short B[^\n]*\n()")
local padding_section = content:sub(last_idx or 1)
-- Strip the final color-reset from finish() before counting newlines
padding_section = padding_section:gsub("\27%[0m", "")
local blanks = 0
for _ in padding_section:gmatch("\n") do blanks = blanks + 1 end
print("blank lines after page 3's last status line: " .. blanks)
print("(expected: 4, since page 3 used 3 of the 7-line region)")
