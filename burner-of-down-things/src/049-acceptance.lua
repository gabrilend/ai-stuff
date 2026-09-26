-- 049-acceptance.lua
--
-- Running an issue's acceptance commands in the design folder (docs/007,
-- "acceptance"). The commands come from the issue's Acceptance section,
-- exactly as written; each runs with bash, from the design folder, under a
-- time limit, one at a time, the first failure ending the issue's run. What
-- they print is kept in the turn folder that last built or repaired the
-- issue, so a repair turn can be shown exactly what went wrong.
--
-- These are commands a model wrote, run with the person's permissions; the
-- first build of a case says so in output/first-build.

local fs = require("017-the-filesystem")

local acceptance = {}

acceptance.LIMIT = 120
acceptance.TAIL_LINES = 60

-- {{{ local function tail
local function tail(text, n)
    local lines = {}
    for line in text:gmatch("[^\n]*\n?") do
        if line ~= "" then
            lines[#lines + 1] = line:gsub("\n$", "")
        end
    end
    local from = math.max(1, #lines - n + 1)
    return table.concat(lines, "\n", from)
end
-- }}}

-- {{{ function acceptance.run
-- `issue` is from 044's read; `record_folder` is the turn folder to keep
-- the output in (or nil). Returns { ok = true } or { ok = false, command,
-- output (last lines), timed_out = boolean }.
function acceptance.run(record, issue, record_folder, limit)
    local log = {}
    for _, command in ipairs(issue.acceptance) do
        local out, ok, status = fs.capture("cd " .. fs.quote(record.design) .. " && timeout --kill-after=5 "
            .. tostring(limit or acceptance.LIMIT) .. " bash -c " .. fs.quote(command) .. " 2>&1")
        log[#log + 1] = "$ " .. command .. "\n" .. out .. "\n(exit " .. tostring(status) .. ")"
        if not ok then
            if record_folder then
                fs.write(record_folder .. "/acceptance.txt", table.concat(log, "\n"))
            end
            -- 124 is timeout's own status; 137 is a process killed after it.
            local timed_out = status == 124 or status == 137
            return {
                ok = false, command = command, timed_out = timed_out,
                output = (timed_out and ("(stopped after " .. tostring(limit or acceptance.LIMIT) .. " seconds)\n") or "")
                    .. tail(out, acceptance.TAIL_LINES),
            }
        end
    end
    if record_folder then
        fs.write(record_folder .. "/acceptance.txt", table.concat(log, "\n"))
    end
    return { ok = true }
end
-- }}}

return acceptance
