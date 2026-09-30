--[[
The Editor's Interface (Issue 901)

What the editor's window shows and how it takes input, apart from the
window itself (editor/main.lua) so tests can drive it:

  toolbar     the tools (select, the terrain brushes, doodads, units) and
              Triggers (the trigger editor over the view: editor/trigger_ui.lua),
              AI (the AI editor over the view: editor/ai_ui.lua), Files
              (the import manager: editor/imports_ui.lua),
              Undo, Redo, Save, Test
  palette     on the left, for the tool in hand: brush size and strength,
              the map's ground textures, its doodad types or unit types
              (paged), the player new units belong to
  properties  on the right: the selection (kind, type, place, facing,
              scale, player) with turn, scale and delete buttons
  status      the tool, the point under the pointer, how many objects and
              selected, unsaved changes, the last message

  mouse       a terrain tool paints while the button is held (one undo
              step a stroke); select picks (Shift adds), drags what's
              picked (one step), or boxes; the placing tools place
  keys        Ctrl+Z / Ctrl+Y undo and redo, Ctrl+C / Ctrl+V copy and
              paste at the pointer, Delete, Ctrl+S save, F5 test,
              [ and ] brush size, 1-9 tools, Esc drops the selection

    local ui = require("editor.ui").new(E, w, h, { to_ground = fn, save_path = p, on_test = fn })
    ui:update(input, dt)     -- input: mx, my, lp, ld, lr, keys, ctrl, shift
    ui:draw(render)
]]


local EUI = {}
EUI.__index = EUI

local editor_ui = {}

editor_ui.TOOLBAR = {
    { "select", "Select" }, { "raise", "Raise" }, { "lower", "Lower" }, { "smooth", "Smooth" },
    { "flatten", "Flatten" }, { "paint", "Paint" }, { "water", "Water" }, { "dry", "Dry" },
    { "cliff_up", "Cliff +" }, { "cliff_down", "Cliff -" }, { "blight", "Blight" },
    { "place_doodad", "Doodads" }, { "place_unit", "Units" }, { "regions", "Regions" },
}
editor_ui.COMMANDS = { { "triggers", "Triggers" }, { "ai", "AI" }, { "files", "Files" }, { "undo", "Undo" },
                       { "redo", "Redo" }, { "save", "Save" }, { "test", "Test" } }
-- the panels over the view each command opens
editor_ui.PANELS = { triggers = "editor.trigger_ui", ai = "editor.ai_ui", files = "editor.imports_ui" }
editor_ui.PAGE = 18
editor_ui.STROKE_EVERY = 0.05

local C = {
    panel = { 24, 26, 32 }, edge = { 70, 74, 86 }, button = { 44, 48, 58 }, active = { 90, 120, 60 },
    hover = { 64, 70, 84 }, text = { 225, 225, 215 }, dim = { 150, 150, 140 }, gold = { 240, 200, 90 },
    warn = { 240, 120, 90 },
}

-- {{{ editor_ui.new
function editor_ui.new(E, w, h, opts)
    local self = setmetatable({ E = E, w = w, h = h, opts = opts or {}, page = 0, player = 0,
                                doodad = nil, unit = nil, clock = 0 }, EUI)
    self.doodad = E:doodad_types()[1]
    self.unit = E:unit_types()[1] or "hfoo"
    self:layout()
    return self
end
-- }}}

-- {{{ layout: every button this frame
function EUI:layout()
    local E = self.E
    local b = {}
    local x = 8
    for _, t in ipairs(editor_ui.TOOLBAR) do
        b[#b + 1] = { x = x, y = 6, w = 56, h = 26, label = t[2], action = "tool", arg = t[1], active = E.tool == t[1] }
        x = x + 60
    end
    local widths = { triggers = 72, ai = 36, files = 48 }
    local total = 0
    for _, c in ipairs(editor_ui.COMMANDS) do total = total + (widths[c[1]] or 52) + 4 end
    x = self.w - 4 - total
    for _, c in ipairs(editor_ui.COMMANDS) do
        local w = widths[c[1]] or 52
        b[#b + 1] = { x = x, y = 6, w = w, h = 26, label = c[2], action = c[1], active = self.tui ~= nil and self.panel == c[1] }
        x = x + w + 4
    end
    -- the trigger editor over the view (issue 905): only the toolbar besides
    if self.tui then
        self.buttons = b
        self.tui:layout()
        return b
    end
    -- the palette
    local px, py = 8, 44
    local function pb(label, action, arg, active, wide)
        b[#b + 1] = { x = px, y = py, w = wide or 200, h = 22, label = label, action = action, arg = arg, active = active }
        py = py + 26
    end
    if E:is_terrain_tool() then
        pb("Size " .. E.brush.size .. "  [-]", "size", -1, nil, 98); py = py - 26; px = px + 102
        pb("[+]", "size", 1, nil, 98); px = px - 102
        pb("Strength " .. E.brush.strength .. "  [-]", "strength", -1, nil, 98); py = py - 26; px = px + 102
        pb("[+]", "strength", 1, nil, 98); px = px - 102
        if E.tool == "paint" then
            for i, ts in ipairs(E.terrain.ground_tilesets) do
                pb(i - 1 .. ": " .. ts, "texture", i - 1, E.brush.texture == i - 1)
            end
        end
    elseif E.tool == "place_doodad" or E.tool == "place_unit" then
        local list = E.tool == "place_doodad" and E:doodad_types() or E:unit_types()
        local pages = math.max(1, math.ceil(#list / editor_ui.PAGE))
        self.page = math.min(self.page, pages - 1)
        pb("Page " .. (self.page + 1) .. "/" .. pages .. "  [<]", "page", -1, nil, 98); py = py - 26; px = px + 102
        pb("[>]", "page", 1, nil, 98); px = px - 102
        if E.tool == "place_unit" then pb("Player " .. self.player .. "  (next)", "player", 1) end
        local cur = E.tool == "place_doodad" and self.doodad or self.unit
        for k = 1, editor_ui.PAGE do
            local id = list[self.page * editor_ui.PAGE + k]
            if id then pb(id, "pick_type", id, id == cur) end
        end
    end
    -- the selection's buttons
    if #E.selection > 0 then
        local rx, ry = self.w - 208, 44 + 7 * 20
        for _, s in ipairs({ { "Turn -15", "turn", -15 }, { "Turn +15", "turn", 15 }, { "Scale -", "scale", 1 / 1.1 },
                             { "Scale +", "scale", 1.1 }, { "Delete", "delete" }, { "New type from this", "new_type" } }) do
            b[#b + 1] = { x = rx, y = ry, w = 200, h = 22, label = s[1], action = s[2], arg = s[3] }
            ry = ry + 26
        end
        -- its type's numeric changes, each a step down or up (issue 906)
        local o = E.selection[1]
        local kind = self:kind_of(o)
        ry = ry + 8
        local shown = 0
        for _, m in ipairs(kind and E:type_fields(kind, o.id) or {}) do
            if type(m.value) == "number" and shown < 8 then
                shown = shown + 1
                local lvl = (m.level or 0) > 0 and ("/" .. m.level) or ""
                b[#b + 1] = { x = rx, y = ry, w = 128, h = 22, label = m.field_id .. lvl .. " " .. string.format(
                    m.var_type == 0 and "%d" or "%.2f", m.value), action = "none" }
                b[#b + 1] = { x = rx + 132, y = ry, w = 32, h = 22, label = "-", action = "field", arg = { kind, o.id, m, -1 } }
                b[#b + 1] = { x = rx + 168, y = ry, w = 32, h = 22, label = "+", action = "field", arg = { kind, o.id, m, 1 } }
                ry = ry + 26
            end
        end
    end
    self.buttons = b
    return b
end

local function inside(b, x, y) return x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h end

function EUI:over_ui(mx, my)
    if self.tui then return true end
    if my < 38 or my > self.h - 28 then return true end
    for _, b in ipairs(self.buttons or {}) do if inside(b, mx, my) then return true end end
    if mx < 216 and (self.E:is_terrain_tool() or self.E.tool:match("^place")) then return true end
    if mx > self.w - 216 and #self.E.selection > 0 then return true end
    return false
end
-- }}}

-- {{{ actions
function EUI:press(b)
    local E = self.E
    local a = b.action
    if editor_ui.PANELS[a] then
        -- a panel over the view (the trigger editor, the AI editor, the
        -- import manager); its button again closes it
        if self.tui and self.panel == a then self.tui, self.panel = nil, nil
        else self.tui, self.panel = require(editor_ui.PANELS[a]).new(E, self.w, self.h, { root = self.opts.root }), a end
    elseif a == "tool" then E:set_tool(b.arg); self.page = 0; self.tui, self.panel = nil, nil
    elseif a == "undo" then E:undo()
    elseif a == "redo" then E:redo()
    elseif a == "save" then self:save()
    elseif a == "test" then self:test()
    elseif a == "size" then E.brush.size = math.max(0, math.min(8, E.brush.size + b.arg))
    elseif a == "strength" then E.brush.strength = math.max(4, math.min(256, E.brush.strength * (b.arg > 0 and 2 or 0.5)))
    elseif a == "texture" then E.brush.texture = b.arg
    elseif a == "page" then self.page = math.max(0, self.page + b.arg)
    elseif a == "player" then self.player = (self.player + 1) % 16
    elseif a == "pick_type" then
        if E.tool == "place_doodad" then self.doodad = b.arg else self.unit = b.arg end
    elseif a == "turn" then E:rotate_selection(math.rad(b.arg))
    elseif a == "scale" then E:scale_selection(b.arg)
    elseif a == "delete" then E:delete_selection()
    elseif a == "field" then
        local kind, id, m, dir = b.arg[1], b.arg[2], b.arg[3], b.arg[4]
        local step = m.var_type == 0 and math.max(1, math.floor(math.abs(m.value) * 0.1 + 0.5)) or math.max(0.01, math.abs(m.value) * 0.1)
        E:set_field(kind, id, m.field_id, m.value + dir * step, m.level)
    elseif a == "new_type" then
        local o = E.selection[1]
        local kind = self:kind_of(o)
        local id = kind and E:new_type(kind, o.id)
        if id then E:set_type_of_selection(id); E:say("New type " .. id .. " from " .. o.id) end
    end
    self:layout()
end

-- the object-data kind a placed object's type is in
function EUI:kind_of(o)
    if not o then return nil end
    if o.kind == "doodad" then
        local E = self.E
        if E:object_table("destructibles")._by_id[o.id] then return "destructibles" end
        if E:object_table("doodads")._by_id[o.id] then return "doodads" end
        -- stock: trees and destructibles are the ones with life
        return (o.entry and (o.entry.life or 100) > 0 and o.entry.flags ~= 0) and "destructibles" or "doodads"
    end
    return "units"
end

function EUI:save()
    local path = self.opts.save_path or (self.E.path:gsub("%.w3[xm]$", "") .. "-edited.w3x")
    local ok, why = self.E:save(path)
    if not ok then self.E:say("Couldn't save: " .. tostring(why)) end
    return ok
end

function EUI:test()
    local cmd, why = self.E:playtest({ run = self.opts.run_tests ~= false, root = self.opts.root, viewer = self.opts.viewer })
    if not cmd then self.E:say("Couldn't test: " .. tostring(why)) end
    return cmd
end
-- }}}

-- {{{ EUI:update
function EUI:update(input, dt)
    local E = self.E
    self.clock = self.clock + (dt or 0)
    local mx, my = input.mx or 0, input.my or 0
    local gx, gy
    if self.opts.to_ground then gx, gy = self.opts.to_ground(mx, my) end
    self.ground = gx and { gx, gy } or nil
    -- the trigger editor takes the keys it uses, and the mouse below the toolbar
    if self.tui then
        local used = self.tui:update(input)
        if input.lp and my < 38 then
            for _, b in ipairs(self.buttons) do if inside(b, mx, my) then self:press(b) end end
        end
        if not used then
            for _, k in ipairs(input.keys or {}) do
                if input.ctrl and k == "Z" then E:undo(); self.tui:layout()
                elseif input.ctrl and k == "Y" then E:redo(); self.tui:layout()
                elseif input.ctrl and k == "S" then self:save()
                elseif k == "F5" then self:test() end
            end
        end
        return
    end
    -- keys
    for _, k in ipairs(input.keys or {}) do
        if input.ctrl and k == "Z" then E:undo()
        elseif input.ctrl and k == "Y" then E:redo()
        elseif input.ctrl and k == "C" then if E:copy() then E:say("Copied " .. #E.selection) end
        elseif input.ctrl and k == "V" then if gx then E:paste(gx, gy) end
        elseif input.ctrl and k == "S" then self:save()
        elseif k == "F5" then self:test()
        elseif k == "DELETE" then E:delete_selection()
        elseif k == "ESCAPE" then E:select({})
        elseif k == "LEFT_BRACKET" or k == "[" then E.brush.size = math.max(0, E.brush.size - 1)
        elseif k == "RIGHT_BRACKET" or k == "]" then E.brush.size = math.min(8, E.brush.size + 1)
        elseif not input.ctrl and k:match("^%d$") then
            local t = editor_ui.TOOLBAR[tonumber(k) == 0 and 10 or tonumber(k)]
            if t then E:set_tool(t[1]) end
        end
        self:layout()
    end
    -- mouse
    local over = self:over_ui(mx, my)
    if input.lp then
        local hit
        for _, b in ipairs(self.buttons) do if inside(b, mx, my) then hit = b end end
        if hit then
            self:press(hit)
            self.pressed_ui = true
            return
        end
        self.pressed_ui = over
        if not over and gx then self:press_world(gx, gy, input) end
    end
    if input.ld and not self.pressed_ui and gx then self:drag_world(gx, gy, input) end
    if input.lr then
        if not self.pressed_ui then self:release_world(gx, gy, input) end
        self.pressed_ui = false
    end
end

function EUI:press_world(gx, gy, input)
    local E = self.E
    if E:is_terrain_tool() then
        E:stroke_begin(nil, gx, gy)
        E:stroke(gx, gy)
        self.last_stroke = self.clock
    elseif E.tool == "place_doodad" and self.doodad then
        E:place_doodad(self.doodad, gx, gy)
    elseif E.tool == "place_unit" and self.unit then
        E:place_unit(self.unit, self.player, gx, gy, math.rad(270))
    elseif E.tool == "regions" then
        -- a region: its corner nearest the pointer (within 96) resizes it,
        -- anywhere else inside moves it (issue 904)
        local r = E:region_at(gx, gy) or self.region
        self.region = r
        if r then
            local corner
            for _, c in ipairs({ { "left", "bottom" }, { "right", "bottom" }, { "left", "top" }, { "right", "top" } }) do
                if (r[c[1]] - gx) ^ 2 + (r[c[2]] - gy) ^ 2 < 96 ^ 2 then corner = c end
            end
            self.drag = { kind = corner and "corner" or "region", corner = corner, x0 = gx, y0 = gy }
        end
    elseif E.tool == "select" then
        local o = E:pick(gx, gy)
        if o then
            local already = false
            for _, s in ipairs(E.selection) do if s == o then already = true end end
            if not already then E:select({ o }, input.shift) end
            self.drag = { kind = "move", x0 = gx, y0 = gy }
        else
            self.drag = { kind = "box", x0 = gx, y0 = gy }
        end
    end
    self:layout()
end

function EUI:drag_world(gx, gy)
    local E = self.E
    if E.stroke_now and self.clock - (self.last_stroke or 0) >= editor_ui.STROKE_EVERY then
        E:stroke(gx, gy)
        self.last_stroke = self.clock
    end
    if self.drag then self.drag.x1, self.drag.y1 = gx, gy end
end

function EUI:release_world(gx, gy, input)
    local E = self.E
    if E.stroke_now then E:stroke_end() end
    local d = self.drag
    self.drag = nil
    if d and gx and self.region and (d.kind == "region" or d.kind == "corner") then
        local r = self.region
        if (gx - d.x0) ^ 2 + (gy - d.y0) ^ 2 > 16 then
            if d.kind == "region" then
                E:move_region(r, gx - d.x0, gy - d.y0)
            else
                local nb = { left = r.left, bottom = r.bottom, right = r.right, top = r.top }
                nb[d.corner[1]], nb[d.corner[2]] = gx, gy
                E:set_region_bounds(r, nb.left, nb.bottom, nb.right, nb.top)
            end
        end
    elseif d and gx then
        if d.kind == "move" and ((gx - d.x0) ^ 2 + (gy - d.y0) ^ 2) > 16 then
            E:move_selection(gx - d.x0, gy - d.y0)
        elseif d.kind == "box" then
            if (gx - d.x0) ^ 2 + (gy - d.y0) ^ 2 > 400 then
                E:select(E:pick_rect(d.x0, d.y0, gx, gy), input.shift)
            elseif not input.shift then
                E:select({})
            end
        end
    end
    self:layout()
end
-- }}}

-- {{{ EUI:draw
function EUI:draw(ui)
    local E = self.E
    local function rect(x, y, w, h, c, a) ui.ui_rect(x, y, w, h, c[1], c[2], c[3], a or 255) end
    local function text(s, x, y, size, c) ui.ui_text(s, x, y, size, c[1], c[2], c[3], 255) end
    rect(0, 0, self.w, 38, C.panel, 235)
    if E:is_terrain_tool() or E.tool:match("^place") then rect(0, 38, 216, self.h - 66, C.panel, 220) end
    if #E.selection > 0 then rect(self.w - 216, 38, 216, self.h - 66, C.panel, 220) end
    rect(0, self.h - 28, self.w, 28, C.panel, 235)
    if self.tui then self.tui:draw(ui) end
    for _, b in ipairs(self.buttons) do
        rect(b.x, b.y, b.w, b.h, b.active and C.active or C.button)
        ui.ui_frame(b.x, b.y, b.w, b.h, 1, C.edge[1], C.edge[2], C.edge[3], 255)
        text(b.label, b.x + 6, b.y + 5, 13, C.text)
    end
    -- the selection
    if #E.selection > 0 then
        local o = E.selection[1]
        local x, y = self.w - 208, 46
        local lines = {
            #E.selection == 1 and (o.kind .. " " .. o.id) or (#E.selection .. " selected"),
            string.format("x %.0f  y %.0f", o.x, o.y),
            string.format("facing %.0f", math.deg(o.facing) % 360),
            o.scale and string.format("scale %.2f", o.scale) or "",
            o.player and ("player " .. o.player) or "",
        }
        for _, l in ipairs(lines) do text(l, x, y, 14, C.text); y = y + 20 end
    end
    -- the region in hand
    if E.tool == "regions" and self.region then
        local r = self.region
        text(string.format("region %s", r.name), 8, 46, 14, C.gold)
        text(string.format("%.0f, %.0f  to  %.0f, %.0f", r.left, r.bottom, r.right, r.top), 8, 66, 14, C.text)
    end
    -- the status line
    local ai_changed = next(E.dirty.ai or {}) ~= nil or E.dirty.imports
    local dirty = (E.dirty.terrain or E.dirty.doodads or E.dirty.units or E.dirty.script or ai_changed)
        and "  (unsaved)" or ""
    local where = self.ground and string.format("%.0f, %.0f", self.ground[1], self.ground[2]) or "-"
    local last = E.messages[#E.messages]
    text(string.format("%s | %s | %d objects | %d selected%s | undo: %s | %s", E.tool, where, #E:objects(),
        #E.selection, dirty, E.history:next_undo() or "-", last and last.text or ""), 8, self.h - 22, 14,
        dirty ~= "" and C.gold or C.dim)
end
-- }}}

return editor_ui
