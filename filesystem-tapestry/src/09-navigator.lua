-- 09-navigator.lua — stand on a file and walk. next, previous, open.
--
-- General description: the front door of the viewing half. It holds a cursor -- a
-- position in whichever walk is active -- and takes plain words: `next` and
-- `previous` step the cursor, `open` hands the file under it to the right
-- program (a movie to mpv, text to neovim, an image to feh, a document to
-- zathura), and `chronological` / `similar` / `different` switch which walk you
-- are on. Every command is a row in a table that maps a word to a small function;
-- there is no ladder of if/else deciding what a word means.
--
-- This is a module. The entry script (10-main.lua) reads input/ first, hands the
-- catalog here, and writes output/ goodbye last -- so this file stays about the
-- walk and nothing else.

local DIR = DIR or "/home/ritz/programming/ai-stuff/filesystem-tapestry"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/libs/?.lua;" .. package.path
local utils    = require("01-utils")
local ordering = require("05-ordering-engine")
local dispatch = require("08-media-dispatch")

local M = {}
local Navigator = {}
Navigator.__index = Navigator

-- {{{ small formatting helpers
local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function human_size(n)
    local units = { "B", "KB", "MB", "GB", "TB" }
    local x, i = n, 1
    while x >= 1024 and i < #units do x = x / 1024; i = i + 1 end
    return string.format("%.1f%s", x, units[i])
end

local function human_time(ts)
    return os.date("%Y-%m-%d %H:%M", ts)
end
-- }}}

-- {{{ Navigator.new
function Navigator.new(records, config, startup)
    startup = startup or {}
    local self = setmetatable({}, Navigator)
    self.records = records
    self.config  = config
    self.mode      = startup.mode      or "chronological"
    self.field     = startup.field     or config.chronology.field
    self.direction = startup.direction or config.chronology.direction
    self.cursor    = 1
    self:rebuild()
    return self
end
-- }}}

-- {{{ Navigator:rebuild
-- Recompute the active ordering, trying to keep the cursor on the same file it
-- was standing on so switching walks does not lose your place.
function Navigator:rebuild()
    local anchor = self:current_index()
    self.ordering = ordering.build(self.records, self.mode, {
        field = self.field,
        direction = self.direction,
        seed = anchor,
        include_excluded = false,   -- browse walk skips junk-dir files
    })
    -- Re-find the anchored file in the new ordering.
    self.cursor = 1
    if anchor then
        for pos, cat_i in ipairs(self.ordering) do
            if cat_i == anchor then self.cursor = pos; break end
        end
    end
end
-- }}}

-- {{{ Navigator:current_index / current_record
function Navigator:current_index()
    return self.ordering and self.ordering[self.cursor] or nil
end

function Navigator:current_record()
    local i = self:current_index()
    return i and self.records[i] or nil
end
-- }}}

-- {{{ Navigator:move
-- Step the cursor. Excluded files are already absent from the ordering, so a
-- step is just +/-1, clamped at the ends with a spoken edge.
function Navigator:move(delta)
    if #self.ordering == 0 then print("(the walk is empty)"); return end
    local target = self.cursor + delta
    if target < 1 then print("(start of the walk)"); target = 1 end
    if target > #self.ordering then
        print("(end of the walk)"); target = #self.ordering
    end
    self.cursor = target
    self:where()
end
-- }}}

-- {{{ Navigator:where
function Navigator:where()
    local rec = self:current_record()
    if not rec then print("(nothing here)"); return end
    print(string.format("[%d/%d] %s", self.cursor, #self.ordering, rec.path))
    print(string.format("   created  %s%s", human_time(rec.created),
        rec.created_is_fallback and "  (fallback: birth time unknown)" or ""))
    print(string.format("   modified %s", human_time(rec.modified)))
    print(string.format("   kind %-6s size %-9s  walk: %s by %s (%s)",
        rec.kind, human_size(rec.size), self.mode, self.field, self.direction))
end
-- }}}

-- {{{ Navigator:open
-- Hand the current file to the program its kind maps to. An unknown kind has no
-- viewer, so we fall back to xdg-open and SAY we fell back. Terminal programs
-- (neovim) run in the foreground; windowed programs detach, with their chatter
-- sent to a RAM log so nothing is hidden yet the prompt stays usable.
function Navigator:open()
    local rec = self:current_record()
    if not rec then print("(nothing to open)"); return end
    local viewer = dispatch.viewer_for(rec.kind)
    if not viewer then
        utils.log_warn("no viewer for kind '" .. rec.kind
            .. "' -- FALLBACK to xdg-open")
        viewer = { program = "xdg-open", args = {}, terminal = false }
    end
    local parts = { viewer.program }
    for _, a in ipairs(viewer.args) do parts[#parts + 1] = shell_quote(a) end
    parts[#parts + 1] = shell_quote(rec.path)
    local cmd = table.concat(parts, " ")

    if viewer.terminal then
        print("opening in " .. viewer.program .. " ...")
        os.execute(cmd)
    else
        local logp = self.config.paths.tmp .. "/viewer.log"
        os.execute(cmd .. " >> " .. shell_quote(logp) .. " 2>&1 &")
        print("opened " .. viewer.program .. "  ->  " .. rec.path)
    end
end
-- }}}

-- {{{ Navigator:set_mode / set_field / reverse
function Navigator:set_mode(mode)
    self.mode = mode
    self:rebuild()
    print("walk: " .. mode)
    self:where()
end

function Navigator:set_field(field)
    self.field = field
    if self.mode == "chronological" then self:rebuild() end
    print("date field: " .. field)
    self:where()
end

function Navigator:reverse()
    self.direction = (self.direction == "asc") and "desc" or "asc"
    if self.mode == "chronological" then self:rebuild() end
    print("direction: " .. self.direction)
    self:where()
end
-- }}}

-- {{{ Navigator:list
-- Show a small window of the walk around the cursor for orientation.
function Navigator:list()
    local lo = math.max(1, self.cursor - 4)
    local hi = math.min(#self.ordering, self.cursor + 4)
    for pos = lo, hi do
        local rec = self.records[self.ordering[pos]]
        local marker = (pos == self.cursor) and "->" or "  "
        print(string.format("%s [%d] %s  %s", marker, pos,
            human_time(rec[self.field]), utils.basename(rec.path)))
    end
end
-- }}}

-- {{{ COMMANDS dispatch table
-- word -> function(nav). Aliases share a handler. This is the whole grammar of
-- the walk; a new command is a new row.
local COMMANDS = {
    ["next"] = function(n) n:move(1) end,
    ["n"]    = function(n) n:move(1) end,
    ["previous"] = function(n) n:move(-1) end,
    ["prev"] = function(n) n:move(-1) end,
    ["p"]    = function(n) n:move(-1) end,
    ["open"] = function(n) n:open() end,
    ["o"]    = function(n) n:open() end,
    ["chronological"] = function(n) n:set_mode("chronological") end,
    ["chrono"] = function(n) n:set_mode("chronological") end,
    ["similar"] = function(n) n:set_mode("similar") end,
    ["different"] = function(n) n:set_mode("different") end,
    ["created"]  = function(n) n:set_field("created") end,
    ["modified"] = function(n) n:set_field("modified") end,
    ["reverse"] = function(n) n:reverse() end,
    ["where"] = function(n) n:where() end,
    ["w"]     = function(n) n:where() end,
    ["list"]  = function(n) n:list() end,
    ["l"]     = function(n) n:list() end,
    ["help"]  = function(n) n:help() end,
    ["h"]     = function(n) n:help() end,
    ["?"]     = function(n) n:help() end,
}
-- }}}

-- {{{ Navigator:help
function Navigator:help()
    print([[
commands:
  next / n            step forward along the walk
  previous / prev / p step backward
  open / o            open the current file (mpv / nvim / feh / zathura)
  where / w           show the current file and dates
  list / l            show a few files around the cursor
  chronological       walk by time
  similar             walk by nearest meaning        (Phase 2; falls back)
  different           walk by greatest difference    (Phase 2; falls back)
  created / modified  which date time sorts on
  reverse             flip oldest-first / newest-first
  help / h / ?        this list
  quit / q            leave (writes output/ goodbye)]])
end
-- }}}

-- {{{ M.run
-- The read-a-word, do-a-thing loop. Returns where the walk ended so the entry
-- script can record it in output/ goodbye.
function M.run(records, config, startup)
    local nav = Navigator.new(records, config, startup)
    print(string.format("filesystem tapestry -- %d files in the walk (%s)",
        #nav.ordering, nav.mode))
    nav:where()
    print("type 'help' for commands, 'quit' to leave.")
    while true do
        io.write("\ntapestry> ")
        io.flush()
        local line = io.read("*l")
        if line == nil then break end            -- EOF (piped input ended)
        local word = line:match("^%s*(%S+)")
        if word == "quit" or word == "q" or word == "exit" then
            break
        elseif word == nil then
            -- empty line: a gentle nudge forward, like turning a page
            nav:move(1)
        else
            local handler = COMMANDS[word:lower()]
            if handler then handler(nav)
            else print("unknown command: " .. word .. "  (try 'help')") end
        end
    end
    local rec = nav:current_record()
    return {
        mode = nav.mode,
        cursor = nav.cursor,
        total = #nav.ordering,
        path = rec and rec.path or "(none)",
    }
end
-- }}}

M.Navigator = Navigator
return M
