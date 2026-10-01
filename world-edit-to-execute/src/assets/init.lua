--[[
Assets: Where a Map's Art Comes From (Issue 522d)

Reads files the way the game does: the map's own archive first (maps
import models and textures over stock ones), then the owner's install
through the game data chain (gamedata/chain.lua: patch layer, then
War3xlocal, War3x, war3). Nothing from an install is copied anywhere:
it's read when the game runs.

  install   opts.install, else $WC3_INSTALL, else <root>/wc3-installs/frozen-throne
            (with <root>/wc3-installs/patch-layers). Without one, only
            what the map imports is found; the rest falls back to the
            engine's geometry designs.

And which model a type of object uses: its object data where the map
sets it (umdl, dfil, bfil), else its stock parent's, else the stock
tables (UnitUI.slk, Doodads.slk, DestructableData.slk).

    local assets = require("assets")
    local A = assets.open("assets/DAoW-5.4b-PUBLIC-TEST.w3x", { root = ROOT })
    local bytes, where = A:read("Textures\\Footman.blp")
    local img = A:texture("Textures\\Footman.blp")      -- { width, height, rgba } or nil
    local m, path = A:model_for("unit", "hfoo")          -- parsed MDX or nil, and its path
    A:report()                                           -- found / missing counts
]]

local mpq = require("mpq")
local blp = require("parsers.blp")
local tga = require("parsers.tga")
local mdx = require("parsers.mdx")

local assets = {}

local A = {}
A.__index = A

local function exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    local ok = os.execute('test -e "' .. path .. '"')
    return ok == true or ok == 0
end

-- "units/Human/Footman/Footman.mdl" -> "units\Human\Footman\Footman.mdx"
function assets.model_path(p)
    if type(p) ~= "string" or p == "" then return nil end
    p = p:gsub("/", "\\")
    local low = p:lower()
    if low:match("%.mdl$") then return p:sub(1, -5) .. ".mdx" end
    if low:match("%.mdx$") then return p end
    return p .. ".mdx"
end

-- {{{ assets.open
function assets.open(map_path, opts)
    opts = opts or {}
    local self = setmetatable({ map_path = map_path, textures = {}, models = {}, tables = {},
                                found = 0, missing = {}, sources = {} }, A)
    local ok, archive = pcall(mpq.open, map_path)
    if ok then self.map = archive end

    -- the install, when there is one
    local root = opts.root or "."
    local install = opts.install or os.getenv("WC3_INSTALL") or (root .. "/wc3-installs/frozen-throne")
    local layers = opts.layers or os.getenv("WC3_LAYERS") or (root .. "/wc3-installs/patch-layers")
    if install and exists(install .. "/war3.mpq") then
        local w3i
        if self.map and self.map:has("war3map.w3i") then
            local wok, parsed = pcall(function() return require("parsers.w3i").parse(self.map:extract("war3map.w3i")) end)
            if wok then w3i = parsed end
        end
        local chain_mod = require("gamedata.chain")
        -- the map's own patch layer; failing that (not built, unknown
        -- editor build), the install as it is: art rarely changes by patch
        local cok, chain = pcall(chain_mod.open, { install = install, layers = exists(layers) and layers or nil,
                                                   w3i = w3i, map = map_path })
        if not cok then
            self.chain_note = "no patch layer (" .. tostring(chain) .. "); reading the install unpatched"
            cok, chain = pcall(chain_mod.open, { install = install, w3i = w3i, map = map_path, layer = false })
        end
        if cok then
            self.chain = chain
        else
            self.chain_error = tostring(chain)
        end
    end
    self.install = self.chain and install or nil
    return self
end
-- }}}

-- {{{ A:read
-- The bytes of a file, and where they came from ("map" or an archive)
function A:read(path)
    path = path:gsub("/", "\\")
    if self.map and self.map:has(path) then
        local ok, data = pcall(self.map.extract, self.map, path)
        if ok and data then return data, "map" end
    end
    if self.chain then
        local ok, data, source = pcall(self.chain.read, self.chain, path, { below_map = true })
        if ok and data then return data, source end
    end
    return nil
end
-- }}}

-- {{{ A:texture
-- A decoded texture (BLP or TGA), cached; nil when missing or unreadable
function A:texture(path)
    if not path or path == "" then return nil end
    local key = path:lower():gsub("/", "\\")
    local hit = self.textures[key]
    if hit ~= nil then return hit or nil end
    local data = self:read(path)
    if not data and not key:match("%.blp$") and not key:match("%.tga$") then data = self:read(path .. ".blp") end
    if not data and key:match("%.tga$") then data = self:read(path:sub(1, -5) .. ".blp") end
    local img
    if data then
        local ok, res
        if data:sub(1, 4) == "BLP1" then ok, res = pcall(blp.decode, data)
        else ok, res = pcall(tga.decode, data) end
        if ok then img = res else self.missing[#self.missing + 1] = path .. " (" .. tostring(res) .. ")" end
    else
        self.missing[#self.missing + 1] = path
    end
    self.textures[key] = img or false
    if img then self.found = self.found + 1 end
    return img
end
-- }}}

-- {{{ A:model
-- A parsed MDX, cached; nil when missing or unreadable
function A:model(path)
    path = assets.model_path(path)
    if not path then return nil end
    local key = path:lower()
    local hit = self.models[key]
    if hit ~= nil then return hit or nil end
    local data = self:read(path)
    local m
    if data then
        local ok, res = pcall(mdx.parse, data)
        if ok then m = res else self.missing[#self.missing + 1] = path .. " (" .. tostring(res) .. ")" end
    else
        self.missing[#self.missing + 1] = path
    end
    self.models[key] = m or false
    if m then self.found = self.found + 1 end
    return m
end
-- }}}

-- {{{ Stock tables
-- A stock SLK table through the install, parsed (nil without an install)
function A:table(path)
    if self.tables[path] ~= nil then return self.tables[path] or nil end
    local t
    if self.chain then
        local ok, data = pcall(self.chain.read, self.chain, path)
        if ok and data then t = require("parsers.slk").parse(data) end
    end
    self.tables[path] = t or false
    return t
end

local KIND = {
    unit = { od = "units", field = "umdl", slk = "Units\\UnitUI.slk", column = "file", scale_field = "usca",
             scale_column = "modelScale" },
    doodad = { od = "doodads", field = "dfil", slk = "Doodads\\Doodads.slk", column = "file", vars = "numVar",
               scale_column = "defScale" },
    destructable = { od = "destructibles", field = "bfil", slk = "Units\\DestructableData.slk", column = "file",
                     vars = "numVar" },
}
-- }}}

-- {{{ A:model_for
-- The model of an object type: (parsed MDX, path) or nil. kind: "unit",
-- "doodad", "destructable", or "placed" (a war3map.doo entry: either).
-- object_data: the map's (data.lua's m.object_data), for its own changes.
function A:model_for(kind, id, variation, object_data)
    -- a placed doodad is a destructable or a doodad by which table has it
    if kind == "placed" then
        local m, p = self:model_for("destructable", id, variation, object_data)
        if m then return m, p end
        return self:model_for("doodad", id, variation, object_data)
    end
    local k = KIND[kind]
    if not k then return nil end
    local file, vars
    -- the map's own setting, on the object or its stock parent
    local t = object_data and object_data[k.od]
    local look = id
    for _ = 1, 4 do
        if t and t:has(look) then
            local v = t:get_modification(look, k.field)
            if type(v) == "string" and v ~= "" then file = v break end
            local parent = t:get_parent(look)
            parent = type(parent) == "table" and (parent.id or parent.original_id) or parent
            if not parent or parent == look then break end
            look = parent
        else
            break
        end
    end
    -- else the stock tables
    local stock = self:table(k.slk)
    local row = stock and stock.rows and stock.rows[look]
    if not file and row then file = row[k.column] end
    if row and k.vars then vars = tonumber(row[k.vars]) end
    if not file then return nil end
    file = tostring(file):gsub("%.mdl$", ""):gsub("%.MDL$", ""):gsub("%.mdx$", "")
    -- doodads with variations keep one model file per variation
    local tries = {}
    if variation and (vars or 0) > 1 then tries[#tries + 1] = file .. variation end
    tries[#tries + 1] = file
    if variation then tries[#tries + 1] = file .. variation end
    for _, p in ipairs(tries) do
        local m = self:model(p)
        if m then return m, assets.model_path(p) end
    end
    return nil, assets.model_path(file)
end

-- The type's model scale (stock modelScale / defScale, or the map's usca)
function A:scale_for(kind, id, object_data)
    if kind == "placed" then
        local d = self:scale_for("doodad", id, object_data)
        return d
    end
    local k = KIND[kind]
    local t = object_data and object_data[k.od]
    if t and k.scale_field and t:has(id) then
        local v = t:get_modification(id, k.scale_field)
        if tonumber(v) then return tonumber(v) end
    end
    local stock = self:table(k.slk)
    local row = stock and stock.rows and stock.rows[id]
    return row and tonumber(row[k.scale_column or ""]) or 1
end
-- }}}

-- {{{ A:report
function A:report()
    local models, textures = 0, 0
    for _, v in pairs(self.models) do if v then models = models + 1 end end
    for _, v in pairs(self.textures) do if v then textures = textures + 1 end end
    return { install = self.install, chain_error = self.chain_error, chain_note = self.chain_note,
             models = models, textures = textures,
             missing = #self.missing }
end
-- }}}

function A:close()
    if self.map then self.map:close() end
    if self.chain then self.chain:close() end
end

return assets
