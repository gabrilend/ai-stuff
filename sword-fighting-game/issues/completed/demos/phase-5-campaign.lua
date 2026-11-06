-- phase-5-campaign.lua - plays a whole match headless and draws the campaign
-- map after every round, for the phase 5 demo.
--
-- Each region is two characters: its owner (1 or 2, or . for nobody) and its
-- kind (m meadow, s swamp park, p prairie, h hills). The front is shown in
-- brackets. Under the map: the round, the push, where it was fought, who won,
-- and how many of each side were standing at the end.
--
-- Usage: luajit phase-5-campaign.lua <project-dir> [seed]

local DIR = arg[1]
local SEED = tonumber(arg[2] or 3)
package.path = DIR .. "/src/?.lua;" .. package.path
local util = require("002-util")
local match_m = require("017-the-match")
local campaign = require("016-the-campaign")

local config = util.load_config(DIR)
local catalogue = require("004-catalogue").load(DIR, config.mods)
local m = match_m.new(config, catalogue, SEED, { person = false })
local KIND = { meadow = "m", swamp_park = "s", prairie = "p", hills = "h" }

-- {{{ local function draw()
local function draw()
	for row = 0, m.map.height - 1 do
		local line = {}
		for col = 0, m.map.width - 1 do
			local r = campaign.region(m.map, col, row)
			local text = (r.owner == 0 and "." or tostring(r.owner)) .. KIND[r.kind]
			local front = m.map.front.col == col and m.map.front.row == row
			line[#line + 1] = front and ("[" .. text .. "]") or (" " .. text .. " ")
		end
		print("      " .. table.concat(line))
	end
end
-- }}}

print(string.format("phase 5 - command and the round: a match from seed %d", SEED))
print("")
draw()
local seen = 0
while not m.result and m.round < 40 do
	match_m.tick(m)
	if #m.history > seen then
		seen = #m.history
		local h = m.history[seen]
		local words = { [0] = "drawn", [1] = "won", [2] = "lost" }
		print(string.format("\n  round %d: pushed %s into %s, %s after %.0f s (standing %d/%d), perks %d",
			h.round, h.push, h.region, words[h.winner], h.seconds, h.standing[1], h.standing[2],
			#m.taken[1]))
		draw()
	end
end
print("")
print(m.result == 1 and "  the match is won" or (m.result == 2 and "  the match is lost"
	or "  the match ran out of rounds"))
local names = {}
for _, t in ipairs(m.taken[1]) do names[#names + 1] = t.name end
print("  perks taken: " .. table.concat(names, ", "))
