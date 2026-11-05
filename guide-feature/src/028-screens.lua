-- 028-screens.lua - one canvas for each screen: which canvases to make, in
-- what order, and what each screen shows meanwhile.
--
-- In plain terms: the owner wants the canvas to fit every screen being
-- watched, without ever cropping words by moving an edge: "we could have one
-- output for each screen currently watching." So no canvas is resized;
-- instead the same context (the subject the voices paint) is painted once
-- for each screen, "with two separate brushsizes on two separate papers".
-- There are three ways to do that, a setting, one at a time (issue 205):
--
--   round          one canvas per watched screen, one after another,
--                  largest first; the context may not change until every
--                  screen has been refreshed (the default)
--   asynchronous   one canvas per watched screen, all at once, each on its
--                  own endpoint
--   smallest       one canvas, at the smallest watched size; bigger screens
--                  draw it centred, its letters enlarged up to a maximum
--                  (the viewer's work: viewer.layout, 022)
--
--   local screens = dofile(DIR .. "/src/028-screens.lua")
--   local watched = screens.watched(list)        -- watched, largest first
--   screens.canvases("round", watched)           -- the canvases to make
--   screens.plan("round", watched, voices)       -- the turns, in batches
--   local keeper = screens.keeper({ mode = function() return mode end })
--   local batch = keeper:context(ctx, list)      -- a context change
--   batch = keeper:batch_done()                  -- the next batch, or nil
--   screens.display(screen, mode, made)          -- what a screen shows
--   screens.read_mode(root)                      -- input/screens
--
-- What it does not do yet, behind these seams: run the turns (405), keep a
-- blitter and canvas files for each screen's canvas, hear the screens from
-- the display programs (801-803, 901-902), and give each asynchronous turn
-- its own endpoint (402). LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local settings = dofile(DIR .. "/src/001-settings.lua")

local M = {}

M.MODES = { "round", "asynchronous", "smallest" }
M.SETTINGS = {
    ["screen-mode"] = { type = "choice", of = M.MODES, required = true },
}
M.SMALLEST = "smallest"   -- the name of the one canvas in smallest mode

-- {{{ function M.read_mode()
-- The screen mode from input/screens; read again on every context change.
function M.read_mode(root)
    return settings.read("screens", M.SETTINGS, { root = root })["screen-mode"]
end
-- }}}

-- {{{ local function is_mode()
local function check_mode(mode, level)
    for _, known in ipairs(M.MODES) do
        if mode == known then return end
    end
    error("screens: no screen mode called '" .. tostring(mode) .. "' (round, asynchronous, "
        .. "smallest)", level + 1)
end
-- }}}

-- {{{ function M.watched()
-- The screen list as the display programs send it: each { name, width,
-- height, watched }. Checked, and the watched ones returned, largest first:
-- by cells, then by width, then by name, so the order never depends on the
-- order they were sent in.
function M.watched(list)
    local seen, out = {}, {}
    for index, screen in ipairs(list) do
        local where = "screens: screen " .. index
        if type(screen.name) ~= "string" or not string.match(screen.name, "^[%w%._%-]+$") then
            error(where .. " has no name (letters, digits, . _ -)", 2)
        end
        if seen[screen.name] then error(where .. " is called '" .. screen.name .. "' twice", 2) end
        seen[screen.name] = true
        for _, side in ipairs({ "width", "height" }) do
            local value = screen[side]
            if type(value) ~= "number" or value < 1 or value ~= math.floor(value) then
                error(where .. " (" .. screen.name .. ") has no whole " .. side .. " of 1 or more", 2)
            end
        end
        if type(screen.watched) ~= "boolean" then
            error(where .. " (" .. screen.name .. ") does not say whether it is watched", 2)
        end
        if screen.watched then out[#out + 1] = screen end
    end
    table.sort(out, function(a, b)
        local ca, cb = a.width * a.height, b.width * b.height
        if ca ~= cb then return ca > cb end
        if a.width ~= b.width then return a.width > b.width end
        return a.name < b.name
    end)
    return out
end
-- }}}

-- {{{ function M.canvases()
-- The canvases a context change makes: { name, width, height }. One per
-- watched screen, largest first, except in smallest mode: one canvas, as
-- narrow as the narrowest screen and as short as the shortest, so it fits
-- in every one of them.
function M.canvases(mode, watched)
    check_mode(mode, 2)
    if #watched == 0 then return {} end
    if mode == "smallest" then
        local width, height = math.huge, math.huge
        for _, screen in ipairs(watched) do
            width, height = math.min(width, screen.width), math.min(height, screen.height)
        end
        return { { name = M.SMALLEST, width = width, height = height } }
    end
    local out = {}
    for index, screen in ipairs(watched) do
        out[index] = { name = screen.name, width = screen.width, height = screen.height }
    end
    return out
end
-- }}}

-- {{{ function M.plan()
-- The turns a context change takes, in batches: a batch is turns that run
-- at the same time, and the next batch starts when it is done. Each turn is
-- { canvas, width, height, voice, slot }; `slot` numbers the turns of a batch
-- that need endpoints of their own at once.
--   round          a batch for each canvas, largest first: every voice paints it
--   asynchronous   one batch: every voice on every canvas, each its own slot
--   smallest       one batch: every voice on the one canvas
function M.plan(mode, watched, voices)
    local batches = {}
    local canvases = M.canvases(mode, watched)
    local function turns_for(list)
        local turns = {}
        for _, made in ipairs(list) do
            for _, voice in ipairs(voices) do
                turns[#turns + 1] = { canvas = made.name, width = made.width,
                                      height = made.height, voice = voice, slot = #turns + 1 }
            end
        end
        return turns
    end
    if mode == "round" then
        for _, made in ipairs(canvases) do
            batches[#batches + 1] = { turns = turns_for({ made }) }
        end
    elseif #canvases > 0 then
        batches[1] = { turns = turns_for(canvases) }
    end
    return batches
end
-- }}}

-- {{{ function M.keeper()
-- Keeps the rounds: a context change starts a round, unless one is under
-- way, in which case it waits until the round ends ("the round finishes on
-- the old context and the new one waits"). Only the newest waiting context
-- is kept; one replaced while waiting is counted as skipped. The mode and
-- the watched screens are taken when a round starts, so a change to either
-- mid-round takes effect at the next one. opts.mode is a function giving the
-- mode (the seam for input/screens).
local Keeper = {}
Keeper.__index = Keeper

function M.keeper(opts)
    if type(opts) ~= "table" or type(opts.mode) ~= "function" then
        error("screens.keeper: opts.mode must be a function giving the screen mode", 2)
    end
    return setmetatable({ read_mode = opts.mode, busy = false, waiting = nil,
        counts = { rounds = 0, batches = 0, turns = 0, ["contexts-held"] = 0,
                   ["contexts-skipped"] = 0 } }, Keeper)
end

-- Starts a round; returns its first batch.
function Keeper:start(context, list)
    local mode = self.read_mode()
    check_mode(mode, 3)
    local watched = M.watched(list)
    self.mode, self.painting, self.watched = mode, context, watched
    self.batches = M.plan(mode, watched, self.voices or {})
    self.index = 0
    self.busy = true
    self.counts.rounds = self.counts.rounds + 1
    return self:batch_done()
end

-- A context change, with the screen list as it is now. Returns the first
-- batch of a new round, or nil when it waits for the round under way.
function Keeper:context(context, list, voices)
    self.voices = voices or self.voices
    if self.busy then
        if self.waiting then
            self.counts["contexts-skipped"] = self.counts["contexts-skipped"] + 1
        else
            self.counts["contexts-held"] = self.counts["contexts-held"] + 1
        end
        self.waiting = { context = context, list = list }
        return nil
    end
    return self:start(context, list)
end

-- The batch under way is done; returns the next batch: of this round, or
-- the first of the next round when a context was waiting, or nil.
function Keeper:batch_done()
    self.index = self.index + 1
    local batch = self.batches[self.index]
    if batch then
        self.counts.batches = self.counts.batches + 1
        self.counts.turns = self.counts.turns + #batch.turns
        batch.round, batch.context, batch.mode = self.counts.rounds, self.painting, self.mode
        return batch
    end
    self.busy = false
    local waiting = self.waiting
    self.waiting = nil
    if waiting then return self:start(waiting.context, waiting.list) end
    return nil
end
-- }}}

-- {{{ function M.display()
-- What a screen shows, given the mode and the canvases made so far (`made`,
-- a table from canvas name to { width, height }): { canvas = name } once a
-- canvas for it is there, with `centred` true when it is smaller than the
-- screen (smallest mode); otherwise { loading = true }. A canvas made for
-- this screen at another size (it was resized, or a cache from before)
-- counts as not there: the screen shows the loading animation until its
-- own size is made.
function M.display(screen, mode, made)
    check_mode(mode, 2)
    local name = mode == "smallest" and M.SMALLEST or screen.name
    local canvas = made[name]
    if not canvas or canvas.width > screen.width or canvas.height > screen.height
        or (mode ~= "smallest" and (canvas.width ~= screen.width
            or canvas.height ~= screen.height)) then
        return { loading = true }
    end
    return { canvas = name, centred = canvas.width < screen.width
        or canvas.height < screen.height }
end
-- }}}

return M
