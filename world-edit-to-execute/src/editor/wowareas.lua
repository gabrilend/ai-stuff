--[[
Areas of a WoW Map's Own (Issue W10g)

A converted map (W02c) is one zone: its area id (AreaTable.dbc's row,
9000 + 10 x its slot) is in every chunk of its tiles, and its row is kept
in World/Maps/<dir>/registration.lua with the map's other table rows.
Here the map gets more areas of its own: each a row of AreaTable, made,
renamed and taken away as plain Lua and as editor steps with undo, and
painted onto chunks by W10f's area brush (editor/wowterrain.lua's
wt.area). A save writes the registration again and every form of the
folder's tables, as the converter does (wowbuild.output): the overlay's
DBFilesClient/AreaTable.dbc and the others, the server's SQL (and, with
the stock tables, the merged ones), and patch-W.MPQ.

    local ar = require("editor.wowareas")
    local reg, why = ar.load(m)                  -- the map's registration (W02c's), or nil and why
    ar.list(m)                                   -- { { id, name, parent, flags, bit, zone } } by id
    local row = ar.create(m, { name = "Hut Hollow", parent = zone, flags = { "town" } })
    ar.change(m, row.ID, { name = "...", flags = 0 })
    ar.delete(m, row.ID)                         -- refused while a chunk or an area uses it
    ar.save(m)                                   -- registration.lua and the folder's tables

The ids and bits are W02c's scheme (wowbuild.registration): a slot's area
block is 10 ids, the zone's and nine more (ids.area + 1 .. ids.area_last),
each with its own explored-zones bit (registration.subarea_bit).
]]

local registration = require("wowbuild.registration")

local ar = {}

ar.HEADER = "-- W02c: this map's registration (src/wowbuild/registration.lua): data only\nreturn "

-- AreaTable's Flags by name (3.3.5a's, from memory of TrinityCore's
-- DBCEnums.h AreaFlags: unchecked); a number is taken as it is
ar.FLAGS = {
    capital = 0x100, sanctuary = 0x800, town = 0x200000,
    rest_horde = 0x400000, rest_alliance = 0x800000, no_fly = 0x20000000,
}
ar.NAME_LIMIT = 120

-- {{{ helpers
local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
local function copy_rows(rows)
    local out = {}
    for i, r in ipairs(rows) do
        local c = {}
        for k, v in pairs(r) do c[k] = v end
        out[i] = c
    end
    return out
end
local function row_of(reg, id)
    for i, r in ipairs(reg.rows.AreaTable) do if r.ID == id then return r, i end end
end
local function flags_of(f)
    if f == nil then return 0 end
    if type(f) == "number" then
        if f ~= math.floor(f) or f < 0 or f > 0xFFFFFFFF then return nil, "flags: a whole number from 0 to 0xFFFFFFFF" end
        return f
    end
    if type(f) ~= "table" then return nil, "flags: a number or a list of names" end
    local n, seen = 0, {}
    for _, name in ipairs(f) do
        local v = ar.FLAGS[name]
        if not v then
            local names = {}
            for k in pairs(ar.FLAGS) do names[#names + 1] = k end
            table.sort(names)
            return nil, "flags: no flag " .. tostring(name) .. " (" .. table.concat(names, ", ") .. ", or a number)"
        end
        if not seen[name] then n = n + v seen[name] = true end
    end
    return n
end
local function clean_name(name)
    local s = registration.clean_text(name, ar.NAME_LIMIT)
    if s == "" then return nil, "an area needs a name" end
    return s
end
-- }}}

-- {{{ ar.load: the map's registration, kept on the map
function ar.load(m)
    if m.registration then return m.registration end
    local path = m.folder .. "/" .. registration.FILE
    local reg = read(path) and registration.read(path)
    if not reg then
        return nil, string.format("%s has no %s (W02c's): areas of its own can't be made; its chunks can still be "
            .. "set to any area number", m.directory, registration.FILE)
    end
    if type(reg.rows) ~= "table" or type(reg.rows.AreaTable) ~= "table" or type(reg.ids) ~= "table"
        or not reg.ids.area or not reg.ids.map then
        return nil, m.directory .. "/" .. registration.FILE .. ": no AreaTable rows or ids"
    end
    m.registration = reg
    return reg
end
-- }}}

-- {{{ ar.list
function ar.list(m)
    local reg, why = ar.load(m)
    if not reg then return nil, why end
    local out = {}
    for _, r in ipairs(reg.rows.AreaTable) do
        out[#out + 1] = { id = r.ID, name = r.AreaName, parent = r.ParentAreaID, flags = r.Flags, bit = r.AreaBit,
                          zone = r.ID == reg.ids.area }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end
-- }}}

-- {{{ the explored-zones bits in use: the stock table's, and every row of
-- every map of the folder (this map's as it is now)
local function used_bits(m, reg)
    local output = require("wowbuild.output")
    local stock_dir = output.stock_dir(m.opts and m.opts.stock_dbc)
    local used = (stock_dir and output.stock_area_bits(stock_dir)) or {}
    for dir, r in pairs(registration.in_build(m.root)) do
        if dir ~= m.directory then
            for _, row in ipairs(r.rows and r.rows.AreaTable or {}) do used[row.AreaBit] = true end
        end
    end
    for _, row in ipairs(reg.rows.AreaTable) do used[row.AreaBit] = true end
    return used
end
-- }}}

-- {{{ ar.create
-- o: name (one line, at most 120 characters), parent (the map's zone, the
-- default, or 0: a zone of its own), flags (a number or names of ar.FLAGS;
-- else 0). Returns the new row, or nil and why.
function ar.create(m, o)
    o = o or {}
    local reg, why = ar.load(m)
    if not reg then return nil, why end
    local name, nwhy = clean_name(o.name)
    if not name then return nil, nwhy end
    local ids = reg.ids
    local parent = o.parent
    if parent == nil then parent = ids.area end
    if parent ~= 0 and parent ~= ids.area then
        return nil, string.format("parent: the map's zone (%d) or 0 (a zone of its own)", ids.area)
    end
    local flags, fwhy = flags_of(o.flags)
    if not flags then return nil, fwhy end
    local id
    for k = 1, registration.SUBAREAS do
        if not row_of(reg, ids.area + k) then id = ids.area + k break end
    end
    if not id then
        return nil, string.format("%s has %d areas besides its zone, all its ids (%d-%d)", m.directory,
            registration.SUBAREAS, ids.area + 1, ids.area + registration.SUBAREAS)
    end
    local used = used_bits(m, reg)
    local bit = registration.subarea_bit(ids.slot or reg.slot or 0, id - ids.area)
    if used[bit] then
        bit = nil
        for b = registration.SUBAREA_BIT_TOP, 0, -1 do if not used[b] then bit = b break end end
        if not bit then return nil, "no free explored-zones bit (AreaBit) under 4096" end
    end
    local row = registration.area_row(ids, { id = id, bit = bit, name = name, parent = parent, flags = flags })
    local list = reg.rows.AreaTable
    list[#list + 1] = row
    table.sort(list, function(a, b) return a.ID < b.ID end)
    m.areas_dirty = true
    return row
end
-- }}}

-- {{{ ar.change: an area's name or flags
function ar.change(m, id, o)
    o = o or {}
    local reg, why = ar.load(m)
    if not reg then return nil, why end
    local row = row_of(reg, id)
    if not row then return nil, string.format("%s has no area %s of its own", m.directory, tostring(id)) end
    local name, flags = row.AreaName, row.Flags
    if o.name ~= nil then
        local nwhy
        name, nwhy = clean_name(o.name)
        if not name then return nil, nwhy end
    end
    if o.flags ~= nil then
        local fwhy
        flags, fwhy = flags_of(o.flags)
        if not flags then return nil, fwhy end
    end
    -- the zone renamed is its row only: the map keeps its own name (Map.dbc)
    row.AreaName, row.Flags = name, flags
    m.areas_dirty = true
    return row
end
-- }}}

-- {{{ ar.delete: an area taken away, when nothing uses it
function ar.delete(m, id)
    local reg, why = ar.load(m)
    if not reg then return nil, why end
    local row, i = row_of(reg, id)
    if not row then return nil, string.format("%s has no area %s of its own", m.directory, tostring(id)) end
    if id == reg.ids.area then return nil, "the map's zone can't be taken away (Map.dbc names it)" end
    for _, r in ipairs(reg.rows.AreaTable) do
        if r.ParentAreaID == id then
            return nil, string.format("area %d (%s) is inside it", r.ID, r.AreaName)
        end
    end
    local wt = require("editor.wowterrain")
    local all, awhy = wt.areas(m)
    if not all then return nil, awhy end
    for _, g in ipairs(all) do
        if g.area == id then
            return nil, string.format("%d chunks are in it (%s): paint them into another area first", g.chunks,
                table.concat(g.tiles, ", "))
        end
    end
    table.remove(reg.rows.AreaTable, i)
    m.areas_dirty = true
    return row
end
-- }}}

-- {{{ undo: the rows as they were
function ar.snapshot(m)
    local reg = m.registration
    return reg and { rows = copy_rows(reg.rows.AreaTable) } or {}
end
function ar.restore(m, s)
    local reg = m.registration
    if not reg or not s.rows then return end
    reg.rows.AreaTable = copy_rows(s.rows)
    m.areas_dirty = true
end
-- }}}

-- {{{ ar.save: the registration written again, then the folder's tables
-- Returns { files = { ... }, warnings = { ... } } (nothing when nothing
-- changed), or nil and why
function ar.save(m)
    if not m.areas_dirty or not m.registration then return { files = {}, warnings = {} } end
    local serialize = require("wowbuild").serialize
    local text = ar.HEADER .. serialize(m.registration) .. "\n"
    local path = m.folder .. "/" .. registration.FILE
    local tmp = path .. ".new"
    local f = io.open(tmp, "wb")
    if not f then return nil, "can't write " .. tmp end
    f:write(text)
    f:close()
    local ok, err = os.rename(tmp, path)
    if not ok then return nil, err end
    local files = {}
    local done, forms = pcall(require("wowbuild.output").write, m.root,
        { stock_dbc = m.opts and m.opts.stock_dbc, patch = m.opts and m.opts.patch, files = files })
    if not done then return nil, "the folder's tables: " .. tostring(forms) end
    m.areas_dirty = false
    m.forms = forms
    return { files = files, warnings = forms.warnings }
end
-- }}}

-- {{{ ar.attach: the editor's area steps (with undo)
-- E:wow_new_area(o) makes an area and has the area brush paint it
-- (brush.wow_area); E:wow_change_area(id, o), E:wow_delete_area(id)
function ar.attach(E)
    local function step(me, name, act)
        local m = me.wow_editing
        if not m then return nil, "no WoW map is being edited (E:wow_edit)" end
        local reg, why = ar.load(m)
        if not reg then me:say(why) return nil, why end
        local before = ar.snapshot(m)
        local got, gwhy = act(m)
        if not got then me:say(gwhy) return nil, gwhy end
        local after = ar.snapshot(m)
        me.history:record({ name = name .. " (WoW map " .. m.directory .. ")",
                            undo = function() ar.restore(m, before) me.dirty.wow = true end,
                            redo = function() ar.restore(m, after) me.dirty.wow = true end })
        me.dirty.wow = true
        return got
    end
    function E:wow_new_area(o)
        local row = step(self, "New area " .. tostring(o and o.name), function(m) return ar.create(m, o) end)
        if row then
            self.brush = self.brush or {}
            self.brush.wow_area = row.ID
            self:say(string.format("Area %d, %s: the area brush paints it", row.ID, row.AreaName))
        end
        return row
    end
    function E:wow_change_area(id, o) return step(self, "Change area " .. tostring(id), function(m) return ar.change(m, id, o) end) end
    function E:wow_delete_area(id) return step(self, "Delete area " .. tostring(id), function(m) return ar.delete(m, id) end) end
end
-- }}}

return ar
