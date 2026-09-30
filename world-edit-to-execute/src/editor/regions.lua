--[[
Editing Regions (Issue 904)

A map's regions are rects its script makes with literal calls
("set gg_rct_Arena = Rect(left, bottom, right, top)"; DAoW's protected
script makes its 81 so) and, for the World Editor, war3map.w3r (named,
with weather and ambient sound). The editor keeps each as a region: its
variable, its name (the w3r's when a w3r region has the same bounds, else
the variable's), its bounds, and where its Rect call stands in the
script.

  E:regions()                       every region
  E:region_at(x, y)                 the smallest region holding the point
  E:move_region(r, dx, dy)          one step to undo
  E:set_region_bounds(r, left, bottom, right, top)
  saving                            the Rect calls get the new numbers
                                    (editor/save.lua); the w3r, when the
                                    map has one, the new bounds

The script's regions aren't removed here: its triggers refer to them by
variable. New regions (E:new_region, E:delete_region) are the editor's
own, kept with the triggers in war3mapEditor.lua and made by
EditorInitRegions for the editor's triggers (issue 904b).

    require("editor.regions")(E)    -- editor/init.lua does this
]]

local w3r = require("parsers.w3r")
local mpq = require("mpq")

return function(E)

    local NUM = "(%-?[%d]*%.?[%d]*)"
    local RECT = "set%s+([%w_]+)%s*=%s*(Rect%(%s*" .. NUM .. "%s*,%s*" .. NUM .. "%s*,%s*" .. NUM .. "%s*,%s*" .. NUM .. "%s*%))"

    function E:load_regions()
        self.region_list = {}
        local a = mpq.open(self.path)
        local d = a and a:extract("war3map.w3r")
        if a then a:close() end
        self.w3r = d and w3r.parse(d) or nil
        if not self.script then return end
        local pos = 1
        while true do
            local s, e, var, call, l, b, r, t = self.script:find(RECT, pos)
            if not s then break end
            l, b, r, t = tonumber(l), tonumber(b), tonumber(r), tonumber(t)
            if l and b and r and t then
                local at = self.script:find("Rect", s, true)
                local reg = { kind = "region", var = var, name = var:gsub("^gg_rct_", ""), left = l, bottom = b,
                              right = r, top = t, at = at, to = e, orig = { l, b, r, t } }
                for _, wr in ipairs(self.w3r and self.w3r.regions or {}) do
                    local bb = wr.bounds
                    if math.abs(bb.left - l) < 1 and math.abs(bb.bottom - b) < 1 and math.abs(bb.right - r) < 1
                        and math.abs(bb.top - t) < 1 and not wr.claimed then
                        reg.name, reg.w3r, wr.claimed = wr.name, wr, true
                        break
                    end
                end
                self.region_list[#self.region_list + 1] = reg
            end
            pos = e + 1
        end
        -- the editor's own (kept with the triggers in war3mapEditor.lua)
        self.trig.regions = self.trig.regions or {}
        for _, r in ipairs(self.trig.regions) do
            r.kind, r.editor = "region", true
            self.region_list[#self.region_list + 1] = r
        end
    end

    function E:regions() return self.region_list or {} end

    -- a new region, for the triggers (made by EditorInitRegions)
    function E:new_region(name, l, b, rt, t)
        local blocks = require("editor.trigger_blocks")
        if rt < l then l, rt = rt, l end
        if t < b then b, t = t, b end
        local base, n = blocks.safe(name or "Region"), 1
        local var = "gg_rct_" .. base
        local function taken(v)
            for _, r in ipairs(self:regions()) do if r.var == v then return true end end
            return (self.script or ""):find(v, 1, true) ~= nil
        end
        while taken(var) do n = n + 1; var = "gg_rct_" .. base .. n end
        local r = { kind = "region", editor = true, var = var, name = var:gsub("^gg_rct_", ""),
                    left = l, bottom = b, right = rt, top = t }
        local list, kept, me = self.region_list, self.trig.regions, self
        self.history:run({ name = "New region " .. r.name,
            redo = function()
                list[#list + 1] = r; kept[#kept + 1] = r
                me.dirty.script, me.dirty.triggers, me.regions_changed = true, true, true
            end,
            undo = function()
                for i, x in ipairs(list) do if x == r then table.remove(list, i) break end end
                for i, x in ipairs(kept) do if x == r then table.remove(kept, i) break end end
                me.dirty.script, me.dirty.triggers, me.regions_changed = true, true, true
            end })
        return r
    end

    function E:delete_region(r)
        if not r.editor then return false, "the script's own regions stay (its triggers use them)" end
        local list, kept, me = self.region_list, self.trig.regions, self
        local at, kat
        for i, x in ipairs(list) do if x == r then at = i end end
        for i, x in ipairs(kept) do if x == r then kat = i end end
        if not at then return false end
        self.history:run({ name = "Delete region " .. r.name,
            redo = function()
                table.remove(list, at); if kat then table.remove(kept, kat) end
                me.dirty.script, me.dirty.triggers, me.regions_changed = true, true, true
            end,
            undo = function()
                table.insert(list, at, r); if kat then table.insert(kept, kat, r) end
                me.dirty.script, me.dirty.triggers, me.regions_changed = true, true, true
            end })
        return true
    end

    function E:region_code()
        local list = self.trig.regions or {}
        if #list == 0 then return nil end
        local g, f = {}, { "function EditorInitRegions takes nothing returns nothing" }
        for _, r in ipairs(list) do
            g[#g + 1] = "rect " .. r.var .. " = null"
            f[#f + 1] = string.format("    set %s = Rect(%.1f, %.1f, %.1f, %.1f)", r.var, r.left, r.bottom, r.right, r.top)
        end
        f[#f + 1] = "endfunction"
        return { globals = table.concat(g, "\n"), functions = table.concat(f, "\n"), call = "EditorInitRegions" }
    end

    function E:region_at(x, y)
        local best, area
        for _, r in ipairs(self:regions()) do
            if x >= r.left and x <= r.right and y >= r.bottom and y <= r.top then
                local a = (r.right - r.left) * (r.top - r.bottom)
                if not area or a < area then best, area = r, a end
            end
        end
        return best
    end

    local function put(self, r, l, b, rt, t)
        r.left, r.bottom, r.right, r.top = l, b, rt, t
        if r.w3r then
            local bb = r.w3r.bounds
            bb.left, bb.bottom, bb.right, bb.top = l, b, rt, t
            self.dirty.w3r = true
        end
        self.dirty.script = true
        if r.editor then self.dirty.triggers = true end
        self.regions_changed = true
    end

    function E:set_region_bounds(r, l, b, rt, t)
        if rt < l then l, rt = rt, l end
        if t < b then b, t = t, b end
        local old = { r.left, r.bottom, r.right, r.top }
        local me = self
        self.history:run({ name = "Region " .. r.name,
            redo = function() put(me, r, l, b, rt, t) end,
            undo = function() put(me, r, old[1], old[2], old[3], old[4]) end })
        return true
    end

    function E:move_region(r, dx, dy)
        return self:set_region_bounds(r, r.left + dx, r.bottom + dy, r.right + dx, r.top + dy)
    end

    -- the script's Rect calls with new numbers (save.lua gathers these)
    function E:region_edits()
        local out = {}
        for _, r in ipairs(self:regions()) do
            local o = r.orig or { r.left, r.bottom, r.right, r.top }   -- the editor's own: made, not edited
            if r.left ~= o[1] or r.bottom ~= o[2] or r.right ~= o[3] or r.top ~= o[4] then
                out[#out + 1] = { at = r.at, to = r.to, text = string.format("Rect(%.1f,%.1f,%.1f,%.1f)",
                    r.left, r.bottom, r.right, r.top) }
            end
        end
        return out
    end
end
