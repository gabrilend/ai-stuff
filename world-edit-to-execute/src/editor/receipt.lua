--[[
The W Client's Goodbye Receipt (Issue 913, step 4; W client issue 1109)

When the W client opened by Test Map closes, it writes a receipt: a Lua
data file, written whole (to a temporary name, then renamed), at the path
the editor gave it with --receipt:

  return { format = 1, map = "<folder as given>",
           started = "2026-11-04T20:31:07Z", ended = "2026-11-04T20:32:10Z",
           seconds = 63.2, frames = 3790,
           reason = "closed" | "lost-connection" | "error",
           why = "<a sentence, only when reason is error>" }

It is read here in an empty environment (no functions reachable, no
bytecode, a count of instructions it may run), every field checked, and
refused when anything is wrong: a missing or mistyped field, a field the
format doesn't have, a map other than the one Test Map opened, or a format
number above the one this editor reads. No receipt at all, once the W
client has exited, is a crash (test_map.lua says so).

    local receipt = require("editor.receipt")
    local r, why = receipt.read(path, folder)   -- the table, or nil and why
    receipt.describe(r)                         -- one line for the status bar
]]

local receipt = {}

receipt.FORMAT = 1            -- the newest format this editor reads
receipt.MAX_BYTES = 64 * 1024
receipt.MAX_STEPS = 100000    -- instructions the file may run
receipt.REASONS = { closed = true, ["lost-connection"] = true, error = true }

local FIELDS = { format = true, map = true, started = true, ended = true, seconds = true, frames = true,
                 reason = true, why = true }
local TIME = "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"

-- {{{ run the file's text as data (receipt.run_data: also how Test Map
-- reads the converter's conversion-report.lua; max_steps, else MAX_STEPS)
local function run_data(text, name, max_steps)
    max_steps = max_steps or receipt.MAX_STEPS
    local env = {}
    local chunk, err
    if text:sub(1, 1) == "\27" then return nil, "it is compiled code, not text" end
    if setfenv then
        chunk, err = loadstring(text, "=" .. name)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = load(text, "=" .. name, "t", env)
    end
    if not chunk then return nil, "it isn't Lua: " .. tostring(err) end
    -- compiled traces don't call hooks: the count below needs the interpreter
    if jit then jit.off(chunk, true) end
    local steps = 0
    debug.sethook(function()
        steps = steps + 1000
        if steps > max_steps then error("it runs too long to be data", 2) end
    end, "", 1000)
    local ok, t = pcall(chunk)
    debug.sethook()
    if not ok then return nil, "it fails when read: " .. tostring(t) end
    if type(t) ~= "table" then return nil, "it doesn't return a table" end
    return t
end
receipt.run_data = run_data
-- }}}

-- {{{ receipt.check: every field
function receipt.check(t, folder)
    for k in pairs(t) do
        if not FIELDS[k] then return nil, "it has a field the format doesn't: " .. tostring(k) end
    end
    if type(t.format) ~= "number" or t.format ~= math.floor(t.format) or t.format < 1 then
        return nil, "format isn't a whole number from 1"
    end
    if t.format > receipt.FORMAT then
        return nil, string.format("its format %d is newer than this editor reads (%d)", t.format, receipt.FORMAT)
    end
    if type(t.map) ~= "string" then return nil, "map isn't text" end
    if folder and t.map ~= folder then
        return nil, "it is for another map (" .. t.map .. ", not " .. folder .. ")"
    end
    for _, k in ipairs({ "started", "ended" }) do
        if type(t[k]) ~= "string" or not t[k]:match(TIME) then
            return nil, k .. " isn't a UTC time like 2026-11-04T20:31:07Z"
        end
    end
    if t.ended < t.started then return nil, "it ended before it started" end
    if type(t.seconds) ~= "number" or t.seconds ~= t.seconds or t.seconds < 0 or t.seconds == math.huge then
        return nil, "seconds isn't a number from 0"
    end
    if type(t.frames) ~= "number" or t.frames ~= math.floor(t.frames) or t.frames < 0 or t.frames == math.huge then
        return nil, "frames isn't a whole number from 0"
    end
    if type(t.reason) ~= "string" or not receipt.REASONS[t.reason] then
        return nil, "reason isn't closed, lost-connection or error"
    end
    if t.reason == "error" then
        if type(t.why) ~= "string" or t.why == "" then return nil, "reason is error but why is missing" end
    elseif t.why ~= nil then
        return nil, "why is given though reason is " .. t.reason
    end
    return t
end
-- }}}

-- {{{ receipt.read
function receipt.read(path, folder)
    local f = io.open(path, "rb")
    if not f then return nil, "no receipt", "missing" end
    local text = f:read(receipt.MAX_BYTES + 1) or ""
    f:close()
    if #text > receipt.MAX_BYTES then return nil, "it is too big to be a receipt", "refused" end
    local t, why = run_data(text, path)
    if not t then return nil, why, "refused" end
    local r, why2 = receipt.check(t, folder)
    if not r then return nil, why2, "refused" end
    return r
end
-- }}}

-- {{{ receipt.describe
function receipt.describe(r)
    local fps = r.seconds > 0 and string.format(", %.0f a second", r.frames / r.seconds) or ""
    local ran = string.format("%.1f s, %d frames%s", r.seconds, r.frames, fps)
    if r.reason == "closed" then
        return "Test Map: the W client closed after " .. ran
    elseif r.reason == "lost-connection" then
        return "Test Map: the W client lost its connection to the server after " .. ran
    end
    return "Test Map: the W client stopped with an error after " .. ran .. ": " .. r.why
end
-- }}}

return receipt
