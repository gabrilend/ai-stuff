#!/usr/bin/env luajit
-- 067-distill.lua - distill mode's asking: one canvas made from every
-- voice's newest.
--
-- In plain terms: the owner: "This updated copy will be sent to Kuvalu, who
-- will run all three combined to distill it once more, and then display it
-- to the screen." In distill mode the blitter keeps the newest canvas from
-- each voice, with the words that voice changed against the version it
-- started from (104). When canvases arrive, this builds the distiller's
-- prompt from input/distill-instructions: the canvas as it is now, each
-- voice's newest canvas and the words it changed, and the same rules the
-- voices follow. It asks the `distiller` endpoint (the endpoints file's
-- use.distiller, read again every distill) through the turn's
-- ask-until-it-fits loop (404), with no look calls, and hands back the
-- distilled rows. The blitter blits them with the current canvas as their
-- base, under the name kuvalu: the distiller is not asked which voice each
-- change came from ("like melting two candles to each other",
-- docs/datapath-blit.md, "distill"). (issue 601)
--
--   local distill = dofile(DIR .. "/src/067-distill.lua")
--   local result = distill.run({
--       root = ROOT,                 -- input/distill, input/distill-instructions, endpoints
--       current = record,            -- the canvas as it is now (006)
--       newest = { { voice = "fg-sora-1", canvas = record, found = changes.find(...),
--                    turn = 4, base = 7 }, ... },   -- in the voices' order
--       log = function(line) end,    -- optional
--       call = function(conversation) return text, info end,  -- optional (tests);
--                                    -- default: the distiller endpoint
--   })
--   result.rows, result.note, result.counts (051's), result.endpoint (its name)
--
--   distill.build({ instructions, current, newest, recommended })  -- the conversation
--   distill.changes_text(found)                                    -- the changed words
--
-- LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local settings = dofile(DIR .. "/src/001-settings.lua")
local prompt = dofile(DIR .. "/src/049-turn-prompt.lua")
local ask = dofile(DIR .. "/src/051-ask-until-it-fits.lua")

local M = {}

M.SOURCE = "input/distill-instructions"
M.ROLE = "distiller"
M.VOICE = "kuvalu"

-- {{{ M.SETTINGS
-- input/distill: the recommended change counts the distiller is told, advice
-- only, as a turn's are (docs/fit-check.md).
M.SETTINGS = {
    ["recommended-words"]     = { type = "whole", required = true },
    ["recommended-sentences"] = { type = "whole", required = true },
}
-- }}}

-- {{{ M.SPEC
-- The instruction file's parts and markers, read by 049's parse_spec, so the
-- two instruction files are refused the same way.
M.SPEC = {
    source = M.SOURCE,
    parts = { "system", "user", "voice" },
    markers = {
        width = true, height = true, words = true, sentences = true, count = true,
        version = true, canvas = true, voices = true,
        name = true, turn = true, base = true, changes = true, ["voice-canvas"] = true,
    },
    required = {
        system = { "width", "height" },
        user = { "canvas", "voices" },
        voice = { "name", "voice-canvas" },
    },
}
-- }}}

-- {{{ function M.read_instructions()
function M.read_instructions(root)
    local handle = io.open(root .. "/" .. M.SOURCE, "rb")
    if not handle then
        error(M.SOURCE .. ": there is no instruction file; the distiller's words live there "
            .. "(issue 601)", 0)
    end
    local text = handle:read("*a")
    handle:close()
    return text
end
-- }}}

-- {{{ function M.parse()
function M.parse(text)
    return prompt.parse_spec(text, M.SPEC)
end
-- }}}

-- {{{ function M.changes_text()
-- The words a voice changed against its base (010's found), one a line,
-- erased words (removed, or written over) before written ones, each in
-- reading order:
--   erased "kitten" at row 1, column 5
--   wrote "cat" at row 1, column 5
-- or one line saying there are none.
function M.changes_text(found)
    local lines = {}
    local function sorted(list)
        local copy = {}
        for index, word in ipairs(list or {}) do copy[index] = word end
        table.sort(copy, function(a, b)
            if a.row ~= b.row then return a.row < b.row end
            return a.column < b.column
        end)
        return copy
    end
    -- a word written over is as gone as one erased (010 lists it apart)
    local gone = {}
    for _, word in ipairs(found.removed or {}) do gone[#gone + 1] = word end
    for _, word in ipairs(found.overwritten or {}) do gone[#gone + 1] = word end
    for _, word in ipairs(sorted(gone)) do
        lines[#lines + 1] = string.format('erased "%s" at row %d, column %d', word.text, word.row,
            word.column)
    end
    for _, word in ipairs(sorted(found.written)) do
        lines[#lines + 1] = string.format('wrote "%s" at row %d, column %d', word.text, word.row,
            word.column)
    end
    if #lines == 0 then return "(no words changed against that version)" end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ local function whole()
local function whole(value)
    return type(value) == "number" and value >= 0 and value == math.floor(value)
end
-- }}}

-- {{{ function M.build()
-- The distiller's conversation: a system turn and a user turn. opts:
--   instructions  input/distill-instructions' text
--   current       the canvas as it is now (a record with rows, width, height,
--                 and headers.canvas, its version)
--   newest        the voices' newest canvases, in order: { voice, canvas,
--                 found, turn, base }
--   recommended   { words, sentences }
function M.build(opts)
    local current = opts.current
    if type(current) ~= "table" or not current.rows or not current.width then
        error("distill.build: current is not a canvas record", 2)
    end
    if type(opts.newest) ~= "table" or #opts.newest == 0 then
        error("distill.build: there is no voice canvas to distill", 2)
    end
    local recommended = opts.recommended
    if type(recommended) ~= "table" or not whole(recommended.words)
        or not whole(recommended.sentences) then
        error("distill.build: recommended must be { words = N, sentences = N }", 2)
    end
    local parts = M.parse(opts.instructions)
    local voices = {}
    for _, entry in ipairs(opts.newest) do
        voices[#voices + 1] = prompt.fill(parts.voice, {
            name = entry.voice,
            turn = tostring(entry.turn or "?"),
            base = tostring(entry.base or "?"),
            changes = M.changes_text(entry.found or {}),
            ["voice-canvas"] = prompt.ruler(entry.canvas),
        })
    end
    local values = {
        width = tostring(current.width),
        height = tostring(current.height),
        words = tostring(recommended.words),
        sentences = tostring(recommended.sentences),
        count = tostring(#opts.newest),
        version = tostring(current.headers and current.headers.canvas or "?"),
        canvas = prompt.ruler(current),
        voices = table.concat(voices, "\n\n"),
    }
    return {
        { role = "system", content = prompt.fill(parts.system, values) },
        { role = "user", content = prompt.fill(parts.user, values) },
    }
end
-- }}}

-- {{{ function M.run()
-- One distill: the settings and words read now (so edits take effect at the
-- next distill), the distiller asked until its canvas fits, the rows back.
-- A model or network error is raised, for the blitter to log; the arrivals
-- then stay held and the distill is tried again (016).
function M.run(opts)
    local root = opts.root
    local values = settings.read("distill", M.SETTINGS, { root = root })
    local recommended = { words = values["recommended-words"],
                          sentences = values["recommended-sentences"] }
    local conversation = M.build({ instructions = M.read_instructions(root),
        current = opts.current, newest = opts.newest, recommended = recommended })
    local call, endpoint_name = opts.call, "(given)"
    if not call then
        local caller = dofile(DIR .. "/src/046-model-caller.lua")
        local endpoint = caller.for_role(root, M.ROLE)
        endpoint_name = endpoint.name or caller.describe(endpoint)
        call = function(turns) return caller.chat(endpoint, turns) end
    end
    local result = ask.until_fits({
        call = call, conversation = conversation, base = opts.current,
        recommended = recommended, look_limit = 0, log = opts.log,
    })
    result.endpoint = endpoint_name
    return result
end
-- }}}

return M
