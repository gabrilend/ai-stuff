-- phase-2-crowds.lua - draws a battle's crowds in the terminal, second by
-- second, for the phase 2 demo.
--
-- Each frame is the battlefield seen from above, one character per cell:
-- a and b are soldiers of the two sides (A and B while guarding), _ a
-- soldier lying tripped, x one fallen, . open ground. Under each frame are
-- the movement counters so far: steps blocked by an enemy, steps taken into
-- an ally's cell, the yields allies gave, and trips.
--
-- Usage: luajit phase-2-crowds.lua <project-dir> [seconds]

local DIR = arg[1]
local SECONDS = tonumber(arg[2] or 22)
package.path = DIR .. "/src/?.lua;" .. package.path
local util = require("002-util")
local battle_m = require("014-the-battle")

local config = util.load_config(DIR)
local catalogue = require("004-catalogue").load(DIR, config.mods)
local b = battle_m.new({ config = config, catalogue = catalogue,
	streams = require("003-random-streams").make_set(7), region = "meadow" })

-- {{{ local function glyph()
local function glyph(s)
	if not s.alive then return "x" end
	if s.tripped > 0 then return "_" end
	local c = s.team == 1 and "a" or "b"
	return s.guard and c:upper() or c
end
-- }}}

-- {{{ local function frame()
local function frame()
	local rows = {}
	for y = 0, b.field.height - 1 do
		local row = {}
		for x = 0, b.field.width - 1 do row[x + 1] = "." end
		rows[y + 1] = row
	end
	for _, s in ipairs(b.soldiers) do
		local x, y = math.floor(s.x), math.floor(s.y)
		if y >= 0 and y < b.field.height and x >= 0 and x < b.field.width then
			rows[y + 1][x + 1] = glyph(s)
		end
	end
	local out = {}
	for y = 9, b.field.height - 3 do out[#out + 1] = "    " .. table.concat(rows[y]) end
	return table.concat(out, "\n")
end
-- }}}

local per_second = math.floor(1 / config.tick.seconds)
for second = 1, SECONDS do
	for _ = 1, per_second do battle_m.tick(b) end
	local c = b.counters
	io.write("\027[H\027[2J")
	print(string.format("phase 2 - bodies on the field     second %d of %d", second, SECONDS))
	print(frame())
	print(string.format("    blocked steps %-6d ally passes %-6d yields %-5d trips %-3d falls %d",
		c.blocked_steps, c.ally_passes, c.yields, c.trips, c.falls))
	os.execute("sleep 0.35")
end
