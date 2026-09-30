--[[
Placing Objects (Issue 903)

The map's objects as the editor keeps them, one kind of record for all:

  doodad       a war3map.doo entry (trees, rocks, destructibles)
  unit         a war3mapUnits.doo entry (when the map has that file)
  script_unit  a unit the map's script makes with a literal
               CreateUnit(player, 'id', x, y, facing) call: where the call
               stands in the script is kept, so moving the unit writes new
               numbers into the call and deleting it takes the call out
               ("set u = null" for "set u = CreateUnit(...)", else
               DoNothing()). DAoW's protected script places its units so
  new_unit     a unit placed in the editor: saved into war3mapUnits.doo
               (when the map has one) and made by an EditorPlacedUnits
               function the save adds to the script and calls at the end
               of main

Every object has x, y, facing (radians), an id and a kind; doodads also a
scale and variation; units a player.

    E:objects()                          -- every object
    E:pick(x, y, r)                      -- the nearest within r
    E:place_doodad(id, x, y, opts), E:place_unit(id, player, x, y, facing)
    E:select({ ... }, add), E:move_selection(dx, dy), E:rotate_selection(da)
    E:scale_selection(k), E:delete_selection(), E:copy(), E:paste(x, y)

    require("editor.objects")(E)         -- editor/init.lua does this
]]

local map_scene = require("demo.wc3map.scene")

return function(E)

    -- {{{ loading
    local NUM = "(%-?[%d]*%.?[%d]*)"
    local CALL = "CreateUnit%(%s*([^,%(%)]-)%s*,%s*'(....)'%s*,%s*" .. NUM .. "%s*,%s*" .. NUM .. "%s*,%s*" .. NUM .. "%s*%)"

    -- the player a script expression names ("Player(3)", or a variable
    -- last set to one before the call)
    local function scan_players(script)
        local sets = {}
        local pos = 1
        while true do
            local s, e, var, arg = script:find("set%s+([%w_]+)%s*=%s*Player%(([^%)]+)%)", pos)
            if not s then break end
            sets[#sets + 1] = { at = s, var = var, player = map_scene.player_number(arg) }
            pos = e + 1
        end
        return sets
    end

    function E:load_objects()
        self.objs = {}
        for _, d in ipairs(self.doodads.doodads) do
            self.objs[#self.objs + 1] = { kind = "doodad", entry = d, id = d.id, x = d.position.x, y = d.position.y,
                                          facing = d.angle or 0, scale = d.scale.x or 1, variation = d.variation or 0 }
        end
        for _, u in ipairs(self.units_doo and self.units_doo.units or {}) do
            self.objs[#self.objs + 1] = { kind = "unit", entry = u, id = u.id, x = u.position.x, y = u.position.y,
                                          facing = u.angle or 0, player = u.player }
        end
        self.script_units = {}
        if self.script then
            local sets = scan_players(self.script)
            local pos = 1
            while true do
                local s, e, who, id, x, y, f = self.script:find(CALL, pos)
                if not s then break end
                local nx, ny, nf = tonumber(x), tonumber(y), tonumber(f)
                if nx and ny and nf then
                    local player = map_scene.player_number((who:match("^Player%((.+)%)$")) or "")
                    if not who:match("^Player%(") then
                        player = nil
                        for _, st in ipairs(sets) do
                            if st.at < s and st.var == who then player = st.player end
                        end
                    end
                    local o = { kind = "script_unit", id = id, who = who, x = nx, y = ny, facing = math.rad(nf),
                                player = player or 15, at = s, to = e,
                                orig = { x = nx, y = ny, facing = math.rad(nf), id = id } }
                    self.objs[#self.objs + 1] = o
                    self.script_units[#self.script_units + 1] = o
                end
                pos = e + 1
            end
        end
        self.new_units = {}
        self.next_creation = 0
        for _, d in ipairs(self.doodads.doodads) do self.next_creation = math.max(self.next_creation, d.creation_number or 0) end
        for _, u in ipairs(self.units_doo and self.units_doo.units or {}) do
            self.next_creation = math.max(self.next_creation, u.creation_number or 0)
        end
    end

    function E:objects()
        local out = {}
        for _, o in ipairs(self.objs) do if not o.deleted then out[#out + 1] = o end end
        return out
    end
    -- }}}

    -- {{{ writing an object's place into what the map keeps
    local function sync(o)
        local e = o.entry
        if e then
            e.position.x, e.position.y, e.angle = o.x, o.y, o.facing
            if o.kind == "doodad" then
                e.scale.x, e.scale.y, e.scale.z = o.scale, o.scale, o.scale
                e.variation = o.variation
            end
        end
    end
    local function mark(self, o)
        if o.kind == "doodad" then self.dirty.doodads = true
        elseif o.kind == "unit" then self.dirty.units = true
        elseif o.kind == "script_unit" then self.dirty.script = true
        elseif o.kind == "new_unit" then self.dirty.units, self.dirty.script = true, true end
        self.objects_changed = true
    end
    -- }}}

    -- {{{ picking and selecting
    function E:pick(x, y, r)
        r = r or 96
        local best, bd = nil, r * r
        for _, o in ipairs(self.objs) do
            if not o.deleted then
                local d = (o.x - x) ^ 2 + (o.y - y) ^ 2
                if d <= bd then best, bd = o, d end
            end
        end
        return best
    end

    function E:pick_rect(x0, y0, x1, y1)
        if x0 > x1 then x0, x1 = x1, x0 end
        if y0 > y1 then y0, y1 = y1, y0 end
        local out = {}
        for _, o in ipairs(self.objs) do
            if not o.deleted and o.x >= x0 and o.x <= x1 and o.y >= y0 and o.y <= y1 then out[#out + 1] = o end
        end
        return out
    end

    function E:select(list, add)
        if not add then self.selection = {} end
        local seen = {}
        for _, o in ipairs(self.selection) do seen[o] = true end
        for _, o in ipairs(list or {}) do
            if not seen[o] then self.selection[#self.selection + 1] = o; seen[o] = true end
        end
        return self.selection
    end
    -- }}}

    -- {{{ changing the selection (each one step to undo)
    local function change(self, name, list, fn)
        local before, after = {}, {}
        for i, o in ipairs(list) do before[i] = { x = o.x, y = o.y, facing = o.facing, scale = o.scale } end
        for _, o in ipairs(list) do fn(o) end
        for i, o in ipairs(list) do after[i] = { x = o.x, y = o.y, facing = o.facing, scale = o.scale } end
        local me = self
        local function put(which)
            for i, o in ipairs(list) do
                local s = which[i]
                o.x, o.y, o.facing, o.scale = s.x, s.y, s.facing, s.scale
                sync(o)
                mark(me, o)
            end
        end
        put(after)
        self.history:record({ name = name, redo = function() put(after) end, undo = function() put(before) end })
    end

    function E:move_selection(dx, dy)
        if #self.selection == 0 then return false end
        local list = { unpack(self.selection) }
        change(self, "Move " .. #list .. (#list == 1 and " object" or " objects"), list,
            function(o) o.x, o.y = o.x + dx, o.y + dy end)
        return true
    end

    function E:rotate_selection(da)
        if #self.selection == 0 then return false end
        local list = { unpack(self.selection) }
        change(self, "Turn " .. #list, list, function(o) o.facing = (o.facing + da) % (2 * math.pi) end)
        return true
    end

    function E:scale_selection(k)
        local list = {}
        for _, o in ipairs(self.selection) do if o.kind == "doodad" then list[#list + 1] = o end end
        if #list == 0 then return false end
        change(self, "Scale " .. #list, list, function(o) o.scale = math.max(0.1, math.min(10, o.scale * k)) end)
        return true
    end

    local function set_deleted(self, list, flag)
        for _, o in ipairs(list) do
            o.deleted = flag
            if o.kind == "doodad" or o.kind == "unit" or o.kind == "new_unit" then
                -- out of (or back into) the table the map keeps
                local tbl = (o.kind == "doodad" and self.doodads.doodads)
                    or (o.kind == "unit" and self.units_doo.units) or self.new_units
                local item = o.entry or o
                if flag then
                    for i, x in ipairs(tbl) do if x == item then table.remove(tbl, i) break end end
                else
                    tbl[#tbl + 1] = item
                end
                if o.kind == "new_unit" and o.doo_entry and self.units_doo then
                    local u = self.units_doo.units
                    if flag then
                        for i, x in ipairs(u) do if x == o.doo_entry then table.remove(u, i) break end end
                    else
                        u[#u + 1] = o.doo_entry
                    end
                end
            end
            mark(self, o)
        end
    end

    function E:delete_selection()
        local list = { unpack(self.selection) }
        if #list == 0 then return false end
        set_deleted(self, list, true)
        self.selection = {}
        local me = self
        self.history:record({ name = "Delete " .. #list,
            redo = function() set_deleted(me, list, true) end,
            undo = function() set_deleted(me, list, false) end })
        return true
    end
    -- }}}

    -- {{{ a different type for the selection (a custom one, say)
    function E:set_type_of_selection(id)
        local list = { unpack(self.selection) }
        if #list == 0 then return false end
        local before = {}
        for i, o in ipairs(list) do before[i] = o.id end
        local me = self
        local function put(ids)
            for i, o in ipairs(list) do
                o.id = ids[i] or ids[1]
                if o.entry then o.entry.id = o.id end
                if o.doo_entry then o.doo_entry.id = o.id end
                mark(me, o)
            end
        end
        put({ id })
        self.history:record({ name = "Type " .. id .. " for " .. #list,
            redo = function() put({ id }) end, undo = function() put(before) end })
        return true
    end
    -- }}}

    -- {{{ placing
    local function add_object(self, o, name)
        self.objs[#self.objs + 1] = o
        o.deleted = true
        set_deleted(self, { o }, false)
        local me = self
        self.history:record({ name = name,
            redo = function() set_deleted(me, { o }, false) end,
            undo = function() set_deleted(me, { o }, true) end })
        return o
    end

    function E:place_doodad(id, x, y, opts)
        opts = opts or {}
        self.next_creation = self.next_creation + 1
        local s = opts.scale or 1
        local d = { id = id, variation = opts.variation or 0, position = { x = x, y = y, z = self:ground_z(x, y) },
                    angle = opts.facing or 0, scale = { x = s, y = s, z = s }, flags = 2, life = 100,
                    creation_number = self.next_creation, item_table_pointer = -1, item_sets_count = 0 }
        local o = { kind = "doodad", entry = d, id = id, x = x, y = y, facing = d.angle, scale = s,
                    variation = d.variation }
        return add_object(self, o, "Place " .. id)
    end

    local function unitsdoo_template_ok(self, id)
        local hero = id:sub(1, 1):match("%u") ~= nil
        return require("parsers.unitsdoo").template(self.units_doo, hero) ~= nil
    end

    function E:place_unit(id, player, x, y, facing)
        local o = { kind = "new_unit", id = id, player = player or 0, x = x, y = y, facing = facing or math.rad(270) }
        -- into war3mapUnits.doo too, when the map has one to copy from
        if self.units_doo and unitsdoo_template_ok(self, id) then
            self.next_creation = self.next_creation + 1
            o.doo_entry = { id = id, variation = 0, position = { x = x, y = y, z = self:ground_z(x, y) },
                            angle = o.facing, scale = { x = 1, y = 1, z = 1 }, flags = 2, player = o.player,
                            creation_number = self.next_creation }
        end
        return add_object(self, o, "Place " .. id)
    end
    -- }}}

    -- {{{ the clipboard
    function E:copy()
        if #self.selection == 0 then return false end
        local cx, cy = 0, 0
        for _, o in ipairs(self.selection) do cx, cy = cx + o.x, cy + o.y end
        cx, cy = cx / #self.selection, cy / #self.selection
        local list = {}
        for _, o in ipairs(self.selection) do
            list[#list + 1] = { kind = o.kind, id = o.id, dx = o.x - cx, dy = o.y - cy, facing = o.facing,
                                scale = o.scale, variation = o.variation, player = o.player }
        end
        self.clipboard = list
        return true
    end

    function E:paste(x, y)
        if not self.clipboard then return {} end
        local made = {}
        self.history:begin("Paste " .. #self.clipboard)
        for _, c in ipairs(self.clipboard) do
            if c.kind == "doodad" then
                made[#made + 1] = self:place_doodad(c.id, x + c.dx, y + c.dy,
                    { facing = c.facing, scale = c.scale, variation = c.variation })
            else
                made[#made + 1] = self:place_unit(c.id, c.player, x + c.dx, y + c.dy, c.facing)
            end
        end
        self.history:finish()
        self:select(made)
        return made
    end
    -- }}}

    -- {{{ palettes: the types this map uses
    function E:doodad_types()
        local seen, out = {}, {}
        for _, d in ipairs(self.doodads.doodads) do
            if not seen[d.id] then seen[d.id] = true; out[#out + 1] = d.id end
        end
        table.sort(out)
        return out
    end
    function E:unit_types()
        local seen, out = {}, {}
        for _, o in ipairs(self.objs) do
            if (o.kind == "unit" or o.kind == "script_unit") and not seen[o.id] then seen[o.id] = true; out[#out + 1] = o.id end
        end
        table.sort(out)
        return out
    end
    -- }}}
end
