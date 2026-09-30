--[[
Tests for the map editor's core (Issues 901, 902, 903, 911): undo and
redo with grouped steps, the terrain brushes, objects placed, moved,
turned, scaled, deleted, copied and pasted, the script's own units moved
and deleted and new ones added, and a saved copy that the game then
plays: DAoW 5.4b's script runs on it, the moved unit stands where it was
put, the deleted one isn't made, the new one is, and the raised ground
and new water are there.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
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

local editor = require("editor")
local history = require("editor.history")
local w3e = require("parsers.w3e")

-- {{{ History
test_section("Undo and redo")
do
    local h = history.new(3)
    local v = 0
    local function add(n) return { name = "add " .. n, redo = function() v = v + n end, undo = function() v = v - n end } end
    h:run(add(1)); h:run(add(2))
    test("done", v == 3 and h:next_undo() == "add 2")
    test("undo", h:undo() == "add 2" and v == 1)
    test("redo", h:redo() == "add 2" and v == 3)
    h:undo()
    h:run(add(10))
    test("something new drops what could be redone", not h:can_redo() and v == 11)
    h:begin("group"); h:run(add(5)); h:run(add(7)); h:finish()
    test("a group is one step", h:next_undo() == "group" and v == 23)
    h:undo()
    test("undone together", v == 11)
    h:run(add(1)); h:run(add(1)); h:run(add(1)); h:run(add(1))
    local n = 0
    while h:undo() do n = n + 1 end
    test("no more than its limit kept", n == 3)
end
-- }}}

local E = assert(editor.open(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x"))
local t = E.terrain
-- an open, dry, level spot near player 0's base
local X, Y = 18400, 16300
local ci, cj = E:tile_at(X, Y)
local function tp(i, j) return t.tilepoints[j][i] end

-- {{{ Terrain
test_section("Terrain brushes")
do
    test("opened: terrain, doodads, the script's units", #E.doodads.doodads > 1000 and #E.script_units > 1000)
    E.brush.size, E.brush.strength = 2, 50
    local h0, edge0, out0 = tp(ci, cj).height, tp(ci + 2, cj).height, tp(ci + 4, cj).height
    E:set_tool("raise")
    E:stroke_begin(nil, X, Y); E:stroke(X, Y); E:stroke(X, Y); local name = E:stroke_end()
    test("raise: the middle by the strength, twice", tp(ci, cj).height == h0 + 100, tostring(tp(ci, cj).height - h0))
    test("less toward the edge", tp(ci + 2, cj).height - edge0 < 100 and tp(ci + 2, cj).height > edge0)
    test("nothing past it", tp(ci + 4, cj).height == out0)
    test("one step", name and name:find("Raise") and E.history:next_undo() == name)
    E:undo()
    test("undone: as it was", tp(ci, cj).height == h0 and tp(ci + 2, cj).height == edge0)
    E:redo()
    test("redone", tp(ci, cj).height == h0 + 100)
    E:set_tool("smooth")
    E:stroke_begin(nil, X, Y); for _ = 1, 5 do E:stroke(X, Y) end; E:stroke_end()
    test("smooth: the peak comes down", tp(ci, cj).height < h0 + 100)
    E:set_tool("flatten")
    E:stroke_begin(nil, X + 1000, Y); E:stroke(X + 1000, Y); E:stroke(X + 1100, Y); E:stroke_end()
    local fi, fj = E:tile_at(X + 1100, Y)
    test("flatten: to where it began", tp(fi, fj).height == tp(E:tile_at(X + 1000, Y)).height)
    E.brush.texture = 1
    E:set_tool("paint")
    E:stroke_begin(nil, X, Y); E:stroke(X, Y); E:stroke_end()
    test("paint: the ground texture", tp(ci, cj).ground_texture == 1)
    E.brush.size = 1
    E:set_tool("cliff_up")
    local l0 = tp(ci, cj).layer_height
    E:stroke_begin(nil, X, Y); E:stroke(X, Y); E:stroke(X, Y); E:stroke_end()
    test("a cliff level up, once a stroke", tp(ci, cj).layer_height == l0 + 1)
    E:undo()
    test("and back", tp(ci, cj).layer_height == l0)
    E:set_tool("blight")
    E:stroke_begin(nil, X, Y); E:stroke(X, Y); E:stroke_end()
    test("blight", tp(ci, cj).is_blight)
    E:undo()
    E.brush.size = 2
    E:set_tool("water")
    local wx, wy = X - 1200, Y
    E:stroke_begin(nil, wx, wy); E:stroke(wx, wy); E:stroke_end()
    local wi, wj = E:tile_at(wx, wy)
    test("water over the ground where it began", tp(wi, wj).has_water and w3e.is_wet(tp(wi, wj)))
    E.brush.size = 0
    E:set_tool("dry")
    E:stroke_begin(nil, wx + 256, wy); E:stroke(wx + 256, wy); E:stroke_end()
    test("dry", not tp(E:tile_at(wx + 256, wy)).has_water)
    local changed = E:take_changed_tiles()
    test("the tilepoints changed are told to the window", #changed > 20 and #E:take_changed_tiles() == 0)
end
-- }}}

-- {{{ Objects
test_section("Objects")
local placed_tree, new_unit, moved, gone
do
    local ids = E:doodad_types()
    test("the map's doodad types for the palette", #ids > 5)
    placed_tree = E:place_doodad(ids[1], X + 300, Y + 300, { facing = 1, scale = 1.5 })
    test("placed on the ground", placed_tree.entry.position.z == E:ground_z(X + 300, Y + 300)
        and E.doodads.doodads[#E.doodads.doodads] == placed_tree.entry)
    E:undo()
    test("undone: gone from the doodads", placed_tree.deleted and E.doodads.doodads[#E.doodads.doodads] ~= placed_tree.entry)
    E:redo()
    test("redone", not placed_tree.deleted)
    test("picked where it stands", E:pick(X + 310, Y + 290) == placed_tree)
    E:select({ placed_tree })
    E:move_selection(64, 0)
    test("moved", placed_tree.x == X + 364 and placed_tree.entry.position.x == X + 364)
    E:rotate_selection(0.5)
    E:scale_selection(2)
    test("turned and scaled", math.abs(placed_tree.facing - 1.5) < 1e-9 and placed_tree.entry.scale.x == 3)
    E:undo(); E:undo()
    test("undone in turn", placed_tree.entry.scale.x == 1.5 and math.abs(placed_tree.facing - 1) < 1e-9)
    E:copy()
    local made = E:paste(X + 800, Y + 800)
    test("copied and pasted", #made == 1 and made[1].kind == "doodad" and made[1].x == X + 800 and made[1] ~= placed_tree)
    E:delete_selection()
    test("deleted", made[1].deleted)
    E:undo()
    test("delete undone", not made[1].deleted)
    -- the script's own units
    for _, o in ipairs(E.script_units) do
        if not moved and o.who ~= "" and (o.x - X) ^ 2 + (o.y - Y) ^ 2 < 3000 ^ 2 then moved = o end
    end
    for _, o in ipairs(E.script_units) do
        if not gone and o ~= moved and o.id ~= moved.id and (o.x - X) ^ 2 + (o.y - Y) ^ 2 < 3000 ^ 2 then gone = o end
    end
    test("script units near", moved ~= nil and gone ~= nil)
    E:select({ moved }); E:move_selection(256, 128)
    E:select({ gone }); E:delete_selection()
    new_unit = E:place_unit("hfoo", 0, X + 500, Y - 500, math.rad(90))
    test("a unit placed", new_unit.kind == "new_unit" and #E.new_units == 1)
    local text = E:script_text()
    test("the script: the moved call's new numbers", text:find(string.format("CreateUnit(%s,'%s',%.1f,%.1f,",
        moved.who, moved.id, moved.x, moved.y), 1, true) ~= nil)
    local call = E.script:sub(gone.at, gone.to)
    local _, count_before = E.script:gsub(call:gsub("%p", "%%%0"), "")
    local _, count_after = text:gsub(call:gsub("%p", "%%%0"), "")
    test("the deleted call gone", count_after == count_before - 1, count_before .. " -> " .. count_after)
    test("the new unit's function, called from main", text:find("function EditorPlacedUnits", 1, true)
        and text:find("call EditorPlacedUnits()", 1, true)
        and text:find("call CreateUnit(Player(0),'hfoo'", 1, true))
end
-- }}}

-- {{{ Saving and playing
test_section("Saved, and played")
local TMP = os.tmpname() .. ".w3x"
do
    local ok, rep = E:save(TMP)
    test("saved", ok and rep.files >= 4, type(rep) == "table" and tostring(rep.files) or tostring(rep))
    local files = E:files()
    test("the pathing map changed where water came", files["war3map.wpm"] ~= nil)
    local cmd = E:playtest({ path = TMP .. ".test.w3x", root = DIR, viewer = "/bin/true" })
    test("a play-test command for the saved copy", cmd and cmd:find("main.lua", 1, true) ~= nil)
    os.remove(TMP .. ".test.w3x")

    local map_scene = require("demo.wc3map.scene")
    local game_mod = require("demo.wc3map.game")
    local s = map_scene.load(TMP)
    local ti, tj = E:tile_at(X, Y)
    test("the saved terrain (heights kept to a quarter unit)",
        math.abs(s.terrain:get_tile(ti, tj).height - tp(ci, cj).height) <= 0.125)
    local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, combat = false })
    local V = g.run_script({ ai = "none" })
    test("the map's script runs on the copy", V ~= nil and #g.units > 1000, tostring(#g.units))
    local at_new, at_old, gone_there, fresh = false, false, false, false
    for _, u in ipairs(g.units) do
        if u.id == moved.id and math.abs(u.x - moved.x) < 1 and math.abs(u.y - moved.y) < 1 then at_new = true end
        if u.id == moved.id and math.abs(u.x - moved.orig.x) < 1 and math.abs(u.y - moved.orig.y) < 1 then at_old = true end
        if u.id == gone.id and math.abs(u.x - gone.x) < 1 and math.abs(u.y - gone.y) < 1 then gone_there = true end
        if u.id == "hfoo" and u.player == 0 and math.abs(u.x - (X + 500)) < 1 and math.abs(u.y - (Y - 500)) < 1 then fresh = true end
    end
    test("the moved unit stands where it was put", at_new and not at_old)
    test("the deleted one isn't made", not gone_there)
    test("the placed one is", fresh)
    test("no script errors", #V.errors == 0, V.errors[1] and V.errors[1].message)
    os.remove(TMP)
end
-- }}}

-- {{{ Object types
test_section("Object types")
do
    local E3 = assert(editor.open(DIR .. "/assets/Daow4.4.w3x"))
    local units = E3:object_table("units")
    -- a custom unit type the map has, with a numeric change
    local ut, field
    for _, o in ipairs(units.custom_list) do
        for _, m in ipairs(o.modifications) do
            if not ut and m.var_type == 0 and m.field_id == "uhpm" then ut, field = o, m end
        end
    end
    test("the map's unit types and their changes", ut ~= nil, tostring(#units.custom_list))
    local hp0 = field.value
    E3:set_field("units", ut.id, "uhpm", hp0 + 100)
    test("a change changed", field.value == hp0 + 100 and E3.dirty.objects.units)
    E3:undo()
    test("and undone", field.value == hp0)
    local id = E3:new_type("units", "hfoo")
    test("a new type copying a stock one: h and three more", id and id:match("^h%w%w%w$") and units.custom[id]
        and units.custom[id].parent_id == "hfoo", tostring(id))
    E3:set_field("units", id, "uhpm", 1234)
    E3:set_field("units", id, "unam", "Editor Footman")
    E3:set_field("units", id, "umvs", 350.5)
    local f = E3:type_fields("units", id)
    test("its fields, each of its own type", #f == 3 and f[1].var_type == 0 and f[2].var_type == 3 and f[3].var_type == 1)
    local n_before = #E3:type_fields("abilities", "AHbz")
    E3:set_field("abilities", "AHbz", "Hbz9", 12, 2)
    local got
    for _, m in ipairs(E3:type_fields("abilities", "AHbz")) do if m.field_id == "Hbz9" then got = m end end
    test("a levelled kind's field at a level", got and got.level == 2 and got.value == 12)
    E3:undo()
    test("undone: the field gone again", #E3:type_fields("abilities", "AHbz") == n_before)
    local o = E3:place_unit(id, 0, E3.terrain.offset_x + 64 * E3.terrain.width, E3.terrain.offset_y + 64 * E3.terrain.height, 0)
    local TMP3 = os.tmpname() .. ".w3x"
    local ok = E3:save(TMP3)
    test("saved with the unit types", ok and E3:files()["war3map.w3u"] ~= nil)
    local s3 = require("demo.wc3map.scene").load(TMP3)
    local t3 = s3.map.object_data.units
    test("the copy's unit types have it", t3:get(id) ~= nil and t3:get_modification(id, "uhpm") == 1234
        and t3:get_modification(id, "unam") == "Editor Footman")
    local g3 = require("demo.wc3map.game").new(s3, { player = 0, placed = false, minimap = false, vision = false, combat = false })
    local V3 = g3.run_script({ ai = "none" })
    local made
    for _, u in ipairs(g3.units) do if u.id == id then made = u end end
    test("the game makes the new type, with its hit points", made and made.hp_max == 1234 and made.name == "Editor Footman",
        made and (tostring(made.hp_max) .. " " .. tostring(made.name)))
    E3:delete_type("units", id)
    test("a custom type deleted", units.custom[id] == nil)
    E3:undo()
    test("and back", units.custom[id] ~= nil)
    os.remove(TMP3)
end
-- }}}

-- {{{ Regions
test_section("Regions")
do
    local E4 = assert(editor.open(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x"))
    local regs = E4:regions()
    test("the script's rects, as regions", #regs > 50, tostring(#regs))
    local r = regs[1]
    local l, b, rt, t = r.left, r.bottom, r.right, r.top
    test("found by a point inside", E4:region_at((l + rt) / 2, (b + t) / 2) ~= nil)
    E4:move_region(r, 256, -128)
    test("moved", r.left == l + 256 and r.top == t - 128)
    E4:set_region_bounds(r, r.left, r.bottom, r.right + 512, r.top)
    test("resized", r.right == rt + 256 + 512)
    E4:undo()
    test("undone: moved only", r.right == rt + 256)
    local text = E4:script_text()
    test("the Rect call has the new numbers", text:find(string.format("Rect(%.1f,%.1f,%.1f,%.1f)", r.left, r.bottom, r.right, r.top), 1, true) ~= nil)
    local TMP4 = os.tmpname() .. ".w3x"
    assert(E4:save(TMP4))
    local s4 = require("demo.wc3map.scene").load(TMP4)
    local g4 = require("demo.wc3map.game").new(s4, { player = 0, placed = false, minimap = false, vision = false, combat = false })
    local V4 = g4.run_script({ ai = "none" })
    local rv = V4.env[r.var]
    test("the game's rect is where it was put", type(rv) == "table" and rv.minx == r.left and rv.maxy == r.top,
        type(rv) == "table" and (rv.minx .. "," .. rv.maxy) or tostring(rv))
    os.remove(TMP4)
end
-- }}}

-- {{{ The interface
test_section("The editor's interface")
do
    local E2 = assert(editor.open(DIR .. "/assets/Daow4.4.w3x"))
    local editor_ui = require("editor.ui")
    -- the screen maps straight onto the ground: 10 world units a pixel,
    -- about a spot on the map
    local t2 = E2.terrain
    local OX, OY = t2.offset_x + t2.width * 64, t2.offset_y + t2.height * 64
    local function to_ground(mx, my) return OX + (mx - 640) * 10, OY - (my - 360) * 10 end
    local ui = editor_ui.new(E2, 1280, 720, { to_ground = to_ground, save_path = os.tmpname() .. ".w3x", run_tests = false })
    local function frame(i) i.keys = i.keys or {}; ui:update(i, 1 / 30) end
    local function button(action, arg)
        for _, b in ipairs(ui.buttons) do if b.action == action and (arg == nil or b.arg == arg) then return b end end
    end
    local b = button("tool", "raise")
    frame({ mx = b.x + 5, my = b.y + 5, lp = true, lr = true })
    test("a toolbar button picks the tool", E2.tool == "raise")
    test("the palette shows the brush", button("size", 1) ~= nil and button("strength", 1) ~= nil)
    local gi, gj = E2:tile_at(to_ground(640, 360))
    local h0 = E2.terrain.tilepoints[gj][gi].height
    frame({ mx = 640, my = 360, lp = true, ld = true })
    for _ = 1, 6 do frame({ mx = 640, my = 360, ld = true }) end
    frame({ mx = 640, my = 360, lr = true })
    local h1 = E2.terrain.tilepoints[gj][gi].height
    test("held down on the ground: the brush works, more the longer", h1 > h0 + E2.brush.strength, tostring(h1 - h0))
    test("one undo step for the stroke", E2.history:next_undo():find("Raise") ~= nil)
    frame({ mx = 640, my = 360, keys = { "Z" }, ctrl = true })
    test("Ctrl+Z undoes it", E2.terrain.tilepoints[gj][gi].height == h0)
    frame({ mx = 640, my = 360, keys = { "Y" }, ctrl = true })
    test("Ctrl+Y redoes it", E2.terrain.tilepoints[gj][gi].height == h1)
    -- place a doodad, select it, drag it
    b = button("tool", "place_doodad")
    frame({ mx = b.x + 5, my = b.y + 5, lp = true, lr = true })
    test("the doodad palette lists the map's types", button("pick_type") ~= nil)
    local n0 = #E2.doodads.doodads
    frame({ mx = 700, my = 300, lp = true, lr = true })
    test("a click places one", #E2.doodads.doodads == n0 + 1)
    frame({ keys = { "1" } })
    test("1: the select tool", E2.tool == "select")
    frame({ mx = 700, my = 300, lp = true, ld = true })
    frame({ mx = 720, my = 300, ld = true })
    frame({ mx = 720, my = 300, lr = true })
    local placed = E2.doodads.doodads[#E2.doodads.doodads]
    local wx = to_ground(700, 300)
    test("clicked: selected, and dragged 200 along", #E2.selection == 1 and math.abs(placed.position.x - (wx + 200)) < 1e-6,
        tostring(placed.position.x - wx))
    test("the properties' buttons show", button("delete") ~= nil)
    frame({ mx = 700, my = 300, keys = { "DELETE" } })
    test("Delete removes it", #E2.doodads.doodads == n0)
    -- a start with nothing under it
    local sx, sy = 100, 100
    while E2:pick(to_ground(sx, sy)) and sx < 600 do sx, sy = sx + 13, sy + 7 end
    local before = #E2:objects()
    frame({ mx = sx, my = sy, lp = true, ld = true })
    frame({ mx = 1100, my = 650, ld = true })
    frame({ mx = 1100, my = 650, lr = true })
    test("a box on empty ground selects what's in it", #E2.selection > 5, tostring(#E2.selection))
    frame({ keys = { "ESCAPE" } })
    test("Esc drops the selection", #E2.selection == 0)
    local ok = ui:save()
    test("Save writes the copy", ok and E2.saved_to == ui.opts.save_path)
    os.remove(ui.opts.save_path)
    local fake = {}
    local calls = 0
    for _, k in ipairs({ "ui_rect", "ui_frame", "ui_text" }) do fake[k] = function() calls = calls + 1 end end
    ui:draw(fake)
    test("it draws", calls > 20)
end
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
