--[[
Saving the Edited Map (Issues 903, 911)

What changed, written back into a copy of the map (mpq.save_copy: in the
map's own archive, every other file as it was; the map opened is never
written):

  war3map.w3e       the terrain, when it changed
  war3map.wpm       the pathing map's cells under changed terrain: water
                    deep enough to swim in keeps walkers and builders off
                    and isn't land; dry ground is land again and, where it
                    was only water that kept them off, walkable and
                    buildable
  war3map.doo       the doodads, when any moved, came or went; a doodad
                    standing on changed terrain sits on the new ground
  war3mapUnits.doo  the placed units, when the map has that file and they
                    changed
  the script        units its CreateUnit calls make: moved ones' numbers
                    written in, deleted ones' calls taken out; and units
                    placed in the editor made by an added EditorPlacedUnits
                    function, called at the end of main

    require("editor.save")(E)     -- editor/init.lua does this
    E:save(path)                  -- true and a report, or nil and why
    E:files()                     -- { name = bytes } that would be written
]]

local w3e = require("parsers.w3e")
local doo = require("parsers.doo")
local unitsdoo = require("parsers.unitsdoo")
local mpq = require("mpq")

local save = {}
save.DEEP = 40                   -- water this far over the ground: no walking

local function num(v)
    local s = string.format("%.1f", v)
    return s
end

return function(E)

    -- {{{ the script
    function E:script_text()
        local text = self.script
        if not text then return nil end
        -- edits from the end, so earlier places stay put
        local edits = {}
        for _, o in ipairs(self.script_units) do
            local moved = o.x ~= o.orig.x or o.y ~= o.orig.y or math.abs(o.facing - o.orig.facing) > 1e-9
                or o.id ~= o.orig.id
            if o.deleted then
                local before = text:sub(1, o.at - 1)
                local call_prefix = before:match("call%s*$")
                edits[#edits + 1] = { at = o.at, to = o.to, text = call_prefix and "DoNothing()" or "null" }
            elseif moved then
                edits[#edits + 1] = { at = o.at, to = o.to, text = string.format("CreateUnit(%s,'%s',%s,%s,%s)",
                    o.who, o.id, num(o.x), num(o.y), num(math.deg(o.facing) % 360)) }
            end
        end
        -- regions' Rect calls (issue 904)
        for _, e in ipairs(self.region_edits and self:region_edits() or {}) do edits[#edits + 1] = e end
        table.sort(edits, function(a, b) return a.at > b.at end)
        for _, e in ipairs(edits) do text = text:sub(1, e.at - 1) .. e.text .. text:sub(e.to + 1) end
        -- units placed here: a function of their own, called at the end of main
        if #self.new_units > 0 then
            local lines = { "function EditorPlacedUnits takes nothing returns nothing" }
            for _, u in ipairs(self.new_units) do
                lines[#lines + 1] = string.format("call CreateUnit(Player(%d),'%s',%s,%s,%s)",
                    u.player, u.id, num(u.x), num(u.y), num(math.deg(u.facing) % 360))
            end
            lines[#lines + 1] = "endfunction"
            local fn = table.concat(lines, "\n") .. "\n"
            local ms, me = text:find("function%s+main%s+takes%s+nothing%s+returns%s+nothing")
            if not ms then return nil, "the script has no main function" end
            local es = text:find("endfunction", me + 1, true)
            if not es then return nil, "main never ends" end
            text = text:sub(1, ms - 1) .. fn .. text:sub(ms, es - 1) .. "\ncall EditorPlacedUnits()\n" .. text:sub(es)
        end
        return text
    end
    -- }}}

    -- {{{ the pathing map under changed terrain
    local function wpm_bytes(self)
        local pm = self.path_map
        if not pm or not next(self.terrain_touched or {}) then return nil end
        local t = self.terrain
        local ffi = require("ffi")
        local bytes = ffi.new("uint8_t[?]", #pm.bytes)
        ffi.copy(bytes, pm.bytes, #pm.bytes)
        local changed = false
        for k in pairs(self.terrain_touched) do
            local i, j = k % t.width, math.floor(k / t.width)
            local tp = t.tilepoints[j][i]
            local deep = tp.has_water and (w3e.water_z(tp) - w3e.ground_z(tp)) > save.DEEP
            local wet = tp.has_water and w3e.water_z(tp) > w3e.ground_z(tp)
            -- the 4 x 4 pathing cells about the tilepoint
            for cj = j * 4 - 2, j * 4 + 1 do
                for ci = i * 4 - 2, i * 4 + 1 do
                    if ci >= 0 and cj >= 0 and ci < pm.w and cj < pm.h then
                        local n = cj * pm.w + ci
                        local f = bytes[n]
                        local was = f
                        if wet then f = f - (math.floor(f / 0x40) % 2) * 0x40 else f = f + (1 - math.floor(f / 0x40) % 2) * 0x40 end
                        if deep then
                            if math.floor(f / 2) % 2 == 0 then f = f + 0x02 end
                            if math.floor(f / 8) % 2 == 0 then f = f + 0x08 end
                        elseif not wet and math.floor(was / 0x40) % 2 == 0 then
                            -- was water: open again
                            if math.floor(f / 2) % 2 == 1 then f = f - 0x02 end
                            if math.floor(f / 8) % 2 == 1 then f = f - 0x08 end
                        end
                        if f ~= was then bytes[n] = f; changed = true end
                    end
                end
            end
        end
        if not changed then return nil end
        return pm.header .. ffi.string(bytes, #pm.bytes)
    end
    -- }}}

    -- {{{ E:files, E:save
    function E:files()
        local files = {}
        if self.dirty.terrain then
            files["war3map.w3e"] = w3e.write(self.terrain)
            local wpm = wpm_bytes(self)
            if wpm then files["war3map.wpm"] = wpm end
            -- doodads on changed ground sit on the new ground
            local t = self.terrain
            for _, d in ipairs(self.doodads.doodads) do
                local i, j = self:tile_at(d.position.x, d.position.y)
                if i and self.terrain_touched[j * t.width + i] then
                    d.position.z = self:ground_z(d.position.x, d.position.y)
                    self.dirty.doodads = true
                end
            end
        end
        if self.dirty.doodads then files["war3map.doo"] = doo.write(self.doodads) end
        if self.dirty.units and self.units_doo then files["war3mapUnits.doo"] = unitsdoo.write(self.units_doo) end
        if self.object_files then self:object_files(files) end
        if self.dirty.w3r and self.w3r then files["war3map.w3r"] = require("parsers.w3r").write(self.w3r) end
        if (self.dirty.script or #self.new_units > 0) and self.script_name then
            local text, why = self:script_text()
            if not text then return nil, why end
            files[self.script_name] = text
        end
        return files
    end

    function E:save(path)
        local files, why = self:files()
        if not files then return nil, why end
        local ok, report = mpq.save_copy(self.path, path, files)
        if not ok then return nil, report end
        local n = 0
        for _ in pairs(files) do n = n + 1 end
        report.files = n
        self:say(string.format("Saved %s (%d files changed)", path, n))
        self.saved_to = path
        return true, report
    end
    -- }}}
end
