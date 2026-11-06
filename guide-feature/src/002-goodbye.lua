-- 002-goodbye.lua - how every guide-feature program keeps its run log and
-- leaves its goodbye receipt.
--
-- In plain terms: a program says hello when it starts and goodbye when it ends
-- cleanly. In between it keeps counts of its own work (turns run, canvases
-- blitted, words blanked) and writes what it does to a log in RAM. Its goodbye
-- is a small file, output/goodbye-<program>, with its name, when it ended, its
-- seed if it has one, and its counts, one `name: value` line each, so two runs
-- can be compared with diff. A crash writes no goodbye. So a goodbye that is
-- missing is the crash report: the old one is moved aside to
-- output/goodbye-<program>.previous as the program starts, where it stays to
-- compare against.
--
--   local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
--   local run = goodbye.start("blitter", { root = DIR, seed = 1234 })
--   run:log("watching tmp/shared-memory/arrivals/ by listing, once a second")
--   run:count("arrivals-taken")          -- one more
--   run:count("words-written", 7)        -- seven more
--   run:finish()                         -- the last act of a clean exit
--
--   goodbye.read(path)      -- a receipt back into a table, for comparing
--
-- The log is tmp/shared-memory/<program>.log, one line per call, each starting
-- with the UTC time. It is appended to, run after run, and every run starts
-- with a "started" line, so a log with a start and no "ended" after it is a run
-- that did not end cleanly. LuaJIT-compatible.

-- {{{ local DIR
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local M = {}

-- {{{ M.HEAD
-- The lines every receipt starts with, in this order, before its counts. A
-- counter may not take one of these names.
M.HEAD = { "program", "ended", "seed" }
local IS_HEAD = { program = true, ended = true, seed = true }
-- }}}

-- {{{ local NAME_PATTERN
-- The same name rule as settings (001), so a counter can be named after one.
local NAME_PATTERN = "^[%w%._%-]+$"
-- }}}

-- {{{ local function utc_now()
local function utc_now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end
-- }}}

-- {{{ local function is_whole()
local function is_whole(value)
    return type(value) == "number" and value == math.floor(value)
        and value > -math.huge and value < math.huge
end
-- }}}

-- {{{ function M.format()
-- A receipt { program, ended, seed, counters } as text: the head lines, then
-- the counters sorted by name. Counters are whole numbers of zero or more.
function M.format(receipt)
    if type(receipt.program) ~= "string" or not string.match(receipt.program, NAME_PATTERN) then
        error("goodbye: '" .. tostring(receipt.program) .. "' is not a program's name", 2)
    end
    local lines = { "program: " .. receipt.program, "ended: " .. receipt.ended }
    if receipt.seed ~= nil then
        if not is_whole(receipt.seed) then
            error("goodbye: the seed must be a whole number, not " .. tostring(receipt.seed), 2)
        end
        lines[#lines + 1] = string.format("seed: %d", receipt.seed)
    end

    local names = {}
    for name, value in pairs(receipt.counters or {}) do
        if type(name) ~= "string" or not string.match(name, NAME_PATTERN) or IS_HEAD[name] then
            error("goodbye: '" .. tostring(name) .. "' cannot be a counter's name", 2)
        end
        if not is_whole(value) or value < 0 then
            error("goodbye: the counter '" .. name .. "' must be a whole number of "
                .. "zero or more, not " .. tostring(value), 2)
        end
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        lines[#lines + 1] = string.format("%s: %d", name, receipt.counters[name])
    end
    return table.concat(lines, "\n") .. "\n"
end
-- }}}

-- {{{ function M.parse()
-- Receipt text back into { program, ended, seed, counters }. Refuses a line
-- that is not `name: value`, so a damaged receipt is noticed.
function M.parse(text, source)
    source = source or "goodbye"
    local receipt, line_number = { counters = {} }, 0
    for line in string.gmatch(text, "([^\n]*)\n") do
        line_number = line_number + 1
        local name, value = string.match(line, "^([%w%._%-]+): (.+)$")
        if not name then
            error(source .. ":" .. line_number .. ": not a `name: value` line: " .. line, 0)
        end
        if name == "program" or name == "ended" then
            receipt[name] = value
        elseif name == "seed" then
            receipt.seed = tonumber(value)
        else
            receipt.counters[name] = tonumber(value)
        end
    end
    return receipt
end
-- }}}

-- {{{ function M.read()
-- A receipt file into a table, or nil when there is none.
function M.read(path)
    local handle = io.open(path, "r")
    if not handle then
        return nil
    end
    local text = handle:read("*a")
    handle:close()
    return M.parse(text, path)
end
-- }}}

-- {{{ function M.path()
-- Where a program's receipt lives. One file per program, because the blitter,
-- the canvas server and the desktop viewers all run on kuvalu at once and one
-- shared output/goodbye would keep only whichever ended last.
function M.path(root, program)
    return (root or DIR) .. "/output/goodbye-" .. program
end
-- }}}

-- {{{ local Run
-- One running program: its name, root, seed, counters and open log.
local Run = {}
Run.__index = Run

-- {{{ function Run:log()
function Run:log(text)
    self.log_handle:write(self.clock(), " ", text, "\n")
    self.log_handle:flush()
end
-- }}}

-- {{{ function Run:count()
-- Adds `by` (one if left out) to a counter, starting it at zero.
function Run:count(name, by)
    by = by or 1
    if type(name) ~= "string" or not string.match(name, NAME_PATTERN) or IS_HEAD[name] then
        error("goodbye: '" .. tostring(name) .. "' cannot be a counter's name", 2)
    end
    if not is_whole(by) or by < 0 then
        error("goodbye: a counter only grows, by a whole number; not " .. tostring(by), 2)
    end
    self.counters[name] = (self.counters[name] or 0) + by
    return self.counters[name]
end
-- }}}

-- {{{ function Run:finish()
-- The last act of a clean exit. The receipt is written beside its final place
-- and then renamed onto it, so a crash half way through writing leaves no
-- receipt rather than a cut one. Returns the receipt's path.
function Run:finish()
    if self.finished then
        error("goodbye: " .. self.program .. " has already said goodbye", 2)
    end
    local text = M.format({ program = self.program, ended = self.clock(),
                            seed = self.seed, counters = self.counters })
    local final = M.path(self.root, self.program)
    local partial = final .. ".partial"
    local handle = assert(io.open(partial, "w"))
    handle:write(text)
    handle:close()
    assert(os.rename(partial, final))
    self:log("ended; goodbye written to output/goodbye-" .. self.program)
    self.log_handle:close()
    self.finished = true
    return final
end
-- }}}
-- }}}

-- {{{ function M.start()
-- The first act of every program, after its settings are read: makes sure of
-- the RAM tiers (for the log), moves the last receipt aside, opens the log.
-- opts: root, seed, clock (a function returning the time as text; tests only).
function M.start(program, opts)
    opts = opts or {}
    local root = opts.root or DIR
    if type(program) ~= "string" or not string.match(program, NAME_PATTERN) then
        error("goodbye: '" .. tostring(program) .. "' is not a program's name", 2)
    end
    if opts.seed ~= nil and not is_whole(opts.seed) then
        error("goodbye: the seed must be a whole number, not " .. tostring(opts.seed), 2)
    end

    local settings = dofile(root .. "/src/001-settings.lua")
    settings.ensure_tiers(root)

    local receipt = M.path(root, program)
    local old = io.open(receipt, "r")
    if old then
        old:close()
        os.remove(receipt .. ".previous")
        assert(os.rename(receipt, receipt .. ".previous"))
    end

    local log_path = root .. "/tmp/shared-memory/" .. program .. ".log"
    local run = setmetatable({
        program = program, root = root, seed = opts.seed, counters = {},
        clock = opts.clock or utc_now, log_path = log_path,
        log_handle = assert(io.open(log_path, "a")),
    }, Run)
    run:log("started" .. (opts.seed and (" with seed " .. opts.seed) or ""))
    return run
end
-- }}}

return M
