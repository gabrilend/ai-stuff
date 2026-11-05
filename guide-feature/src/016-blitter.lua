#!/usr/bin/env luajit
-- 016-blitter.lua - the blitter: the long-running program on kuvalu that
-- takes the voices' edited canvases and writes them onto the shared canvas.
--
-- In plain terms: each voice's edit arrives as a file in
-- tmp/shared-memory/arrivals/. The blitter takes them one at a time, oldest
-- first. It reads each (102), checks who sent it and that it is the size of
-- the version it started from (105), finds what that voice changed (104), and
-- writes those changes onto the shared canvas (106). When the canvas changed,
-- that is the next version, and it is handed to every publisher. An arrival
-- that fails a check is moved to arrivals-refused/ with a log line saying
-- why; nothing is dropped silently. With no network yet, the files are
-- dropped in by hand or by a script. Each version is written to
-- tmp/shared-memory/canvas/current and canvas/history/NNNNNN (203), where
-- the viewers read it and where the blitter finds each voice's base, and the
-- one publisher so far writes it to the log.
--
--   luajit src/016-blitter.lua [--dir ROOT]     run until a clean stop
--   scripts/run-blitter [ROOT]                  the same, with Ctrl-C or a
--                                               TERM signal as a clean stop
--
-- A clean stop is a file named `stop` in the arrivals folder: the blitter
-- finishes the arrivals before it, removes it, writes its goodbye receipt
-- (output/goodbye-blitter) and exits.
--
-- As a library (the tests, the phase-1 demo):
--   local blitter = dofile(DIR .. "/src/016-blitter.lua")
--   local b = blitter.new({ root = ROOT })
--   b:step()            -- takes every arrival waiting; true once told to stop
--   b.version, b.current, b.run.counters
--   b.history[n]        -- version n, read back from its history file
--   b:finish()
--
-- LuaJIT-compatible.

-- {{{ local DIR
-- Sibling files are found next to this one (as in 006).
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local settings = dofile(DIR .. "/src/001-settings.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local changes = dofile(DIR .. "/src/010-changes.lua")
local fit = dofile(DIR .. "/src/012-fit-check.lua")
local blit = dofile(DIR .. "/src/014-blit.lua")
local marks = dofile(DIR .. "/src/020-marks.lua")

local M = {}

-- {{{ M.SETTINGS
-- input/blitter. merge-mode and collision-rule are read again on every
-- arrival, so they can be changed while it runs; the size is fixed at start
-- (resizing is issue 205). mark-lifetime, in versions, is how long a mark
-- stays (201): a mark is dropped once its age is over it.
local function rule_names()
    local names = {}
    for name in pairs(blit.RULES) do names[#names + 1] = name end
    table.sort(names)
    return names
end
M.SETTINGS = {
    ["canvas-size"]    = { type = "WxH", required = true },
    ["merge-mode"]     = { type = "choice", of = { "newest", "distill" }, required = true },
    ["collision-rule"] = { type = "choice", of = rule_names(), required = true },
    ["mark-lifetime"]  = { type = "whole", required = true },
    -- the viewers' headers (docs/canvas-protocol.md): the project's name, and
    -- the voices in the order viewers give them colours
    ["project"]        = { type = "text", required = true },
    ["voices"]         = { type = "names", required = true },
}
-- }}}

-- {{{ M.MODES
-- The merge modes: a table from mode name to a function that takes the
-- blitter, the arrived voice canvas and its base, and returns the new canvas
-- and the blit's report. `distill` (601) is added here when it is built; until
-- then an arrival in that mode is refused, never quietly blitted.
M.MODES = {
    newest = function(self, voice, base)
        local found = changes.find(base, voice)
        return blit.apply(self.current, found, self.settings["collision-rule"])
    end,
}
-- }}}

-- {{{ M.log_publisher()
-- Phase 1's only publisher: each new version, row by row, in the log.
-- Files (203) and rmail (303) are added to the list later, each a
-- function(blitter, record, report). Marks (201) are made before any
-- publisher runs, so every publisher is handed the version with its marks.
function M.log_publisher(self, record)
    self.run:log("version " .. record.headers.canvas .. ":")
    for _, row in ipairs(record.rows) do
        self.run:log("| " .. string.gsub(row, " +$", ""))
    end
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. string.gsub(text, "'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function list_folder()
-- The plain file names in a folder, through ls; LuaJIT has no directory
-- listing of its own.
local function list_folder(path)
    local names = {}
    local pipe = io.popen("ls -1A " .. shell_quote(path) .. " 2>/dev/null")
    for name in pipe:lines() do names[#names + 1] = name end
    pipe:close()
    return names
end
-- }}}

-- {{{ function M.arrival_name()
-- An arrival's name, `<sender>-<unix time>-<random>` (issue 302), as its
-- parts, or nil. The sender may itself hold dashes (fg-sora-1).
function M.arrival_name(name)
    local sender, time, random = string.match(name, "^([%w%._%-]+)%-(%d+)%-(%w+)$")
    if not sender then
        return nil
    end
    return { sender = sender, time = tonumber(time), random = random }
end
-- }}}

-- {{{ function M.pending()
-- The arrivals waiting, oldest first: by the time in their names, then by
-- name. Names starting with "." are files still being written, and `stop` is
-- the stop file; neither is an arrival. Returns the names, and whether the
-- stop file is there.
function M.pending(folder)
    local arrivals, stop = {}, false
    for _, name in ipairs(list_folder(folder)) do
        if name == "stop" then
            stop = true
        elseif string.sub(name, 1, 1) ~= "." then
            arrivals[#arrivals + 1] = name
        end
    end
    local function time_of(name)
        local parts = M.arrival_name(name)
        return parts and parts.time or -1
    end
    table.sort(arrivals, function(a, b)
        local ta, tb = time_of(a), time_of(b)
        if ta ~= tb then return ta < tb end
        return a < b
    end)
    return arrivals, stop
end
-- }}}

-- {{{ local Blitter
local Blitter = {}
Blitter.__index = Blitter

-- {{{ function Blitter:refuse()
-- Moves an arrival to arrivals-refused/, logs the reason and counts it.
function Blitter:refuse(name, reason, detail)
    os.rename(self.arrivals .. "/" .. name, self.refused .. "/" .. name)
    self.run:count("refused-" .. reason)
    self.run:log("refused " .. name .. " (" .. reason .. "): " .. detail)
    return reason
end
-- }}}

-- {{{ function Blitter:reread()
-- The settings again, on every arrival. A file that no longer reads keeps the
-- last good settings, with the error in the log: an edit with a typo must not
-- stop the canvas.
function Blitter:reread()
    local ok, values = pcall(settings.read, "blitter", M.SETTINGS, { root = self.root })
    if not ok then
        self.run:log("input/blitter did not read; keeping the last good settings: " .. values)
        self.run:count("settings-not-read")
        return
    end
    for _, name in ipairs({ "merge-mode", "collision-rule", "mark-lifetime" }) do
        if values[name] ~= self.settings[name] then
            self.run:log(name .. " is now " .. tostring(values[name]))
        end
    end
    local size = values["canvas-size"]
    if size.width ~= self.current.width or size.height ~= self.current.height then
        self.run:log("canvas-size changed in input/blitter; it takes effect at the next start")
    end
    self.settings = values
end
-- }}}

-- {{{ function Blitter:take()
-- One arrival, start to end. Returns "blitted", "unchanged", or the reason it
-- was refused.
function Blitter:take(name)
    self.run:count("arrivals-taken")
    local parts = M.arrival_name(name)
    if not parts then
        return self:refuse(name, "bad-name", "an arrival is named <sender>-<unix time>-<random>")
    end

    local handle = io.open(self.arrivals .. "/" .. name, "r")
    local text = handle and handle:read("*a")
    if handle then handle:close() end
    local ok, voice = pcall(canvas.read, text or "", "from-voice", name)
    if not ok then
        return self:refuse(name, "unreadable", voice)
    end
    if voice.headers.voice ~= parts.sender then
        return self:refuse(name, "wrong-sender", "sent by " .. parts.sender
            .. ", but its voice: header says " .. voice.headers.voice)
    end

    local last = self.last_turn[parts.sender]
    if last and voice.headers.turn <= last then
        return self:refuse(name, "turn-not-newer", "turn " .. voice.headers.turn
            .. " after turn " .. last .. " from " .. parts.sender)
    end

    local base = self.history[voice.headers.base]
    if not base then
        return self:refuse(name, "base-not-in-history", "base " .. voice.headers.base
            .. " is not in the history (versions " .. self.first_version .. " to "
            .. self.version .. ")")
    end
    local problems = fit.arrival(voice, base)
    if #problems > 0 then
        local lines = {}
        for _, problem in ipairs(problems) do lines[#lines + 1] = fit.LINES[problem.kind](problem) end
        return self:refuse(name, "wrong-size", table.concat(lines, "; "))
    end

    self:reread()
    local mode = M.MODES[self.settings["merge-mode"]]
    if not mode then
        return self:refuse(name, "mode-not-built", "merge mode "
            .. self.settings["merge-mode"] .. " is not built yet")
    end

    -- {{{ accepted: blit it
    if last and voice.headers.turn > last + 1 then
        self.run:count("turns-skipped", voice.headers.turn - last - 1)
    end
    self.last_turn[parts.sender] = voice.headers.turn
    if voice.ignored_marks > 0 then
        self.run:count("voice-marks-ignored", voice.ignored_marks)
    end

    local new, report = mode(self, voice, base)
    for counter, value in pairs(report.counts) do
        self.run:count(counter, value)
    end
    os.remove(self.arrivals .. "/" .. name)
    self.reports[#self.reports + 1] = { name = name, voice = parts.sender, report = report }

    local summary = string.format("%s: turn %d on base %d, %d written, %d removed, "
        .. "%d conflicts, %d cut", name, voice.headers.turn, voice.headers.base,
        report.counts["words-written"], report.counts["removals-applied"],
        report.counts["conflicts"], #report.cut)
    if not report.changed then
        self.run:count("unchanged-turns")
        self.run:log(summary .. "; nothing changed")
        return "unchanged"
    end
    self.run:count("versions-made")
    self:publish(new, report, summary, parts.sender)
    return "blitted"
    -- }}}
end
-- }}}

-- {{{ function Blitter:publish()
-- The next version: marked (201), kept in the history and handed to every
-- publisher. `voice` is whose blit it is; version 1 has neither a report nor
-- a voice, and no marks.
function Blitter:publish(new, report, summary, voice)
    self.version = self.version + 1
    new.set = "for-viewers"
    new.headers = { canvas = self.version, size = { width = new.width, height = new.height },
                    mode = self.settings["merge-mode"],
                    project = { name = self.settings["project"], commit = self.commit },
                    written = self.run.clock(), voices = self.settings["voices"] }
    local marked
    if report then
        marked = marks.mark(self.current, new, report, voice, self.version,
            self.settings["mark-lifetime"])
        new.marks = marked.marks
        self.run:count("cells-marked-word", marked.counts.word)
        self.run:count("cells-marked-sentence", marked.counts.sentence)
        self.run:count("marks-expired", marked.counts.expired)
        -- No collision rule built yet leaves fragments to fade, so there are
        -- no orphans; fade-fragments brings their blanking with it.
        assert(#marked.expired_orphans == 0, "orphan marks expired, but nothing blanks them yet")
    else
        new.marks = {}
    end
    self.current = new
    self:write_files(new)
    self.run:log(summary .. "; now version " .. self.version)
    if marked then
        self.run:log(string.format("marks: %d cells word, %d cells sentence, %d expired, "
            .. "%d runs", marked.counts.word, marked.counts.sentence, marked.counts.expired,
            #marked.marks))
    end
    for _, publisher in ipairs(self.publishers) do
        publisher(self, new, report, voice)
    end
end
-- }}}

-- {{{ function Blitter:step()
-- Takes every arrival waiting, oldest first. Returns true when the stop file
-- was there: the arrivals listed with it are taken first, then it is removed.
function Blitter:step()
    local names, stop = M.pending(self.arrivals)
    for _, name in ipairs(names) do
        self:take(name)
    end
    if stop then
        os.remove(self.arrivals .. "/stop")
        self.run:log("stop file found")
    end
    return stop
end
-- }}}

-- {{{ function Blitter:finish()
function Blitter:finish()
    self.run:count("versions-in-history", self.version - self.first_version + 1)
    return self.run:finish()
end
-- }}}
-- }}}

-- {{{ function Blitter:write_files()
-- A version as viewers read it (docs/canvas-protocol.md, "On kuvalu: files"):
-- history/NNNNNN, never rewritten, then `current`, replaced whole by rename,
-- so a reader never sees half a canvas. Both are the same text, byte for
-- byte. Made in publish itself, not by a publisher, because the blitter
-- reads its bases back from the history. The version's number is also kept
-- on disk, in output/blitter-version.
function Blitter:write_files(record)
    local text = canvas.write(record, "for-viewers")
    local name = string.format("%06d", record.headers.canvas)
    local history = self.canvas_folder .. "/history/" .. name
    local existing = io.open(history, "r")
    if existing then
        existing:close()
        error("blitter: history/" .. name .. " is already there; history is never rewritten")
    end
    for _, place in ipairs({ { history, self.canvas_folder .. "/history/." .. name },
                             { self.canvas_folder .. "/current",
                               self.canvas_folder .. "/.current" } }) do
        local handle = assert(io.open(place[2], "w"))
        handle:write(text)
        handle:close()
        assert(os.rename(place[2], place[1]))
    end
    -- the number alone goes to disk, so a run after a reboot numbers on
    local number = self.root .. "/output/blitter-version"
    local handle = assert(io.open(number .. ".partial", "w"))
    handle:write(record.headers.canvas, "\n")
    handle:close()
    assert(os.rename(number .. ".partial", number))
end
-- }}}

-- {{{ local function history_reader()
-- b.history[n]: version n read back from its history file, or nil. Nothing
-- but the current version is held in memory.
local function history_reader(folder)
    return setmetatable({}, { __index = function(_, number)
        if type(number) ~= "number" then return nil end
        local handle = io.open(string.format("%s/history/%06d", folder, number), "r")
        if not handle then return nil end
        local text = handle:read("*a")
        handle:close()
        return canvas.read(text, "for-viewers", string.format("history/%06d", number))
    end })
end
-- }}}

-- {{{ local function previous_version()
-- The last version number any earlier run made: the larger of the one in
-- the previous run's `current` (RAM) and the one in output/blitter-version
-- (disk, so it outlives a reboot that empties the RAM), or 0. The new run
-- numbers on from it, so no version number is ever used twice.
local function number_in(path, pattern)
    local handle = io.open(path, "r")
    if not handle then return 0 end
    local first = handle:read("*l")
    handle:close()
    return tonumber(string.match(first or "", pattern)) or 0
end
local function previous_version(canvas_folder, root)
    return math.max(number_in(canvas_folder .. "/current", "^canvas: (%d+)$"),
                    number_in(root .. "/output/blitter-version", "^(%d+)$"))
end
-- }}}

-- {{{ local function project_commit()
-- The commit the project is at, for the `project:` header; nil when the root
-- is not a git checkout.
local function project_commit(root)
    local pipe = io.popen("git -C " .. shell_quote(root) .. " rev-parse --short=7 HEAD 2>/dev/null")
    local commit = pipe:read("*l")
    pipe:close()
    return commit and string.match(commit, "^%x+$") and commit or nil
end
-- }}}

-- {{{ local function sleep_ms()
-- Waits without a busy loop, through poll(2): LuaJIT has no sleep of its own.
local ffi = require("ffi")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
local function sleep_ms(ms)
    ffi.C.poll(nil, 0, ms)
end
-- }}}

-- {{{ function M.new()
-- A blitter on a project root: its settings read, its run started, its folders
-- made, the canvas folder emptied of the previous run, and the first
-- version, an empty canvas, in the history and published. The first version
-- is 1, or one more than any earlier run's last (even across a reboot, from
-- output/blitter-version), so a voice's base from before a restart is never
-- mistaken for a new version: it is refused, as not in the history.
-- opts: root, clock (tests), publishers (default: the log), wait (a function
-- called between steps; default: the once-a-second listing), commit (the
-- project's commit for the viewers' header; default: git's, in the root).
function M.new(opts)
    opts = opts or {}
    local root = opts.root or DIR
    local values = settings.read("blitter", M.SETTINGS, { root = root })
    local run = goodbye.start("blitter", { root = root, clock = opts.clock })
    local self = setmetatable({
        root = root, run = run, settings = values,
        arrivals = root .. "/tmp/shared-memory/arrivals",
        refused = root .. "/tmp/shared-memory/arrivals-refused",
        canvas_folder = root .. "/tmp/shared-memory/canvas",
        publishers = opts.publishers or { M.log_publisher },
        last_turn = {}, reports = {},
    }, Blitter)
    os.execute("mkdir -p " .. shell_quote(self.arrivals) .. " " .. shell_quote(self.refused))

    -- the previous run's canvas folder: its last number kept, the rest gone
    self.version = previous_version(self.canvas_folder, root)
    self.first_version = self.version + 1
    os.execute("rm -rf " .. shell_quote(self.canvas_folder) .. " && mkdir -p "
        .. shell_quote(self.canvas_folder .. "/history"))
    self.history = history_reader(self.canvas_folder)
    if self.version > 0 then
        run:log("the previous run ended at version " .. self.version
            .. "; its canvas files are removed, and this run starts at version "
            .. self.first_version)
    end
    self.commit = opts.commit or project_commit(root)
    if not self.commit then
        self.commit = "0000000"
        run:log("the project is not a git checkout, so its commit is written as 0000000")
    end

    self.wait = opts.wait or function() sleep_ms(1000) end
    run:log(opts.wait and "waiting for arrivals as the caller says"
        or "waiting for arrivals by listing the folder once a second "
        .. "(no inotify binding in this project)")
    run:log(string.format("canvas %dx%d, merge mode %s, collision rule %s, marks last %d versions",
        values["canvas-size"].width, values["canvas-size"].height, values["merge-mode"],
        values["collision-rule"], values["mark-lifetime"]))

    local first = canvas.blank(values["canvas-size"].width, values["canvas-size"].height)
    self.current = first
    self:publish(first, nil, "started from an empty canvas")
    return self
end
-- }}}

-- {{{ function M.main()
-- Runs until a clean stop, then writes the goodbye.
function M.main(opts)
    local self = M.new(opts)
    while not self:step() do
        self.wait()
    end
    return self:finish()
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "016%-blitter%.lua$") then
    local root = DIR
    for index = 1, #arg do
        if arg[index] == "--dir" then root = arg[index + 1] end
    end
    -- the publishers: the log, and the voices' living message (303), as
    -- input/to-voices says
    local to_voices = dofile(DIR .. "/src/035-to-voices.lua")
    local voices = settings.read("blitter", M.SETTINGS, { root = root }).voices
    local mailer, why_not = to_voices.publisher({ root = root, voices = voices })
    local publishers = { M.log_publisher }
    if mailer then
        publishers[#publishers + 1] = mailer
    else
        publishers[#publishers + 1] = function(self, record)
            if record.headers.canvas == self.first_version then self.run:log(why_not) end
        end
    end
    M.main({ root = root, publishers = publishers })
end
-- }}}

return M
