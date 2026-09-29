--[[
AI Profile Tool (Issue 521)

Writes an editable AI profile (ai/profile.lua's shape: the AI Editor's
tabs as a Lua table) for each computer faction of a map, derived from
what the map's own script gives it, into ai-profiles/<map>/. Files
already there are kept; the game uses a faction's file instead of
deriving while it exists. Also checks the profiles in a folder.

    luajit src/ai/tool.lua write assets/DAoW-5.4b-PUBLIC-TEST.w3x
    luajit src/ai/tool.lua check ai-profiles/DAoW-5.4b-PUBLIC-TEST
]]

local ROOT = (arg[0]:match("^(.*)/src/ai/tool%.lua$")) or "."
package.path = ROOT .. "/src/?.lua;" .. ROOT .. "/src/?/init.lua;" .. package.path

local profile = require("ai.profile")
local faction = require("ai.faction")

local cmd, target, out = arg[1], arg[2], arg[3]

if cmd == "write" and target then
    local map_scene = require("demo.wc3map.scene")
    local game_mod = require("demo.wc3map.game")
    local scene = map_scene.load(target)
    local game = game_mod.new(scene, { player = 0, minimap = false, placed = false, pathing = false })
    local V, err = game.run_script({ ai = "none" })
    if not V then
        io.stderr:write("the map's script didn't run: " .. tostring(err) .. "\n")
        os.exit(1)
    end
    -- every player slot but the local one, that owns something
    local players, names = {}, {}
    for n = 1, 11 do
        for _, u in ipairs(game.units) do
            if u.player == n then
                players[#players + 1] = n
                names[n] = V:text(V:player(n).name)
                break
            end
        end
    end
    local dir = out or (ROOT .. "/ai-profiles/" .. faction.map_key(target))
    local written = faction.write(dir, game, players, names)
    for _, path in ipairs(written) do print("wrote " .. path) end
    print(string.format("%d written, %d kept (already there)", #written, #players - #written))
elseif cmd == "check" and target then
    local bad = 0
    for f in io.popen('ls "' .. target .. '"/*.lua 2>/dev/null'):lines() do
        local chunk, err = loadfile(f)
        local problems = chunk and profile.check(chunk()) or { tostring(err) }
        print((#problems == 0 and "ok   " or "BAD  ") .. f)
        for _, p in ipairs(problems) do print("       " .. p) end
        if #problems > 0 then bad = bad + 1 end
    end
    os.exit(bad == 0 and 0 or 1)
else
    print("usage: luajit src/ai/tool.lua write MAP [DIR]  |  check DIR")
    os.exit(2)
end
