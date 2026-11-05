-- 039-stand-in-turn.lua - a turn without a language model, for phase 3.
--
-- In plain terms: the turn runner (038) runs one turn by running the program
-- its `turn` setting names. Until the real turn is built (405), that program
-- is this one: it reads the canvas kuvalu sent, writes one word from a
-- scripted list into it, waits a moment as a model would, and writes the
-- voice's canvas back. That is enough to carry canvases round the whole loop
-- (voice, rmail, kuvalu's blitter, rmail, voice) and measure it, so phase 3
-- can be tested apart from phase 4. (issue 304)
--
-- Which word, and where, follows from the turn number and the voice:
--   the word     words[(turn - 1) % #words + 1]
--   the row      (turn - 1) % height + 1
--   the column   1 + (n - 1) * floor(width / 3), n being the number at the
--                end of the voice's name (fg-sora-2: 2), or 1
-- so the three voices write in their own thirds and move down a row a turn.
-- The word is cut to fit its third. Writing a word that is already there
-- changes nothing, which the runner counts as an unchanged turn.
--
--   scripts/stand-in-turn --dir ROOT --voice fg-sora-1 --turn 3 \
--       --canvas turn/fg-sora-1/taken --out turn/fg-sora-1/turn-out
--   local stand_in = dofile(DIR .. "/src/039-stand-in-turn.lua")
--   stand_in.edit(record, voice, turn, words)   -- the from-voice record
--
-- Settings in input/stand-in-turn: `words` (the list, separated by spaces)
-- and `seconds` (how long a turn takes). LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
local settings = dofile(DIR .. "/src/001-settings.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local utf8 = dofile(DIR .. "/src/005-utf8.lua")

local M = {}

-- {{{ M.SETTINGS
M.SETTINGS = {
    ["words"]   = { type = "text", required = true },
    ["seconds"] = { type = "decimal", required = true },
}
-- }}}

-- {{{ function M.edit()
-- The voice's canvas for one turn on a to-voices record.
function M.edit(record, voice, turn, words)
    local width, height = record.width, record.height
    local third = math.max(1, math.floor(width / 3))
    local n = tonumber(string.match(voice, "(%d+)$")) or 1
    local column = 1 + ((n - 1) % 3) * third
    local row = (turn - 1) % height + 1
    local word = utf8.split(words[(turn - 1) % #words + 1])
    local room = math.min(third, width - column + 1)
    local cells = utf8.split(record.rows[row])
    for index = 1, math.min(#word, room) do
        cells[column + index - 1] = word[index]
    end
    local rows = {}
    for index = 1, height do rows[index] = record.rows[index] end
    rows[row] = table.concat(cells)
    return {
        set = "from-voice", width = width, height = height, rows = rows, marks = {},
        headers = { voice = voice, turn = turn, base = record.headers.canvas,
                    written = os.date("!%Y-%m-%dT%H:%M:%SZ") },
    }
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "039%-stand%-in%-turn%.lua$") then
    local opts = { dir = DIR }
    local index = 1
    while index <= #arg do
        local key = string.match(arg[index], "^%-%-(%a+)$")
        if not key or arg[index + 1] == nil then
            io.stderr:write("usage: stand-in-turn [--dir ROOT] --voice NAME --turn N "
                .. "--canvas FILE --out FILE\n")
            os.exit(2)
        end
        opts[key] = arg[index + 1]
        index = index + 2
    end
    local turn = tonumber(opts.turn)
    if not (opts.voice and turn and opts.canvas and opts.out) then
        io.stderr:write("stand-in-turn: --voice, --turn, --canvas and --out are all needed\n")
        os.exit(2)
    end
    local ok, problem = pcall(function()
        local values = settings.read("stand-in-turn", M.SETTINGS, { root = opts.dir })
        local words = {}
        for word in string.gmatch(values.words, "%S+") do words[#words + 1] = word end
        if #words == 0 then error("input/stand-in-turn: words is empty", 0) end
        local handle = assert(io.open(opts.canvas, "rb"))
        local text = handle:read("*a")
        handle:close()
        local record = canvas.read(text, "to-voices", opts.canvas)
        if values.seconds > 0 then ffi.C.poll(nil, 0, math.floor(values.seconds * 1000)) end
        local out = assert(io.open(opts.out, "wb"))
        out:write(canvas.write(M.edit(record, opts.voice, turn, words), "from-voice"))
        out:close()
    end)
    if not ok then
        io.stderr:write(tostring(problem), "\n")
        os.exit(1)
    end
    os.exit(0)
end
-- }}}

return M
