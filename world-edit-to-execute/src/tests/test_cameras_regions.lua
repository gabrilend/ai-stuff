--[[
Tests for the camera editor and new regions (Issue 904b): DAoW 5.4b's
cameras found in its protected script, changed (the calls rewritten), set
from a view in one step; a new camera and a new region made for the
editor's triggers; the game's camera natives (a camera applied, a pan, a
reset reach the world's on_camera); saved and played: the script's camera
has its new fields, a chat trigger applies the new camera and another
pans to the new region; opened again, the new ones read back once; the
window's tools driven headless.
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

-- {{{ The VM's camera natives
test_section("The script moves the camera")
do
    local vm = require("jass.vm")
    local world = vm.bare_world()
    local asked = {}
    world.on_camera = function(r) asked[#asked + 1] = r end
    local V = vm.new(world, { player = 0 })
    assert(V:load([[
globals
    camerasetup gg_cam_A = null
endglobals
function main takes nothing returns nothing
    set gg_cam_A = CreateCameraSetup()
    call CameraSetupSetField(gg_cam_A, CAMERA_FIELD_TARGET_DISTANCE, 900.0, 0.0)
    call CameraSetupSetField(gg_cam_A, CAMERA_FIELD_ROTATION, 45.0, 0.0)
    call CameraSetupSetDestPosition(gg_cam_A, 100.0, 200.0, 0.0)
    call CameraSetupApplyForPlayer(true, gg_cam_A, Player(0), 2.0)
    call CameraSetupApplyForPlayer(true, gg_cam_A, Player(1), 2.0)
    call PanCameraToTimed(-50.0, 60.0, 1.0)
    call ResetToGameCamera(0.5)
endfunction
function config takes nothing returns nothing
endfunction
]]))
    V:run_main()
    test("three asked of the local player's view (not player 2's)", #asked == 3, tostring(#asked))
    test("the camera applied", asked[1] and asked[1].x == 100 and asked[1].y == 200 and asked[1].distance == 900
        and asked[1].rotation == 45 and asked[1].duration == 2)
    test("a pan", asked[2] and asked[2].x == -50 and asked[2].duration == 1)
    test("back to the game camera", asked[3] and asked[3].reset)
    test("the setup read back", V.natives.CameraSetupGetField(V.env.gg_cam_A, "CAMERA_FIELD_ROTATION") == 45
        and V.natives.CameraSetupGetDestPositionX(V.env.gg_cam_A) == 100)
    test("none left as no-ops", not V.noops.CameraSetupApplyForPlayer and not V.noops.PanCameraToTimed)
end
-- }}}

local E = assert(editor.open(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x"))

-- {{{ The map's cameras
test_section("DAoW's cameras")
local cam
do
    local list = E:cameras()
    test("seven, from the script", #list == 7, tostring(#list))
    cam = list[1]
    test("one read whole", cam.distance == 409.8 and cam.rotation == 181 and cam.aoa == 322 and cam.fov == 68
        and cam.zoffset == 604 and cam.x == -8825.4 and cam.y == 18840.3)
    E:set_camera(cam, "distance", 1200)
    E:set_camera(cam, "x", -9000)
    local text = E:script_text()
    test("its distance call rewritten", text:find("CameraSetupSetField(" .. cam.var .. ",CAMERA_FIELD_TARGET_DISTANCE,1200.0,", 1, true) ~= nil)
    test("where it looks", text:find("CameraSetupSetDestPosition(" .. cam.var .. ",-9000.0,18840.3,", 1, true) ~= nil)
    local steps = #E.history.done
    E:camera_from_view(cam, -9100, 18000, 1500, 90, 304, 70)
    test("set from a view in one step", #E.history.done == steps + 1 and cam.distance == 1500 and cam.rotation == 90)
    E:undo()
    test("undone together", cam.distance == 1200 and cam.rotation == 181 and cam.x == -9000)
end
-- }}}

-- {{{ New ones for the triggers
test_section("A new camera and region, used by triggers")
local newcam, reg
do
    newcam = E:new_camera("Throne", 1000, 2000)
    E:set_camera(newcam, "distance", 800)
    E:set_camera(newcam, "rotation", 30)
    test("a camera made", newcam.var == "gg_cam_Throne" and E:camera_named("gg_cam_Throne") == newcam)
    local n = #E:regions()
    reg = E:new_region("Gate", 3000, 4000, 2000, 3500)
    test("a region made, its corners in order", reg.var == "gg_rct_Gate" and reg.left == 2000 and reg.top == 4000
        and #E:regions() == n + 1)
    E:move_region(reg, 100, 0)
    test("moved like the script's", reg.left == 2100)
    local t = E:new_trigger("Show throne")
    E:add_block(t, "events", "player_chat", { player = 0, text = "-throne", exact = true })
    E:add_block(t, "actions", "apply_camera", { camera = newcam.var, player = 0, seconds = 1.5 })
    local t2 = E:new_trigger("Look at gate")
    E:add_block(t2, "events", "player_chat", { player = 0, text = "-gate", exact = true })
    E:add_block(t2, "actions", "pan_camera", { player = 0, region = reg.var, seconds = 2 })
    E:add_block(t2, "actions", "reset_camera", { player = 0, seconds = 0 })
    local code = E:trigger_code()
    test("made at the start", code.functions:find("set gg_cam_Throne = CreateCameraSetup()", 1, true)
        and code.functions:find("set gg_rct_Gate = Rect(2100.0, 3500.0, 3100.0, 4000.0)", 1, true)
        and code.functions:find("call EditorInitRegions()", 1, true) ~= nil)
    test("nothing wrong", #E:check_triggers() == 0, (E:check_triggers()[1] or {}).message)
    test("the script's cameras stay", not E:delete_camera(cam) and not E:delete_region(E:regions()[1]))
end
-- }}}

-- {{{ Saved and played
test_section("Saved, and played")
local TMP = os.tmpname() .. ".w3x"
do
    assert(E:save(TMP))
    local s = require("demo.wc3map.scene").load(TMP)
    local g = require("demo.wc3map.game").new(s, { player = 0, placed = false, minimap = false, vision = false, combat = false })
    local asked = {}
    g.on_camera = function(r) asked[#asked + 1] = r end
    local V = g.run_script({ ai = "none" })
    test("the script runs", V and #g.units > 1000 and #V.errors == 0, V and V.errors[1] and V.errors[1].message)
    local h = V.env[cam.var]
    test("the script's camera, as the game has it", type(h) == "table" and h.fields.distance == 1200 and h.x == -9000)
    local before = #asked
    V:chat(0, "-throne")
    g.tick(0.05)
    local r = asked[before + 1]
    test("the new camera applied by a trigger", r and r.x == 1000 and r.y == 2000 and r.distance == 800
        and r.rotation == 30 and r.duration == 1.5)
    V:chat(0, "-gate")
    g.tick(0.05)
    local p, z = asked[before + 2], asked[before + 3]
    test("a pan to the new region's middle", p and p.x == 2600 and p.y == 3750 and p.duration == 2)
    test("then back to the game camera", z and z.reset)

    local E2 = assert(editor.open(TMP))
    test("opened again: the new camera once", E2:camera_named("gg_cam_Throne") and #E2:cameras() == 8)
    local n = 0
    for _, x in ipairs(E2:regions()) do if x.var == "gg_rct_Gate" then n = n + 1 end end
    test("and the new region once", n == 1 and #E2:regions() == #E:regions())
    os.remove(TMP)
end
-- }}}

-- {{{ The window's tools
test_section("The tools")
do
    local view = { 0, 0, 1650, 90, 304, 70 }
    local ui = require("editor.ui").new(E, 1280, 720, { run_tests = false,
        camera = function() return unpack(view) end,
        set_camera = function(...) view = { ... } end })
    local function press(label)
        for _, b in ipairs(ui.buttons) do
            if b.label == label then ui:update({ mx = b.x + 2, my = b.y + 2, lp = true, keys = {}, chars = "" }, 0.016) return true end
        end
        return false
    end
    E:set_tool("cameras"); ui:layout()
    ui:press_world(cam.x + 50, cam.y, {})
    ui:release_world(cam.x + 250, cam.y, {})
    test("a camera picked and dragged", ui.camera == cam and cam.x == -9000 + 200, tostring(cam.x))
    press("View through it")
    test("the view put where it looks", view[1] == cam.x and view[3] == cam.distance and view[4] == cam.rotation)
    view = { 500, 600, 2000, 120, 300, 60 }
    press("Set it from the view")
    test("set from the view", cam.x == 500 and cam.distance == 2000 and cam.fov == 60)
    local d = cam.distance
    for _, b in ipairs(ui.buttons) do
        if b.action == "camera_step" and b.arg[1] == "distance" and b.arg[2] > 0 then
            ui:update({ mx = b.x + 2, my = b.y + 2, lp = true, keys = {}, chars = "" }, 0.016)
        end
    end
    test("distance stepped", cam.distance == d + 100)
    local n = #E:cameras()
    press("+ Camera from the view")
    test("a camera made from the view", #E:cameras() == n + 1 and ui.camera.x == 500 and ui.camera.distance == 2000)
    press("Delete camera")
    test("and deleted", #E:cameras() == n)
    E:set_tool("regions"); ui:layout()
    local nr = #E:regions()
    ui:press_world(-30000, -30000, {})
    ui:release_world(-29500, -29600, {})
    test("a region dragged out on open ground", #E:regions() == nr + 1 and ui.region and ui.region.editor)
    ui:update({ keys = { "DELETE" }, chars = "" }, 0.016)
    test("and deleted with Delete", #E:regions() == nr)
end
-- }}}

print(string.format("\n%d/%d tests passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
