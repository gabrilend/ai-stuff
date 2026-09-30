--[[
The Map Editor's Core (Issue 901)

A map opened for editing: its terrain (war3map.w3e), doodads
(war3map.doo), placed units (war3mapUnits.doo, when the map has one) and
the units its script places by literal CreateUnit calls (as DAoW's
protected script does), each as the editor's own objects; the tool in
hand, the selection, the clipboard and the undo history. Nothing here
draws: src/editor/main.lua is the window; tests drive this directly.

  terrain    brushes: raise, lower, smooth, flatten, paint a ground
             texture, water, cliffs up and down, blight (editor/terrain.lua)
  objects    doodads and units placed, moved, turned, scaled, deleted,
             copied and pasted (editor/objects.lua)
  types      the map's changes to object types, and its custom types
             (editor/object_data.lua)
  regions    the script's rects moved and resized (editor/regions.lua)
  saving     a copy of the map with what changed written back
             (editor/save.lua, through mpq.save_copy: the map opened is
             never written)
  testing    the saved copy played in the game (E:playtest)
  modules    other parts of the editor register themselves by name
             (E:register(name, module)); a module's init(E) runs then

Every change goes through the history (editor/history.lua): Ctrl+Z and
Ctrl+Y in the window.

    local editor = require("editor")
    local E = editor.open("assets/Daow4.4.w3x")
    E:set_tool("raise"); E:stroke_begin(); E:stroke(x, y); E:stroke_end()
    E:undo(); E:redo()
    E:save("maps/mine.w3x")
]]

local mpq = require("mpq")
local w3e = require("parsers.w3e")
local doo = require("parsers.doo")
local unitsdoo = require("parsers.unitsdoo")
local history_mod = require("editor.history")

local editor = {}

editor.TOOLS = { "select", "raise", "lower", "smooth", "flatten", "paint", "water", "dry", "cliff_up",
                 "cliff_down", "blight", "unblight", "place_doodad", "place_unit", "regions" }

local E = {}
E.__index = E

-- {{{ editor.open
function editor.open(path, opts)
    opts = opts or {}
    local a, err = mpq.open(path)
    if not a then return nil, err end
    local self = setmetatable({ path = path, opts = opts, modules = {}, messages = {} }, E)
    local tdata = a:extract("war3map.w3e")
    if not tdata then a:close() return nil, "no war3map.w3e" end
    self.terrain = w3e.parse(tdata)
    local ddata = a:extract("war3map.doo")
    self.doodads = ddata and doo.parse(ddata) or { version = 8, subversion = 11, doodads = {}, tail_raw = "" }
    local udata = a:extract("war3mapUnits.doo")
    self.units_doo = udata and unitsdoo.parse(udata) or nil
    self.script_name = a:has("war3map.j") and "war3map.j" or (a:has("scripts\\war3map.j") and "scripts\\war3map.j") or nil
    self.script = self.script_name and a:extract(self.script_name) or nil
    local wpm = a:extract("war3map.wpm")
    self.path_map = wpm and require("demo.wc3map.footprint").parse_wpm(wpm) or nil
    if self.path_map then self.path_map.header = wpm:sub(1, 16) end
    a:close()

    self.history = history_mod.new(opts.history_limit or 200)
    self.tool = "select"
    self.brush = { size = 2, strength = 32, texture = 0, level = nil }
    self.selection = {}
    self.clipboard = nil
    self.dirty = { terrain = false, doodads = false, units = false, script = false, objects = {} }
    self.changed_tiles = {}          -- tile key -> true, for the window to redraw
    self.terrain_touched = {}        -- every tile key changed since opening (saving asks)
    self.objects_changed = false
    require("editor.terrain")(E)
    require("editor.objects")(E)
    require("editor.save")(E)
    require("editor.object_data")(E)
    require("editor.regions")(E)
    self:load_objects()
    self:load_regions()
    return self
end
-- }}}

-- {{{ tools, messages, modules
function E:set_tool(name)
    for _, t in ipairs(editor.TOOLS) do
        if t == name then self.tool = name return true end
    end
    for _, m in pairs(self.modules) do
        if m.tools and m.tools[name] then self.tool = name return true end
    end
    return false
end

function E:say(text)
    self.messages[#self.messages + 1] = { text = text, at = os.clock() }
    if #self.messages > 50 then table.remove(self.messages, 1) end
end

function E:register(name, module)
    self.modules[name] = module
    if module.init then module.init(self) end
    return module
end
-- }}}

-- {{{ undo and redo
function E:undo()
    local name = self.history:undo()
    if name then self:say("Undid: " .. name) end
    return name
end

function E:redo()
    local name = self.history:redo()
    if name then self:say("Redid: " .. name) end
    return name
end
-- }}}

-- {{{ testing: the saved copy in the game
-- Saves to a copy beside the map and returns the command that plays it
-- (the viewer with the game's scene script); run it when opts.run
function E:playtest(opts)
    opts = opts or {}
    local dst = opts.path or (os.tmpname() .. ".w3x")
    local ok, why = self:save(dst)
    if not ok then return nil, why end
    local root = opts.root or "."
    local viewer = opts.viewer or os.getenv("WC3_VIEWER") or (root .. "/src/render/scene_viewer")
    local cmd = string.format('"%s" "%s" src/demo/wc3map/main.lua "%s"', viewer, root, dst)
    if opts.run then os.execute(cmd .. " &") end
    self:say("Testing " .. dst)
    return cmd, dst
end
-- }}}

return editor
