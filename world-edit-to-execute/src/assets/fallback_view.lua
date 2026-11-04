--[[
Wire-frame Fallback in the Editor (Issue 602a)

What the editor hands the fallback (assets/fallback.lua): its units,
doodads, items, regions, cameras and ground, turned into the fallback's
plain objects; and two keys, F6 for forced wire-frame and F7 for the
debug overlay (each object's type, number and place).

    local fv = require("assets.fallback_view")
    local V = fv.new({ loader = L })   -- (fv.editor_object: the editor's records)
    V:key(viewer.keys())              -- F6 / F7 toggle; gives what changed
    V.F.force, V.F.overlay            -- what is on
    V:labels(objects)                 -- the overlay's labels for what is drawn for real
    local out = V:build({ objects = { fv.editor_object(o, z) },
                          regions = { fv.region(r) }, cameras = { fv.camera(c, ground_at) } })
    fallback.emit(out, render, true, 0)
    fallback.draw_labels(out.labels, render, viewer.to_screen)
    fv.terrain(E.terrain, ground_z)   -- the grid's input (a blank new map, or forced)
    fv.is_blank(E)                    -- a new map with nothing on it yet

Each converter takes the editor's own record and copies only what the
fallback reads, so nothing the fallback does can change a unit.

The map viewer (demo/wc3map) had F6 and F7 too, with fv.unit and
fv.doodad for its game's units and doodads, until 2026-11-04: served play
gives way to Test Map, and wire-frames for players are the W client's
(issue 602a, "After the editor-and-client split").
]]

local fallback = require("assets.fallback")

local fv = {}

fv.KEYS = { wire = "F6", overlay = "F7" }
fv.MAX_GRID_LINES = 20000     -- a larger map's grid draws every 2nd (4th ...) line

-- {{{ converters
-- A placed object of the editor (editor/objects.lua): a unit or doodad,
-- at Z (the ground under it; the editor keeps objects on the ground).
function fv.editor_object(o, z, selected)
    local doodad = o.kind == "doodad"
    return {
        doodad = doodad or nil,
        tree = doodad and (o.tree or (type(o.id) == "string" and o.id:match("^[A-Z]T") ~= nil)) or nil,
        kind = o.kind == "item" and "item" or nil,
        type_id = o.id, id = o.number or o.index,
        x = o.x, y = o.y, z = z, facing = o.facing,
        selected = selected or nil,
    }
end

-- A region of the editor (editor/regions.lua: left, bottom, right, top).
function fv.region(r)
    return { name = r.name, x1 = r.left, y1 = r.bottom, x2 = r.right, y2 = r.top }
end

-- A camera of the editor (editor/cameras.lua): it looks at (x, y) from
-- DISTANCE away, turned ROTATION degrees, tipped down by 360 - AOA
-- degrees, ZOFFSET above the ground. The fallback draws its eye, and a
-- line to what it looks at.
function fv.camera(c, ground_at)
    local d = c.distance or 1650
    local rot = math.rad(c.rotation or 90)
    local down = math.rad(360 - (c.aoa or 304))
    local flat, up = d * math.cos(down), d * math.sin(down)
    local tz = (ground_at and ground_at(c.x, c.y) or 0) + (c.zoffset or 0)
    return { name = c.name, x = c.x - math.cos(rot) * flat, y = c.y - math.sin(rot) * flat, z = tz + up,
             target_x = c.x, target_y = c.y }
end

-- The ground as the fallback's grid: tile points of a w3e terrain
-- (width, height in points; offset_x, offset_y), Z_AT(i, j) their height.
-- Every Nth line on a map whose grid would pass MAX_GRID_LINES.
function fv.terrain(t, z_at)
    local w, h = t.width - 1, t.height - 1
    local every = 1
    while (w / every + 1) * (h / every) + (h / every + 1) * (w / every) > fv.MAX_GRID_LINES do every = every * 2 end
    return { width = w - w % every, height = h - h % every, x0 = t.offset_x, y0 = t.offset_y, tile = 128,
             every = every, height_at = z_at }
end

-- A new map with nothing placed on it yet: no unit or doodad in its
-- placement files. (A new melee map's gold mines are made by its script,
-- so they don't count: the World Editor's new map looks empty too.)
function fv.is_blank(E)
    for _, o in ipairs(E.objs or {}) do
        if not o.deleted and o.kind ~= "script_unit" then return false end
    end
    return true
end
-- }}}

-- {{{ fv.new / V:key / V:build / V:status
local V = {}
V.__index = V

-- opts: loader, keys ({ wire, overlay }), force, overlay: as fallback.new.
function fv.new(opts)
    opts = opts or {}
    return setmetatable({
        F = fallback.new({ loader = opts.loader, force = opts.force, overlay = opts.overlay }),
        keys = opts.keys or fv.KEYS,
    }, V)
end

-- KEYS: the names pressed this frame (viewer.keys()). Gives "wire" or
-- "overlay" for the one toggled (the last, if both), or nil.
function V:key(keys)
    local changed
    for _, k in ipairs(keys or {}) do
        if k == self.keys.wire then
            self.F:force_wireframe(not self.F.force)
            changed = "wire"
        elseif k == self.keys.overlay then
            self.F:set_debug_overlay(not self.F.overlay)
            changed = "overlay"
        end
    end
    return changed
end

-- Is anything drawn the fallback way this frame?
function V:active()
    return self.F.force or self.F.overlay
end

-- The fallback's drawing of SCENE (as fallback's F:build takes it).
function V:build(scene)
    return self.F:build(scene)
end

-- The overlay's labels for OBJECTS drawn for real (models or designs),
-- where F:build labels only what it draws itself: each object's type,
-- number and place, over its head. Empty when the overlay is off.
function V:labels(objects, height)
    local out = {}
    if not self.F.overlay then return out end
    for _, obj in ipairs(objects) do
        local parts = {}
        if obj.type_id then parts[#parts + 1] = tostring(obj.type_id) end
        if obj.id then parts[#parts + 1] = "#" .. tostring(obj.id) end
        parts[#parts + 1] = string.format("(%d, %d)", math.floor(obj.x + 0.5), math.floor(obj.y + 0.5))
        out[#out + 1] = { x = obj.x, y = obj.y, z = (obj.z or 0) + (height or 140),
                          text = table.concat(parts, " "), color = { 200, 200, 200 } }
    end
    return out
end

-- One line for the corner: what is on, and which key turns it off.
function V:status()
    local on = {}
    if self.F.force then on[#on + 1] = "wire-frame (" .. self.keys.wire .. ")" end
    if self.F.overlay then on[#on + 1] = "overlay (" .. self.keys.overlay .. ")" end
    if #on == 0 then return nil end
    return "fallback: " .. table.concat(on, ", ")
end
-- }}}

return fv
