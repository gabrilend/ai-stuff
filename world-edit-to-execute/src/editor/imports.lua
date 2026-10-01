--[[
The Import Manager (Issue 908)

The files a map carries beyond its own (war3map.*): models, textures,
sounds, scripts, data. Protected maps strip their listfile (DAoW 5.4b's
201 files have no names), so names are found the way the game finds
them: every path the map refers to (its object types' strings, its
script's strings, the textures its models name), tried with the usual
variants (.mdl as .mdx, war3mapImported\ in front, .blp for .tga); a
file still unnamed keeps StormLib's name ("File00000041.mdx").

Each file: its name, size, kind (model, texture, sound, script, data,
other), what uses it (the object type fields and script that name it)
and whether it reads as its kind (validation). Changes are kept until
saving, each one step to undo:

  E:load_imports()                 finds the names; the list
  E:imports()                      { name, size, kind, unnamed, users, added } ...
  E:import_bytes(bytes, name)      a new file, or one replaced
  E:import_file(path, name)        the same from a file on disk
  E:delete_import(name)
  E:rename_import(old, new)        (an unnamed file too: it gets the name)
  E:import_data(name)              the bytes, as they'll be saved
  E:export_import(name, path)      written to disk
  E:validate_import(name)          { status = "ok" | "warn" | "error", message }
  E:unused_imports()               files nothing found names
  E:import_files(files)            what saving writes (bytes, or false: taken out)

    require("editor.imports")(E)    -- editor/init.lua does this
]]

local mpq = require("mpq")
local standard = require("mpq.standard_names")

local imports = {}

imports.KINDS = {
    mdx = "model", mdl = "model", blp = "texture", tga = "texture", dds = "texture", png = "texture",
    wav = "sound", mp3 = "sound", ogg = "sound", flac = "sound", j = "script", ai = "script", lua = "script",
    txt = "data", slk = "data", fdf = "data", toc = "data", ttf = "font", otf = "font",
}
imports.ORDER = { "model", "texture", "sound", "script", "data", "font", "other" }

-- the map's own files (not imports)
local OWN = {}
for _, n in ipairs(standard.MAP_FILES) do OWN[n:lower()] = true end
for _, n in ipairs({ "(listfile)", "(attributes)", "(signature)", "war3map.j", "scripts\\war3map.j",
                     "war3mapeditor.lua" }) do OWN[n] = true end

function imports.kind_of(name)
    local ext = name:match("%.([%w]+)$")
    return imports.KINDS[ext and ext:lower() or ""] or "other"
end

function imports.is_own(name)
    local low = name:lower()
    return OWN[low] or low:match("^war3mapai\\") ~= nil
end

-- {{{ names a map refers to
local function variants(p, out)
    p = p:gsub("/", "\\"):gsub("^%s+", ""):gsub("%s+$", "")
    if p == "" or #p > 260 then return end
    local low = p:lower()
    local base = p
    if low:match("%.mdl$") then base = p:sub(1, -5) end
    local forms = {}
    if low:match("%.mdl$") or low:match("%.mdx$") then forms = { base .. ".mdx", base .. ".mdl" }
    elseif low:match("%.tga$") then forms = { p, p:sub(1, -5) .. ".blp" }
    elseif low:match("%.blp$") then forms = { p, p:sub(1, -5) .. ".tga" }
    elseif low:match("%.%w+$") then forms = { p }
    else forms = { p .. ".mdx", p .. ".blp" } end
    for _, f in ipairs(forms) do
        out[#out + 1] = f
        if not f:lower():match("^war3mapimported\\") then out[#out + 1] = "war3mapImported\\" .. f end
    end
end
imports.variants = variants

-- strings that look like paths, with who names them
local function refs_of(E)
    local refs = {}          -- lowercased candidate -> { users }
    local names = {}
    local function note(path, user)
        local v = {}
        variants(path, v)
        for _, n in ipairs(v) do
            local k = n:lower()
            if not refs[k] then refs[k] = {}; names[#names + 1] = n end
            local list = refs[k]
            if #list < 20 and list[#list] ~= user then list[#list + 1] = user end
        end
    end
    for kind in pairs(E.OBJECT_KINDS or {}) do
        local t = E:object_table(kind)
        for _, list in ipairs({ t.original_list, t.custom_list }) do
            for _, o in ipairs(list or {}) do
                for _, m in ipairs(o.modifications) do
                    if type(m.value) == "string" and m.value:find("[%.\\/]") then
                        for piece in m.value:gmatch("[^,]+") do
                            if piece:match("%.%w%w%w?$") or piece:find("\\", 1, true) then
                                note(piece, kind .. " " .. o.id .. " " .. m.field_id)
                            end
                        end
                    end
                end
            end
        end
    end
    if E.script then
        for s in E.script:gmatch('"([^"\r\n]+)"') do
            local p = s:gsub("\\\\", "\\")
            if p:match("%.%w%w%w?$") and (p:find("\\", 1, true) or p:find("/", 1, true) or #p < 64) then
                note(p, "script")
            end
        end
    end
    return refs, names
end
-- }}}

-- {{{ reading headers
local function u32(d, at)
    local a, b, c, e = d:byte(at, at + 3)
    return (a or 0) + (b or 0) * 256 + (c or 0) * 65536 + (e or 0) * 16777216
end
local function u16(d, at)
    local a, b = d:byte(at, at + 1)
    return (a or 0) + (b or 0) * 256
end
local function pow2(n) return n > 0 and math.floor(math.log(n) / math.log(2) + 0.5) == math.log(n) / math.log(2) end

function imports.validate(name, data)
    if not data then return { status = "error", message = "can't be read" } end
    local kind = imports.kind_of(name)
    local ext = (name:match("%.(%w+)$") or ""):lower()
    if ext == "mdx" then
        if data:sub(1, 4) ~= "MDLX" then return { status = "error", message = "not an MDX model" } end
        local ok, m = pcall(require("parsers.mdx").parse, data)
        if not ok then return { status = "error", message = "not an MDX model: " .. tostring(m):sub(1, 80) } end
        if #(m.geosets or {}) == 0 and #(m.sequences or {}) == 0 then
            return { status = "error", message = "an MDX with nothing in it" }
        end
        return { status = "ok", message = string.format("MDX, %d sequences, %d geosets, %d textures",
            #(m.sequences or {}), #(m.geosets or {}), #(m.textures or {})) }
    elseif ext == "blp" then
        local ok, h = pcall(require("parsers.blp").header, data)
        if not ok then return { status = "error", message = tostring(h):gsub("^.-: ", "") } end
        if not (pow2(h.width) and pow2(h.height)) then
            return { status = "warn", message = string.format("BLP %dx%d: not powers of two", h.width, h.height) }
        end
        return { status = "ok", message = string.format("BLP %dx%d", h.width, h.height) }
    elseif ext == "tga" then
        if #data < 18 then return { status = "error", message = "too short for a TGA" } end
        local w, h, bits = u16(data, 13), u16(data, 15), data:byte(17)
        if w == 0 or h == 0 or (bits ~= 24 and bits ~= 32 and bits ~= 8) then
            return { status = "error", message = "not a TGA picture" }
        end
        return { status = "ok", message = string.format("TGA %dx%d, %d bits", w, h, bits) }
    elseif ext == "wav" then
        if data:sub(1, 4) ~= "RIFF" or data:sub(9, 12) ~= "WAVE" then return { status = "error", message = "not a WAV" } end
        local rate, bps = u32(data, 25), u32(data, 29)
        local seconds = bps > 0 and (#data - 44) / bps or 0
        return { status = "ok", message = string.format("WAV %.1f s at %d Hz", seconds, rate) }
    elseif ext == "mp3" then
        local b1, b2 = data:byte(1, 2)
        if data:sub(1, 3) == "ID3" or (b1 == 0xFF and b2 and b2 >= 0xE0) then
            return { status = "ok", message = string.format("MP3, %d KB", math.floor(#data / 1024)) }
        end
        return { status = "error", message = "not an MP3" }
    elseif kind == "script" or kind == "data" then
        if data:find("\0", 1, true) then return { status = "warn", message = "text with zero bytes in it" } end
        return { status = "ok", message = string.format("text, %d lines", select(2, data:gsub("\n", "")) + 1) }
    end
    return { status = "ok", message = string.format("%d bytes", #data) }
end
-- }}}

local function install(E)

    -- {{{ loading
    function E:load_imports()
        local refs, names = refs_of(self)
        local a = mpq.open(self.path)
        if not a then self.import_list = {} return {} end
        local files = a:files(names)
        -- models name their textures: one more round with those
        local more = {}
        for _, f in ipairs(files) do
            if f.name:lower():match("%.mdx$") and f.size < 8 * 1024 * 1024 then
                local ok, m = pcall(function() return require("parsers.mdx").parse(a:extract(f.name)) end)
                if ok and m then
                    for _, t in ipairs(m.textures or {}) do
                        if t.path and t.path ~= "" then
                            local v = {}
                            variants(t.path, v)
                            for _, n in ipairs(v) do
                                local k = n:lower()
                                if not refs[k] then refs[k] = {}; names[#names + 1] = n end
                                local u = refs[k]
                                if #u < 20 and u[#u] ~= "model " .. f.name then u[#u + 1] = "model " .. f.name end
                            end
                        end
                    end
                end
            end
        end
        if #names > 0 then files = a:files(names) end
        a:close()
        self.import_refs = refs
        self.import_list = {}
        for _, f in ipairs(files) do
            if not imports.is_own(f.name) then
                self.import_list[#self.import_list + 1] = { name = f.name, size = f.size, block = f.block, in_map = true,
                    kind = imports.kind_of(f.name), unnamed = f.name:match("^File%d+%.") ~= nil,
                    users = refs[f.name:lower()] or {} }
            end
        end
        table.sort(self.import_list, function(x, y)
            if x.kind ~= y.kind then
                local ox, oy = 99, 99
                for i, k in ipairs(imports.ORDER) do if k == x.kind then ox = i end if k == y.kind then oy = i end end
                return ox < oy
            end
            if x.unnamed ~= y.unnamed then return not x.unnamed end
            return x.name:lower() < y.name:lower()
        end)
        self.import_changes = {}     -- name -> bytes | false
        return self.import_list
    end

    function E:imports()
        if not self.import_list then self:load_imports() end
        return self.import_list
    end

    function E:import_named(name)
        local low = name:lower()
        for _, f in ipairs(self:imports()) do if f.name:lower() == low then return f end end
    end
    -- }}}

    -- {{{ changes
    local function changed(self) self.dirty.imports = true end

    function E:import_data(name)
        local c = self.import_changes and self.import_changes[name]
        if c ~= nil then return c or nil end
        local a = mpq.open(self.path)
        if not a then return nil end
        local d = a:extract(name)
        a:close()
        return d
    end

    function E:import_bytes(bytes, name)
        name = name:gsub("/", "\\")
        self:imports()
        local list, ch, me = self.import_list, self.import_changes, self
        local old = self:import_named(name)
        local old_change = ch[name]
        local entry = { name = name, size = #bytes, kind = imports.kind_of(name), unnamed = false, added = true,
                        users = (self.import_refs or {})[name:lower()] or {} }
        self.history:run({ name = (old and "Replace " or "Import ") .. name,
            redo = function()
                ch[name] = bytes
                if old then old.size, old.added = #bytes, true
                else list[#list + 1] = entry end
                changed(me)
            end,
            undo = function()
                ch[name] = old_change
                if old then old.size = entry.size
                else for i, x in ipairs(list) do if x == entry then table.remove(list, i) break end end end
                changed(me)
            end })
        return true
    end

    function E:import_file(path, name)
        local f = io.open(path, "rb")
        if not f then return false, "can't read " .. path end
        local bytes = f:read("*a")
        f:close()
        name = name or ("war3mapImported\\" .. path:match("([^/\\]+)$"))
        return self:import_bytes(bytes, name)
    end

    function E:delete_import(name)
        local list, ch, me = self:imports(), self.import_changes, self
        local at, entry
        for i, x in ipairs(list) do if x.name == name then at, entry = i, x end end
        if not entry then return false, "no file " .. name end
        local before = ch[name]
        self.history:run({ name = "Delete " .. name,
            redo = function()
                table.remove(list, at)
                -- one the map has is taken out; one only added here just goes
                if entry.in_map then ch[name] = false else ch[name] = nil end
                changed(me)
            end,
            undo = function() table.insert(list, at, entry); ch[name] = before; changed(me) end })
        return true
    end

    function E:rename_import(old, new)
        new = new:gsub("/", "\\")
        if old == new then return true end
        if self:import_named(new) then return false, "a file has that name" end
        local entry = self:import_named(old)
        if not entry then return false, "no file " .. old end
        local data = self:import_data(old)
        if not data then return false, "can't read " .. old end
        self.history:begin("Rename " .. old .. " to " .. new)
        self:delete_import(old)
        self:import_bytes(data, new)
        self.history:finish()
        return true
    end

    function E:export_import(name, path)
        local d = self:import_data(name)
        if not d then return false, "can't read " .. name end
        local f = io.open(path, "wb")
        if not f then return false, "can't write " .. path end
        f:write(d)
        f:close()
        return true
    end

    function E:validate_import(name)
        return imports.validate(name, self:import_data(name))
    end

    function E:unused_imports()
        local out = {}
        for _, f in ipairs(self:imports()) do
            if #f.users == 0 then out[#out + 1] = f end
        end
        return out
    end

    function E:import_files(files)
        for name, v in pairs(self.import_changes or {}) do files[name] = v end
        return files
    end
    -- }}}
end

return setmetatable(imports, { __call = function(_, E) return install(E) end })
