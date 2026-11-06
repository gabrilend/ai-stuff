-- 002-goodbye.lua - the receipt every program leaves on a clean exit, and the
-- run log beside it.
--
-- In plain terms: while a program works it keeps a tally (requests carried,
-- entries written, visits made). When it finishes cleanly it writes that
-- tally to output/goodbye, with the time it ended and the seed it ran from.
-- A crash never reaches this point, so a missing or old receipt is itself
-- the crash report, and a fresh one proves the program ended and says what it
-- did. Longer detail goes in a run log in the project's RAM scratch space,
-- tmp/shared-memory/<program>.log (docs/settings-files.md).
--
-- Both receipt files are written under a temporary name and renamed into
-- place, because a rename within one folder is all-or-nothing: a reader sees
-- the old receipt or the new one, never half of one.

local M = {}

-- {{{ local function utc_now()
local function utc_now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end
-- }}}

-- {{{ local function write_whole()
-- Writes text to a temporary name beside the target, then renames it over
-- the target. Any failure is raised, never ignored: a receipt that silently
-- failed to write would look exactly like a crash.
local function write_whole(path, text)
    local temporary = path .. ".writing"
    local file, open_error = io.open(temporary, "w")
    if file == nil then
        error("goodbye: cannot write " .. temporary .. " (" .. tostring(open_error) .. ")", 0)
    end
    file:write(text)
    file:close()
    local renamed, rename_error = os.rename(temporary, path)
    if not renamed then
        error("goodbye: cannot rename into " .. path .. " (" .. tostring(rename_error) .. ")", 0)
    end
end
-- }}}

-- {{{ local SCRIPTS_DIR
-- The monorepo's scripts folder, found from where this file sits
-- (<monorepo>/distant-computer/src/002-goodbye.lua), not from a hard-coded
-- path: the distant computer's clone lives at a different path from
-- kuvalu's, and the receipt must work on both.
local SCRIPTS_DIR = string.match(debug.getinfo(1, "S").source, "^@(.*)/[^/]+/src/[^/]+$")
    .. "/scripts"
-- }}}

-- {{{ local function ensure_ram_tiers()
-- The run log lives in RAM, which a reboot empties, so the scratch folders
-- are rebuilt before the first write. The rebuilding is the house library's
-- job; it is reached through the monorepo's scripts folder, which sits beside
-- this project on both computers (the distant one holds a full clone), so no
-- copy of the library is kept here to drift from the original. Tests point
-- the library's roots elsewhere with EXEC_TIER_ROOT and ARTIFACT_TIER_ROOT.
local function ensure_ram_tiers(project_dir)
    local tiers = dofile(SCRIPTS_DIR .. "/libs/ensure-ram-tiers.lua")
    tiers.ensure(project_dir, SCRIPTS_DIR)
end
-- }}}

-- {{{ function M.start()
-- Begins a run. Returns a receipt: a table holding the program's name, its
-- seed, its counters and its open run log, with the methods below.
--
-- seed: text or a number. A program that uses no randomness passes "none"
-- in so, deliberately; there is no default, so forgetting is an error.
function M.start(project_dir, program, seed)
    if type(program) ~= "string" or not string.match(program, "^[%w%-_]+$") then
        error("goodbye: the program name must be a single word, got " .. tostring(program), 2)
    end
    if type(seed) ~= "string" and type(seed) ~= "number" then
        error("goodbye: say the seed, or \"none\"; got " .. type(seed), 2)
    end
    ensure_ram_tiers(project_dir)
    local log_path = project_dir .. "/tmp/shared-memory/" .. program .. ".log"
    local log, log_error = io.open(log_path, "a")
    if log == nil then
        error("goodbye: cannot open the run log " .. log_path .. " (" .. tostring(log_error) .. ")", 2)
    end
    local receipt = {
        project_dir = project_dir,   -- string: the project folder
        program = program,           -- string: one word, names the files
        seed = tostring(seed),       -- string: as written in the receipt
        counters = {},               -- table: counter name -> whole number
        log = log,                   -- file handle: the run log, appended to
        log_path = log_path,         -- string
    }
    log:write(utc_now(), " start ", program, " seed ", receipt.seed, "\n")
    log:flush()
    return setmetatable(receipt, { __index = M })
end
-- }}}

-- {{{ function M:count()
-- Adds to a counter (by 1 when no amount is given). Counters are whole
-- numbers; the receipt is for counts, and a fraction would be a measurement
-- that belongs in the log.
function M:count(name, amount)
    amount = amount or 1
    if amount ~= math.floor(amount) then
        error("goodbye: counter '" .. name .. "' must change by a whole number", 2)
    end
    self.counters[name] = (self.counters[name] or 0) + amount
end
-- }}}

-- {{{ function M:set()
-- Sets a counter outright, for totals known only at the end.
function M:set(name, value)
    if value ~= math.floor(value) then
        error("goodbye: counter '" .. name .. "' must be a whole number", 2)
    end
    self.counters[name] = value
end
-- }}}

-- {{{ function M:note()
-- One line in the run log, stamped with the time.
function M:note(text)
    self.log:write(utc_now(), " ", text, "\n")
    self.log:flush()
end
-- }}}

-- {{{ function M:text()
-- The receipt as text: program, ended, seed, then counters sorted by name, so
-- two receipts compare line for line with diff.
function M:text(ended)
    local lines = {
        "program: " .. self.program,
        "ended: " .. ended,
        "seed: " .. self.seed,
    }
    local names = {}
    for name in pairs(self.counters) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        lines[#lines + 1] = name .. ": " .. string.format("%d", self.counters[name])
    end
    return table.concat(lines, "\n") .. "\n"
end
-- }}}

-- {{{ function M:finish()
-- Writes output/goodbye.<program> and output/goodbye, closes the log. The
-- last thing a program does. Returns the receipt's text.
function M:finish()
    local text = self:text(utc_now())
    local output_dir = self.project_dir .. "/output"
    write_whole(output_dir .. "/goodbye." .. self.program, text)
    write_whole(output_dir .. "/goodbye", text)
    self:note("goodbye")
    self.log:close()
    return text
end
-- }}}

-- {{{ function M.read()
-- Reads a receipt back into { program, ended, seed, counters = {...} }, so
-- tests and demos can check what a run did.
function M.read(path)
    local file, open_error = io.open(path, "r")
    if file == nil then
        error("goodbye: no receipt at " .. path .. " (" .. tostring(open_error) .. ")", 2)
    end
    local receipt = { counters = {} }
    for line in file:lines() do
        local name, value = string.match(line, "^([%w%-_]+): (.*)$")
        if name == "program" or name == "ended" or name == "seed" then
            receipt[name] = value
        elseif name ~= nil then
            receipt.counters[name] = tonumber(value)
        end
    end
    file:close()
    return receipt
end
-- }}}

return M
