--[[
Tests for the WC3 interface (Issue 518): layout, command card, HUD input
and drawing, and the map game state's orders. Headless: a fake game with a
flat projection, and a recorder in place of the renderer.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local layout = require("ui.wc3.layout")
local commands = require("ui.wc3.commands")
local hud_mod = require("ui.wc3.hud")
local names = require("ui.wc3.names")
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

-- {{{ Layout
test_section("Layout")

local r = layout.compute(1280, 720)
local function within(b) return b.x >= 0 and b.y >= 0 and b.x + b.w <= 1280 and b.y + b.h <= 720 end
local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
local all_inside = within(r.minimap) and within(r.portrait) and within(r.info) and within(r.card_area)
for _, b in ipairs(r.card) do all_inside = all_inside and within(b) end
test("console parts on screen", all_inside)
test("12 command buttons", #r.card == 12)
local clash = false
for i = 1, 12 do for j = i + 1, 12 do clash = clash or overlap(r.card[i], r.card[j]) end end
test("command buttons don't overlap", not clash)
local parts = { r.minimap, r.portrait, r.info, r.card_area }
for _, s in ipairs(r.inventory) do parts[#parts + 1] = s end
clash = false
for i = 1, #parts do for j = i + 1, #parts do clash = clash or overlap(parts[i], parts[j]) end end
test("minimap, portrait, info, inventory and card don't overlap", not clash)
test("four menu buttons, F9-F12", #r.menu == 4 and r.menu[1].key == "F9" and r.menu[4].key == "F12")
test("five minimap buttons", #r.minimap_buttons == 5)
test("six inventory slots", #r.inventory == 6)
-- }}}

-- {{{ A fake game
-- Screen = world / 10 (x right, y down = -world y), everything in front
local function fake_game()
    local g = { player = 0, orders = {}, camera_at = { 0, 0 }, quit_called = false }
    local function unit(id, spec, player, x, y) return { id = id, spec = spec, player = player, x = x, y = y, z = 0, name = id } end
    g.units = {
        unit("hfoo", { design = "unit", archetype = "infantry" }, 0, 3000, -3000),
        unit("hfoo", { design = "unit", archetype = "infantry" }, 0, 3200, -3000),
        unit("hkni", { design = "unit", archetype = "mounted" }, 0, 3400, -3000),
        unit("Hpal", { design = "unit", archetype = "infantry", hero = true }, 0, 3600, -3000),
        unit("hpea", { design = "unit", archetype = "worker" }, 0, 3800, -3000),
        unit("hbar", { design = "building", size = "medium" }, 0, 5000, -3000),
        unit("ogru", { design = "unit", archetype = "infantry" }, 1, 6000, -3000),
        unit("nban", { design = "unit", archetype = "infantry" }, 12, 7000, -3000),
    }
    g.db = {
        unit_list = function(id, code)
            if code == "ubui" then return names.BUILDS[id] or {} end
            if code == "utra" then return names.TRAINS[id] or {} end
            if code == "uhab" and id == "Hpal" then return { "AHhb", "AHds", "AHad", "AHre" } end
            return {}
        end,
        unit_button = function(id) return { name = names.unit(id) or id } end,
        ability_button = function(id) return { name = names.ability(id) or id } end,
    }
    g.to_screen = function(x, y, z) return x / 10, -y / 10 + (z or 0) * 0, true end
    g.to_ground = function(sx, sy) return sx * 10, -sy * 10 end
    g.camera = function() return g.camera_at[1], g.camera_at[2], 1650 end
    g.set_camera = function(x, y) g.camera_at = { x, y } end
    g.order = function(list, kind, x, y) g.orders[#g.orders + 1] = { list = list, kind = kind, x = x, y = y } end
    g.resources = function() return { gold = 500, lumber = 150, food = 12, food_cap = 30 } end
    g.time_of_day = function() return 8 end
    g.minimap = { x0 = -10000, y0 = -10000, x1 = 10000, y1 = 10000 }
    g.players = { { number = 0, name = "Red", team = 1 }, { number = 1, name = "Blue", team = 2 } }
    g.quests = { main = { "A quest" }, optional = {} }
    g.portrait = function() end
    g.quit = function() g.quit_called = true end
    return g
end

-- screen point of a unit (its middle is drawn 45 units up; the flat
-- projection ignores height)
local function at(u) return u.x / 10, -u.y / 10 end
-- }}}

-- {{{ Command card
test_section("Command card")

local g = fake_game()
local foot, pal, pea, bar, grunt = g.units[1], g.units[4], g.units[5], g.units[6], g.units[7]
local S = commands.slot
local card = commands.card(foot, g.db, "main")
test("Move at top left (M)", card[S(0, 0)] and card[S(0, 0)].action == "move" and card[S(0, 0)].hotkey == "M")
test("Stop (S), Hold Position (H), Attack (A) across the top",
    card[S(1, 0)].hotkey == "S" and card[S(2, 0)].hotkey == "H" and card[S(3, 0)].hotkey == "A")
test("Patrol under Move (P)", card[S(0, 1)].action == "patrol" and card[S(0, 1)].hotkey == "P")
local hero_card = commands.card(pal, g.db, "main")
test("hero: Hero Abilities at the middle right (O)", hero_card[S(3, 1)].action == "learn")
test("hero: its abilities along the bottom", hero_card[S(0, 2)] and hero_card[S(0, 2)].label == "Holy Light")
local worker_card = commands.card(pea, g.db, "main")
test("worker: Build Structure at the bottom left (B)", worker_card[S(0, 2)].action == "build")
test("worker: Gather (G)", worker_card[S(3, 1)].action == "gather")
local build_card = commands.card(pea, g.db, "build")
test("build menu: structures", build_card[1] and build_card[1].label == "Town Hall")
test("build menu: Cancel stays bottom right even when full", build_card[S(3, 2)].action == "cancel")
local bar_card = commands.card(bar, g.db, "main")
test("building: trains its units", bar_card[1].action == "train" and bar_card[1].label == "Train Footman")
test("building: rally point", bar_card[S(3, 1)].action == "rally")
test("hotkey lookup", commands.find_hotkey(card, "A") == S(3, 0))
test("stock commands have tooltips", card[S(0, 0)].tip ~= nil)
-- }}}

-- {{{ HUD input
test_section("Interface input")

g = fake_game()
foot, pal, pea, bar, grunt = g.units[1], g.units[4], g.units[5], g.units[6], g.units[7]
local hud = hud_mod.new(g, 1280, 720)
local function frame(input) input.keys = input.keys or {}; hud:update(input, 0.02) end
local function click(x, y, extra)
    local i = { mx = x, my = y, lp = true, ld = true, lr = true }
    for k, v in pairs(extra or {}) do i[k] = v end
    frame(i)
end

local fx, fy = at(foot)
click(fx, fy)
test("click selects a unit", #hud.selection == 1 and hud.selection[1] == foot)
test("its card shows", hud:card()[1] and hud:card()[1].action == "move")

click(at(grunt))
test("an enemy can be selected", hud.selection[1] == grunt)
test("but its card is empty", next(hud:card()) == nil)

hud.drag = { x0 = 290, y0 = 290, x1 = 290, y1 = 290 }
frame({ mx = 710, my = 310, lr = true })
test("drag selects your units only", #hud.selection == 5)
local has_building = false
for _, u in ipairs(hud.selection) do has_building = has_building or u.spec.design == "building" end
test("units before buildings", not has_building)

hud:select({ foot })
frame({ keys = { "M" } })
test("hotkey M starts targeting", hud.targeting == "move")
click(400, 250)
local o = g.orders[#g.orders]
test("a click orders the move there", o and o.kind == "move" and o.x == 4000 and o.y == -2500)
test("targeting ends", hud.targeting == nil)

frame({ mx = 450, my = 260, rp = true })
o = g.orders[#g.orders]
test("right click on the ground: move", o.kind == "move" and o.x == 4500)
local gx, gy = at(grunt)
frame({ mx = gx, my = gy, rp = true })
test("right click on an enemy: attack that unit", g.orders[#g.orders].kind == "attack_unit")

frame({ keys = { "A" } })
frame({ keys = { "ESCAPE" } })
test("Esc cancels targeting", hud.targeting == nil)

local n_orders = #g.orders
frame({ keys = { "S" } })
test("S: stop at once", #g.orders == n_orders + 1 and g.orders[#g.orders].kind == "stop")

click(r.card[S(3, 0)].x + 5, r.card[S(3, 0)].y + 5)
test("clicking a button presses it", hud.targeting == "attack")
frame({ keys = { "ESCAPE" } })

hud:select({ pea })
frame({ keys = { "B" } })
test("B opens the build menu", hud.mode == "build")
frame({ keys = { "ESCAPE" } })
test("Esc closes it", hud.mode == "main")

hud:select({ foot, g.units[2] })
frame({ keys = { "1" }, ctrl = true })
hud:select({ pea })
frame({ keys = { "1" } })
test("Ctrl+1 sets a group, 1 recalls it", #hud.selection == 2 and hud.selection[1] == foot)

frame({ keys = { "F1" } })
test("F1 selects the first hero", hud.selection[1] == pal)
frame({ keys = { "F8" } })
test("F8 selects an idle worker", hud.selection[1] == pea)

hud:select({ foot, g.units[3] })
frame({ keys = { "TAB" } })
test("Tab moves to the next subgroup", hud:leader() == g.units[3])

frame({ keys = { "T" }, alt = true })
test("Alt+T toggles the minimap terrain", hud.toggles.terrain == false)

local mm = r.minimap
click(mm.x + mm.w / 2, mm.y + mm.h / 2)
test("a minimap click moves the camera", math.abs(g.camera_at[1]) < 200 and math.abs(g.camera_at[2]) < 200)

frame({ keys = { "F10" } })
test("F10 opens the menu", hud.panel == "menu")
local p = r.panel
click(p.x + p.w / 2, p.y + 60 + 6 * 46 + 10)
test("Return to Game closes it", hud.panel == nil)
click(r.menu[2].x + 5, r.menu[2].y + 5)
test("the Menu button opens it too", hud.panel == "menu")
click(p.x + p.w / 2, p.y + 60 + 5 * 46 + 10)
test("End Game quits", g.quit_called)
hud.panel = nil
frame({ keys = { "F9" } })
test("F9: quests", hud.panel == "quests")
frame({ keys = { "F9" } })
test("F9 again closes", hud.panel == nil)
-- }}}

-- {{{ Drawing
test_section("Drawing")

local calls, texts = {}, {}
local ui = setmetatable({
    ui_text = function(s) texts[#texts + 1] = s; calls.ui_text = (calls.ui_text or 0) + 1 end,
    ui_text_width = function(s, size) return #s * size / 2 end,
}, { __index = function(_, name)
    return function() calls[name] = (calls[name] or 0) + 1 end
end })
hud:select({ pal })
hud.panel = nil
hud:draw(ui)
local joined = table.concat(texts, "|")
test("draws without error", calls.ui_rect and calls.ui_rect > 30)
test("menu buttons labelled", joined:find("Quests") and joined:find("Allies"))
test("resources shown", joined:find("500") and joined:find("150") and joined:find("12/30"))
test("upkeep shown", joined:find("No Upkeep"))
test("the hero's name and level", joined:find("Hpal") and joined:find("Level 1 Hero"))
test("portrait drawn", calls.ui_portrait == 1)
for _, panel in ipairs({ "quests", "menu", "allies", "log" }) do
    hud.panel = panel
    local ok = pcall(hud.draw, hud, ui)
    test("panel " .. panel .. " draws", ok)
end
-- }}}

-- {{{ Game state (a real map)
test_section("Game state on Daow4.4")

local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local scene = map_scene.load(DIR .. "/assets/Daow4.4.w3x")
local game = game_mod.new(scene, { player = 0, minimap = false, combat = false })
test("units carry names", game.units[1].name ~= nil)
test("players", #game.players > 1)
local res = game.resources(0)
test("melee starting gold and lumber unless the script sets them", res.gold == 500 and res.lumber == 150)
test("the day starts at 8:00", game.time_of_day() == 8)

local mover
for _, u in ipairs(game.units) do
    if u.player == 0 and u.spec.design == "unit" then mover = u; break end
end
local x0, y0 = mover.x, mover.y
-- a point it can reach: the walkable cell of its own region nearest 600
-- east (issue 519: orders now path around cliffs and water)
local pi, pj = game.pathing:cell(x0, y0)
local ti, tj = game.pathing:nearest(pi + 5, pj, game.pathing:region_at(game.pathing:nearest(pi, pj)))
local gx, gy = game.pathing:world(ti, tj)
game.order({ mover }, "move", gx, gy)
for _ = 1, 50 do game.tick(0.02) end
test("a moved unit walks", math.abs(mover.x - x0) + math.abs(mover.y - y0) > 50,
    string.format("%.0f, %.0f", mover.x - x0, mover.y - y0))
test("on the ground", math.abs(mover.z - scene.sample.ground_at(mover.x, mover.y)) < 1e-6)
for _ = 1, 500 do game.tick(0.02) end
test("and arrives", math.abs(mover.x - gx) < 1 and math.abs(mover.y - gy) < 1 and mover.order == nil,
    string.format("%.0f, %.0f off", mover.x - gx, mover.y - gy))
game.order({ mover }, "patrol", x0, y0)
for _ = 1, 400 do game.tick(0.02) end
test("patrol keeps going", mover.order ~= nil and mover.order.kind == "patrol")
game.order({ mover }, "stop")
test("stop clears the order", mover.order == nil)
test("the clock turns: a day in 480 s", math.abs(game.time_of_day() - (8 + game.time / 480 * 24)) < 1e-9)
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))
if pass_count == test_count then
    print("ALL TESTS PASSED")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}
