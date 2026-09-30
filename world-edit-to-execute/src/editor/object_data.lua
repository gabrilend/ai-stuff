--[[
Editing Object Types (Issue 906)

The map's changes to WC3's object types, as the World Editor's object
editor keeps them: per kind (units war3map.w3u, items w3t, destructibles
w3b, doodads w3d, abilities w3a, buffs w3h, upgrades w3q), a table of the
stock types the map changes and of its own custom types (each copying a
stock parent), each with its field changes (a four-letter field, a level
for levelled kinds, a value).

  fields     E:type_fields(kind, id) lists a type's changes;
             E:set_field(kind, id, field, value, level) changes or adds
             one (an integer, a real or a string: an existing change keeps
             its type, a new one takes the value's; opts var_type
             overrides), E:clear_field takes one out
  types      E:new_type(kind, parent) makes a custom type copying parent
             (its id the kind's letter and the next free three: h000,
             A000 ...); E:delete_type(kind, id) removes a custom one
  saving     each kind changed is written back (objectdata.write)

Every change is one step to undo. A kind the map doesn't change yet gets
a new, empty table.

    require("editor.object_data")(E)    -- editor/init.lua does this
]]

local objectdata = require("parsers.objectdata")
local mpq = require("mpq")

local EXT = { units = "w3u", items = "w3t", destructibles = "w3b", doodads = "w3d", abilities = "w3a",
              buffs = "w3h", upgrades = "w3q" }
local LETTER = { items = "I", destructibles = "B", doodads = "D", abilities = "A", buffs = "B", upgrades = "R" }

return function(E)

    -- {{{ tables
    function E:object_table(kind)
        self.object_tables = self.object_tables or {}
        local t = self.object_tables[kind]
        if t then return t end
        local ext = EXT[kind]
        if not ext then return nil end
        local levels = objectdata.FILE_CONFIG[ext].has_level_column
        local a = mpq.open(self.path)
        local d = a and a:extract("war3map." .. ext)
        if a then a:close() end
        t = d and objectdata.parse(d, { has_level_column = levels })
        if not t then
            t = setmetatable({ version = 2, original = {}, custom = {}, _by_id = {}, original_list = {},
                               custom_list = {}, has_level_column = levels, tail_raw = "" },
                             { __index = objectdata.ObjectDataTable })
        end
        self.object_tables[kind] = t
        return t
    end
    E.OBJECT_KINDS = EXT
    -- }}}

    -- {{{ fields
    function E:type_fields(kind, id)
        local t = self:object_table(kind)
        local o = t and t._by_id[id]
        return o and o.modifications or {}
    end

    local function entry_for(t, id)
        local o = t._by_id[id]
        if o then return o end
        -- a stock type the map didn't change yet
        o = { id = id, original_id = id, modifications = {} }
        t.original_list[#t.original_list + 1] = o
        t.original[id], t._by_id[id] = o, o
        return o
    end

    local function find(o, field, level)
        for i, m in ipairs(o.modifications) do
            if m.field_id == field and (level == nil or (m.level or 0) == level) then return m, i end
        end
    end

    function E:set_field(kind, id, field, value, level, opts)
        local t = self:object_table(kind)
        if not t then return false, "no such kind" end
        local o = entry_for(t, id)
        local m = find(o, field, level)
        local me = self
        local cmd
        if m then
            local old = m.value
            cmd = { name = string.format("%s %s: %s", id, field, tostring(value)),
                    redo = function() m.value = value; me.dirty.objects[kind] = true end,
                    undo = function() m.value = old; me.dirty.objects[kind] = true end }
        else
            local vt = opts and opts.var_type
            if not vt then
                if type(value) == "string" then vt = objectdata.VAR_TYPE.STRING
                elseif math.floor(value) == value and not (opts and opts.real) then vt = objectdata.VAR_TYPE.INT
                else vt = objectdata.VAR_TYPE.REAL end
            end
            local new = { field_id = field, var_type = vt, level = level or 0, column = 0, value = value,
                          source_id = o.id }
            cmd = { name = string.format("%s %s: %s", id, field, tostring(value)),
                    redo = function() o.modifications[#o.modifications + 1] = new; me.dirty.objects[kind] = true end,
                    undo = function()
                        for i, x in ipairs(o.modifications) do if x == new then table.remove(o.modifications, i) break end end
                        me.dirty.objects[kind] = true
                    end }
        end
        self.history:run(cmd)
        return true
    end

    function E:clear_field(kind, id, field, level)
        local t = self:object_table(kind)
        local o = t and t._by_id[id]
        local m, i = o and find(o, field, level)
        if not m then return false end
        local me = self
        self.history:run({ name = id .. " " .. field .. " cleared",
            redo = function()
                for k, x in ipairs(o.modifications) do if x == m then table.remove(o.modifications, k) break end end
                me.dirty.objects[kind] = true
            end,
            undo = function() table.insert(o.modifications, math.min(i, #o.modifications + 1), m); me.dirty.objects[kind] = true end })
        return true
    end
    -- }}}

    -- {{{ custom types
    function E:new_type(kind, parent)
        local t = self:object_table(kind)
        if not t then return nil, "no such kind" end
        local letter = LETTER[kind] or parent:sub(1, 1)
        local id
        for n = 0, 36 * 36 * 36 - 1 do
            local digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            local a = math.floor(n / 1296) % 36 + 1
            local b = math.floor(n / 36) % 36 + 1
            local c = n % 36 + 1
            local cand = letter .. digits:sub(a, a) .. digits:sub(b, b) .. digits:sub(c, c)
            if not t._by_id[cand] then id = cand break end
        end
        if not id then return nil, "no free id" end
        local o = { id = id, new_id = id, original_id = parent, parent_id = parent, modifications = {} }
        local me = self
        self.history:run({ name = "New " .. kind .. " " .. id .. " (from " .. parent .. ")",
            redo = function()
                t.custom_list[#t.custom_list + 1] = o
                t.custom[id], t._by_id[id] = o, o
                me.dirty.objects[kind] = true
            end,
            undo = function()
                for i, x in ipairs(t.custom_list) do if x == o then table.remove(t.custom_list, i) break end end
                t.custom[id], t._by_id[id] = nil, nil
                me.dirty.objects[kind] = true
            end })
        return id
    end

    function E:delete_type(kind, id)
        local t = self:object_table(kind)
        local o = t and t.custom[id]
        if not o then return false, "not a custom type" end
        local at
        for i, x in ipairs(t.custom_list) do if x == o then at = i end end
        local me = self
        self.history:run({ name = "Delete " .. kind .. " " .. id,
            redo = function()
                table.remove(t.custom_list, at)
                t.custom[id], t._by_id[id] = nil, nil
                me.dirty.objects[kind] = true
            end,
            undo = function()
                table.insert(t.custom_list, at, o)
                t.custom[id], t._by_id[id] = o, o
                me.dirty.objects[kind] = true
            end })
        return true
    end
    -- }}}

    -- {{{ what saving writes
    function E:object_files(files)
        for kind, changed in pairs(self.dirty.objects) do
            if changed then files["war3map." .. EXT[kind]] = objectdata.write(self:object_table(kind)) end
        end
        return files
    end
    -- }}}
end
