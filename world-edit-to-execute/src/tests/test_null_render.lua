-- test_null_render.lua - the headless renderer reports a known scene the same way every time (issue 501c)
--
-- In plain terms: builds a small scene in the render slots three ways --
-- from C, from Lua through the bridge's calls, and from Lua through
-- src/render.lua as a game would -- with no window and no raylib, and
-- asks the headless renderer what it would have drawn. The counts must be
-- the scene's, the checksum must be the one this test works out by
-- itself from the scene's values, and it must be the same each time and
-- every way; one changed field must change it.
--
-- Run with: luajit src/tests/test_null_render.lua [DIR] [BUILD]
-- DIR defaults to the project this file is in. Builds in BUILD, or in
-- $WETE_TEST_BUILD/null-render when that is set, or in DIR/tmp/null-render.

-- The project: the argument, or the folder this test sits in (run-tests.sh
-- runs each test by its full path, from the project), or the owner's.
local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local env_build = os.getenv("WETE_TEST_BUILD")
local BUILD = arg[2] or (env_build and env_build ~= "" and env_build .. "/null-render") or (DIR .. "/tmp/null-render")
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ffi = require("ffi")
local bit = require("bit")
local null = require("render.null")

-- {{{ Test utilities
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. tostring(msg) or ""))
    end
end

local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function run(command)
    local ok = os.execute(command)
    return ok == 0 or ok == true
end
-- }}}

-- {{{ the scene
-- Each item: entity, mesh, x, y, z, and what is changed from the bridge's defaults.
local MAP = { min_x = 0, min_y = 0, max_x = 1024, max_y = 1024 }
local scene = {
    { 1, 1, 100, 100, 0, team = 0, selected = true },
    { 2, 1, 200, 120.5, 4, rotation = { 90, 0, 45 } },
    { 3, 1, 1024, 1024, 0, scale = 1.5 },                    -- on the edge: inside
    { 4, 1, 512, 512, 8, color = { 10, 20, 30, 128 } },
    { 5, 0, 300, 300, 0, team = 3 },
    { 6, 0, 310, 300, 0, selected = true },
    { 7, 0, 320, 300, 0 },
    { 8, 2, 50, 900, 2, rotation = { 0, 180 } },
    { 9, 3, 900, 50, 0, scale = 0 },                         -- the bridge makes 0 into 0.01
    { 10, 4, 600, 600, 0 },                                  -- no model: a placeholder, just past the kinds
    { 11, 1, 700, 700, 0, hidden = true },
    { 12, 1, -50, 400, 0, color = { 300, -5, 255 } },        -- outside the map; colours clamped
    { 13, -1, 400, 400, 0 },                                 -- no model either
    { 14, 0, 0, 0, 0 },                                      -- on the other edge: inside
    { 15, 2, 500, 1024.5, 0 },                               -- outside by y alone
}
local want = { active = 15, drawn = 14, hidden = 1, circle = 4, cube = 5, triangle = 2, cylinder = 1,
    placeholders = 2, outside = 2, selected = 2 }
-- }}}

-- {{{ the checksum, worked out here from the scene
local FNV_PRIME = 0x100000001b3ULL
local bits = ffi.new("union { float f; uint32_t u; int32_t i; }")
local function fbits(f) bits.f = f return bits.u end
local function ibits(n) bits.i = n return bits.u end

local function expected_checksum()
    local h = 0xcbf29ce484222325ULL
    local function byte(b) h = bit.bxor(h, ffi.cast("uint64_t", b)) * FNV_PRIME end
    local function u32(v)
        v = tonumber(v)
        for i = 0, 3 do byte(math.floor(v / 2 ^ (8 * i)) % 256) end
    end
    local function clamp(v) v = math.floor(v) return v < 0 and 0 or (v > 255 and 255 or v) end
    for _, e in ipairs(scene) do
        if not e.hidden then
            local rot = e.rotation or { 0, 0, 0 }
            local c = e.color or { 255, 255, 255, 255 }
            local scale = e.scale or 1
            if scale <= 0 then scale = 0.01 end
            u32(ibits(e[1])) u32(ibits(e[2]))
            u32(fbits(e[3])) u32(fbits(e[4])) u32(fbits(e[5]))
            u32(fbits(rot[1])) u32(fbits(rot[2] or 0)) u32(fbits(rot[3] or 0)) u32(fbits(scale))
            byte(clamp(c[1])) byte(clamp(c[2])) byte(clamp(c[3])) byte(clamp(c[4] or 255))
            byte(e.selected and 1 or 0)
            u32(ibits(e.team or -1)) u32(ibits(0)) u32(fbits(0))
        end
    end
    return string.format("%08x%08x", tonumber(h / 4294967296ULL), tonumber(h % 4294967296ULL))
end
local WANT_SUM = expected_checksum()
-- }}}

-- {{{ the scene through the bridge's calls (render.null) or src/render.lua
local function by_bridge(r)
    for _, e in ipairs(scene) do
        local s = r.create_entity(e[1], e[2], e[3], e[4], e[5])
        if e.team then r.set_team(s, e.team) end
        if e.selected then r.set_selected(s, true) end
        if e.rotation then r.set_rotation(s, e.rotation[1], e.rotation[2], e.rotation[3]) end
        if e.scale then r.set_scale(s, e.scale) end
        if e.color then r.set_color(s, e.color[1], e.color[2], e.color[3], e.color[4]) end
        if e.hidden then r.set_visible(s, false) end
    end
end

local MESH_NAMES = { [0] = "circle", [1] = "cube", [2] = "triangle", [3] = "cylinder" }
local function by_render_lua(render)
    for _, e in ipairs(scene) do
        render.create(e[1], MESH_NAMES[e[2]] or "cube", e[3], e[4], e[5])
        if e.team then
            render.set_team(e[1], e.team)
            render.set_color(e[1], 255, 255, 255)            -- render.lua paints a team's colour; the scene keeps white
        end
        if e.selected then render.select(e[1], true) end
        if e.rotation then render.rotate(e[1], e.rotation[1], e.rotation[2], e.rotation[3]) end
        if e.scale then render.scale(e[1], e.scale) end
        if e.color then render.set_color(e[1], e.color[1], e.color[2], e.color[3], e.color[4]) end
        if e.hidden then render.show(e[1], false) end
    end
end
-- }}}

-- {{{ the scene from C
local function c_scene()
    local out = { '#include <stdio.h>', '#include <stdlib.h>', '#include <string.h>', '#include "null_render.h"',
        'static int put(SlotArray* a, int e, int mesh, float x, float y, float z) {',
        '    int i = slot_allocate_for_entity(a, e);',
        '    RenderSlot* d = calloc(1, sizeof *d);',
        '    d->x = x; d->y = y; d->z = z; d->mesh_id = mesh; d->visible = true; d->scale = 1.0f;',
        '    d->r = d->g = d->b = d->a = 255; d->team_id = -1;',
        '    slot_set(slot_get(a, i), d);',
        '    return i;', '}',
        'int main(void) {', '    SlotArray* a = slot_array_create();', '    RenderSlot* d;' }
    local function clamp(v) v = math.floor(v) return v < 0 and 0 or (v > 255 and 255 or v) end
    for _, e in ipairs(scene) do
        out[#out + 1] = string.format('    d = slot_get(a, put(a, %d, %d, (float)%.17g, (float)%.17g, (float)%.17g))->data;', e[1], e[2], e[3], e[4], e[5])
        if e.team then out[#out + 1] = string.format('    d->team_id = %d;', e.team) end
        if e.selected then out[#out + 1] = '    d->selected = true;' end
        if e.rotation then
            out[#out + 1] = string.format('    d->rotation = (float)%.17g; d->spin = (float)%.17g; d->facing = (float)%.17g;',
                e.rotation[1], e.rotation[2] or 0, e.rotation[3] or 0)
        end
        if e.scale then out[#out + 1] = string.format('    d->scale = (float)%.17g;', e.scale <= 0 and 0.01 or e.scale) end
        if e.color then
            out[#out + 1] = string.format('    d->r = %d; d->g = %d; d->b = %d; d->a = %d;',
                clamp(e.color[1]), clamp(e.color[2]), clamp(e.color[3]), clamp(e.color[4] or 255))
        end
        if e.hidden then out[#out + 1] = '    d->visible = false;' end
    end
    out[#out + 1] = string.format('    NullBounds map = { %d, %d, %d, %d };', MAP.min_x, MAP.min_y, MAP.max_x, MAP.max_y)
    out[#out + 1] = '    NullReport r; char text[512];'
    out[#out + 1] = '    null_render_slots(a, &map, &r);'
    out[#out + 1] = '    null_report_format(&r, text, sizeof text);'
    out[#out + 1] = '    fputs(text, stdout);'
    out[#out + 1] = '    slot_array_destroy(a);'
    out[#out + 1] = '    return 0;'
    out[#out + 1] = '}'
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ C
print("from C")
local lib = null.build(DIR, BUILD)
local f = assert(io.open(BUILD .. "/scene.c", "w"))
f:write(c_scene())
f:close()
local src = DIR .. "/src/render/"
test("the scene builds with no raylib", run("gcc -O2 -Wall -pthread -I" .. q(src) .. " -o " .. q(BUILD .. "/scene") .. " "
    .. q(BUILD .. "/scene.c") .. " " .. q(src .. "slots.c") .. " " .. q(src .. "null_render.c")))
local function c_report()
    local p = io.popen("DISPLAY= WAYLAND_DISPLAY= " .. q(BUILD .. "/scene"), "r")
    local text = p:read("*a")
    p:close()
    return text
end
local text = c_report()
test("it runs with no display and reports", text:find("null renderer: 15 slots in use, 14 drawn, 1 hidden", 1, true) ~= nil, text)
test("its counts are the scene's", text:find("circle 4, cube 5, triangle 2, cylinder 1, placeholders 2", 1, true)
    and text:find("outside the map 2, selected 2", 1, true), text)
local c_sum = text:match("checksum (%x+)")
test("its checksum is the one worked out from the scene", c_sum == WANT_SUM, tostring(c_sum) .. " vs " .. WANT_SUM)
test("and the same on a second run", c_report() == text)
-- }}}

-- {{{ Lua, through the bridge's calls
print("from Lua, through the bridge's calls")
local backend = null.open(lib)
by_bridge(backend.render)
local r = backend:report(MAP)
local ok = true
for k, v in pairs(want) do
    local got = r[k] or r.kinds[k]
    if got ~= v then ok = false print("    " .. k .. ": " .. tostring(got) .. ", not " .. v) end
end
test("the counts are the scene's", ok)
test("the checksum is the same as from C", r.checksum == WANT_SUM, r.checksum)
test("the text is the same as from C", backend:text(MAP) == text)
test("with no map, nothing is outside", backend:report().outside == 0 and backend:report().checksum == WANT_SUM)
test("the bridge's slot count", (backend.render.get_slot_count()) == 15 and select(2, backend.render.get_slot_count()) == 4096)
local s5 = backend.render.find_by_entity(5)
backend.render.set_position(s5, 300, 300.25, 0)
test("one field changed changes the checksum", backend:report(MAP).checksum ~= WANT_SUM)
backend.render.set_position(s5, 300, 300, 0)
test("and changed back, it is back", backend:report(MAP).checksum == WANT_SUM)
backend.render.set_selected(s5, true)
test("a selection ring counts and changes it", backend:report(MAP).selected == 3 and backend:report(MAP).checksum ~= WANT_SUM)
backend.render.set_selected(s5, false)
backend.render.set_visible(backend.render.find_by_entity(11), true)
test("an item shown again is drawn", backend:report(MAP).drawn == 15 and backend:report(MAP).hidden == 0)
backend.render.set_mesh(backend.render.find_by_entity(10), 2)
test("a placeholder given a model counts as that kind", backend:report(MAP).placeholders == 1 and backend:report(MAP).kinds.triangle == 3)
backend.render.destroy_entity(backend.render.find_by_entity(12))
test("a destroyed item is gone", backend:report(MAP).active == 14 and backend:report(MAP).outside == 1
    and backend.render.find_by_entity(12) == nil)
backend.render.set_team(9999, 1)
backend.render.set_position(-1, 0, 0, 0)
test("calls on slots not in use change nothing", backend:report(MAP).active == 14)
backend:close()
test("after close the calls do nothing, as the bridge with no slots", backend.render.create_entity(1, 1, 0, 0, 0) == -1
    and backend.render.find_by_entity(1) == nil and backend.render.get_slot_count() == 0)
test("and a report is refused", not pcall(backend.report, backend))
-- }}}

-- {{{ Lua, through src/render.lua
print("from Lua, through src/render.lua")
local again = null.open(lib)
package.loaded.render = again.render
local render = dofile(DIR .. "/src/render.lua")
by_render_lua(render)
-- render.lua knows no other mesh; give 10 and 13 theirs through the bridge, as a game with more models would
again.render.set_mesh(render.get_slot(10), 4)
again.render.set_mesh(render.get_slot(13), -1)
local r2 = again:report(MAP)
test("a scene written for the window runs headless", r2.drawn == 14 and r2.kinds.cube == 5 and r2.placeholders == 2)
test("and gives the same checksum", r2.checksum == WANT_SUM, r2.checksum)
render.destroy_all()
test("destroying everything leaves nothing drawn", again:report(MAP).active == 0 and again:report(MAP).checksum == "cbf29ce484222325")
again:close()
package.loaded.render = nil
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("null renderer: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
