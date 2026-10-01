--[[
Map Projects: the Unified Format (Issue 911c)

A map as a folder of files, for version control and for editing outside
the editor: what can be text is text (Lua data or the file's own text),
the rest is kept as it is, and building the folder gives back a map that
WC3 and this engine read as they read the original, file for file.

    MyMap.wex/
      manifest.lua          the format, the map's name, its 512-byte
                            header, its archive's hash table (every slot:
                            where each file was, so files with no known
                            name are found again), and each file: where it
                            is in the folder and in what form
      info.lua              war3map.w3i as Lua (players, forces, flags ...)
      terrain/terrain.lua   war3map.w3e's header (tilesets, size, offset)
      terrain/points.txt    its points, one row of the map a line:
                            height, water (with its flags), texture and
                            flags, details and cliff variation, layer and
                            cliff texture, as hex
      objects/doodads.lua   war3map.doo, one doodad a line
      objects/units.lua     war3mapUnits.doo, one unit a line
      objects/regions.lua   war3map.w3r
      definitions/*.lua     the object types (units, items, destructibles,
                            doodads, abilities, buffs, upgrades), one type
                            a line
      scripts/              the script, the strings, the editor's triggers,
                            AI profiles, other text: as their own text
      assets/               the imports, at their paths (war3mapImported/..)
      map/                  the map's other files, as they are
      unnamed/              files nobody names (protected maps), by block
      wow/                  reserved for the WoW layer (issue 911's design);
                            a WC3 build leaves it out and says so

A readable form is used only when it gives back the file byte for byte
(checked when exporting); otherwise the file is kept as it is. Editing a
readable form and building puts the edit in the map. Files added under
assets/ are imported by their path; files taken away are taken out.

  mapfile.export(map, dir, opts)    a map (.w3x path) into a folder;
                                    opts.lightweight leaves assets out
  mapfile.build(dir, out, opts)     the folder back into a .w3x;
                                    opts.assets_from: a map or folder the
                                    assets come from (lightweight projects)
  mapfile.validate(dir, mode)       problems { level, message } for "wc3"
  mapfile.pack(dir, file)           the folder as one .wex file (a ZIP,
                                    stored), and mapfile.unpack(file, dir)
  mapfile.is_project(path)

    luajit src/editor/mapfile.lua export MAP.w3x DIR [--light]
    luajit src/editor/mapfile.lua build DIR OUT.w3x
    luajit src/editor/mapfile.lua pack DIR OUT.wex | unpack IN.wex DIR | validate DIR
]]

local AS_SCRIPT = arg and arg[0] and (arg[0] == "mapfile.lua" or arg[0]:match("editor/mapfile%.lua$")) and arg[1]
if AS_SCRIPT then
    local root = arg[0]:match("^(.*)/src/editor/mapfile%.lua$") or "."
    package.path = root .. "/src/?.lua;" .. root .. "/src/?/init.lua;" .. package.path
end

local mpq = require("mpq")
local patch = require("mpq.patch")
local bw = require("parsers.binwrite")

local mapfile = {}
mapfile.FORMAT = 1

-- {{{ files and folders
local function sh(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local d = f:read("*a")
    f:close()
    return d
end

local function write(path, data)
    local dir = path:match("^(.*)/[^/]+$")
    if dir then os.execute("mkdir -p " .. sh(dir)) end
    local f = assert(io.open(path, "wb"))
    f:write(data)
    f:close()
end

-- every file under dir, relative, sorted
local function walk(dir)
    local out = {}
    local p = io.popen("cd " .. sh(dir) .. " 2>/dev/null && find . -type f | sort")
    if not p then return out end
    for line in p:lines() do out[#out + 1] = line:gsub("^%./", "") end
    p:close()
    return out
end
mapfile.walk = walk

function mapfile.is_project_dir(path) return read(path .. "/manifest.lua") ~= nil end

function mapfile.is_project(path)
    if type(path) ~= "string" then return false end
    if read(path .. "/manifest.lua") then return true end
    if path:match("%.wexl?$") then
        local f = io.open(path, "rb")
        local head = f and f:read(4)
        if f then f:close() end
        return head == "PK\3\4"
    end
    return false
end
-- }}}

-- {{{ Lua data: a table, and its long lists one item a line
local function one_line(v, out)
    local t = type(v)
    if t == "string" then out[#out + 1] = (string.format("%q", v):gsub("\\\n", "\\n"):gsub("\r", "\\r"))
    elseif t == "number" then
        if v ~= v then out[#out + 1] = "0/0"
        elseif v == math.huge then out[#out + 1] = "1/0"
        elseif v == -math.huge then out[#out + 1] = "-1/0"
        elseif v == 0 and 1 / v < 0 then out[#out + 1] = "-0.0"      -- its bytes differ from 0's
        elseif v == math.floor(v) and math.abs(v) < 2 ^ 53 then out[#out + 1] = string.format("%d", v)
        else out[#out + 1] = string.format("%.17g", v) end
    elseif t == "boolean" then out[#out + 1] = tostring(v)
    elseif t == "table" then
        out[#out + 1] = "{"
        local n = #v
        for i = 1, n do one_line(v[i], out); out[#out + 1] = "," end
        local keys = {}
        for k in pairs(v) do
            if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) and type(v[k]) ~= "function"
                and not (type(k) == "string" and k:match("^_")) then
                keys[#keys + 1] = k
            end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then out[#out + 1] = k
            else out[#out + 1] = "["; one_line(k, out); out[#out + 1] = "]" end
            out[#out + 1] = "="
            one_line(v[k], out)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    else out[#out + 1] = "nil" end
end

function mapfile.data_text(t, lists, title)
    local head, out = {}, {}
    for k, v in pairs(t) do
        local listed = false
        for _, l in ipairs(lists or {}) do if l == k then listed = true end end
        if not listed then head[k] = v end
    end
    out[#out + 1] = "-- " .. (title or "data") .. " (world-edit-to-execute map project, issue 911c)"
    local parts = {}
    one_line(head, parts)
    out[#out + 1] = "return " .. table.concat(parts)
    for _, l in ipairs(lists or {}) do
        out[#out + 1] = "--@" .. l
        for _, item in ipairs(t[l] or {}) do
            local p = {}
            one_line(item, p)
            out[#out + 1] = table.concat(p)
        end
    end
    return table.concat(out, "\n") .. "\n"
end

local function load_data(src, name)
    local f, err = loadstring(src, "=" .. name)
    if not f then return nil, err end
    setfenv(f, {})
    local ok, v = pcall(f)
    if not ok then return nil, v end
    return v
end

function mapfile.read_data(text, name)
    local head_src, sections = {}, {}
    local cur
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local l = line:match("^%-%-@([%w_]+)$")
        if l then cur = { key = l, items = {} }; sections[#sections + 1] = cur
        elseif cur then
            if line ~= "" then
                local v, err = load_data("return " .. line, name)
                if v == nil then return nil, err end
                cur.items[#cur.items + 1] = v
            end
        else head_src[#head_src + 1] = line end
    end
    local t, err = load_data(table.concat(head_src, "\n"), name)
    if type(t) ~= "table" then return nil, err or "not a table" end
    for _, s in ipairs(sections) do t[s.key] = s.items end
    return t
end
-- }}}

-- {{{ the readable forms
local od = require("parsers.objectdata")
local OBJECT_KINDS = { w3u = "units", w3t = "items", w3b = "destructibles", w3d = "doodads", w3a = "abilities",
                       w3h = "buffs", w3q = "upgrades" }

local FORMS = {}

FORMS["war3map.w3i"] = { path = "info.lua",
    text = function(b) return mapfile.data_text(require("parsers.w3i").parse(b), nil, "war3map.w3i") end,
    bytes = function(files) local t = assert(mapfile.read_data(files["info.lua"], "info.lua")); return require("parsers.w3i").write(t) end }

FORMS["war3map.doo"] = { path = "objects/doodads.lua",
    text = function(b) return mapfile.data_text(require("parsers.doo").parse(b), { "doodads" }, "war3map.doo") end,
    bytes = function(files) return require("parsers.doo").write(assert(mapfile.read_data(files["objects/doodads.lua"], "doodads"))) end }

FORMS["war3mapUnits.doo"] = { path = "objects/units.lua",
    text = function(b) return mapfile.data_text(require("parsers.unitsdoo").parse(b), { "units" }, "war3mapUnits.doo") end,
    bytes = function(files) return require("parsers.unitsdoo").write(assert(mapfile.read_data(files["objects/units.lua"], "units"))) end }

FORMS["war3map.w3r"] = { path = "objects/regions.lua",
    text = function(b) return mapfile.data_text(require("parsers.w3r").parse(b), { "regions" }, "war3map.w3r") end,
    bytes = function(files) return require("parsers.w3r").write(assert(mapfile.read_data(files["objects/regions.lua"], "regions"))) end }

for ext, kind in pairs(OBJECT_KINDS) do
    local path = "definitions/" .. kind .. ".lua"
    local levels = od.FILE_CONFIG[ext].has_level_column
    FORMS["war3map." .. ext] = { path = path,
        text = function(b)
            local t = od.parse(b, { has_level_column = levels })
            local copy = {}
            for k, v in pairs(t) do if k ~= "original" and k ~= "custom" then copy[k] = v end end
            return mapfile.data_text(copy, { "original_list", "custom_list" }, "war3map." .. ext)
        end,
        bytes = function(files)
            local t = assert(mapfile.read_data(files[path], kind))
            t.original_list, t.custom_list = t.original_list or {}, t.custom_list or {}
            return od.write(t)
        end }
end

-- the terrain: its header as Lua, its points as hex rows
local function u16(d, at) local a, b = d:byte(at, at + 1) return a + b * 256 end
FORMS["war3map.w3e"] = { path = "terrain/terrain.lua", also = { "terrain/points.txt" },
    text = function(b)
        local t = require("parsers.w3e").parse(b)
        local head = { version = t.version, tileset = t.tileset_code, custom_tileset = t.custom_tileset and true or false,
                       ground_tilesets = t.ground_tilesets, cliff_tilesets = t.cliff_tilesets, width = t.width,
                       height = t.height, offset_x = t.offset_x, offset_y = t.offset_y }
        local header_size = #b - t.width * t.height * 7
        local rows = {}
        for y = 0, t.height - 1 do
            local cells = {}
            for x = 0, t.width - 1 do
                local at = header_size + (y * t.width + x) * 7 + 1
                cells[#cells + 1] = string.format("%04x%04x%02x%02x%02x", u16(b, at), u16(b, at + 2),
                    b:byte(at + 4), b:byte(at + 5), b:byte(at + 6))
            end
            rows[#rows + 1] = table.concat(cells, " ")
        end
        return mapfile.data_text(head, nil, "war3map.w3e (points in points.txt)"),
            { ["terrain/points.txt"] = table.concat(rows, "\n") .. "\n" }
    end,
    bytes = function(files)
        local h = assert(mapfile.read_data(files["terrain/terrain.lua"], "terrain"))
        local out = bw.new():str("W3E!"):i32(h.version or 11):str(h.tileset or "L"):i32(h.custom_tileset and 1 or 0)
        out:i32(#h.ground_tilesets)
        for _, g in ipairs(h.ground_tilesets) do out:str(g) end
        out:i32(#h.cliff_tilesets)
        for _, c in ipairs(h.cliff_tilesets) do out:str(c) end
        out:i32(h.width):i32(h.height):f32(h.offset_x):f32(h.offset_y)
        local n = 0
        for row in (files["terrain/points.txt"] or ""):gmatch("[^\n]+") do
            for cell in row:gmatch("%x+") do
                out:u16(tonumber(cell:sub(1, 4), 16)):u16(tonumber(cell:sub(5, 8), 16))
                out:u8(tonumber(cell:sub(9, 10), 16)):u8(tonumber(cell:sub(11, 12), 16)):u8(tonumber(cell:sub(13, 14), 16))
                n = n + 1
            end
        end
        if n ~= h.width * h.height then error("terrain/points.txt has " .. n .. " points, not " .. h.width * h.height) end
        return out:done()
    end }

local TEXT_EXT = { j = true, lua = true, ai = true, wts = true, txt = true, fdf = true, slk = true, toc = true }

-- where a file goes in the folder, as it is (no readable form)
local function raw_path(name, unnamed)
    local p = name:gsub("\\", "/"):gsub("%.%.", "_"):gsub("^/+", "")
    if unnamed then return "unnamed/" .. p end
    local ext = (p:match("%.(%w+)$") or ""):lower()
    local low = p:lower()
    if low:match("^war3mapimported/") then return "assets/" .. p end
    if low == "war3map.j" or low == "scripts/war3map.j" or low == "war3mapeditor.lua" or low:match("^war3mapai/")
        or low == "war3map.wts" or (TEXT_EXT[ext] and low:match("^war3map")) then
        return "scripts/" .. p
    end
    if low:match("^war3map") or low:match("^%(") then return "map/" .. p:gsub("[%(%)]", "") end
    return "assets/" .. p
end
mapfile.raw_path = raw_path
-- }}}

-- {{{ the names in a map
local function names_of(map_path)
    local names = {}
    local ok, editor = pcall(require, "editor")
    if ok then
        local E = editor.open(map_path)
        if E then
            for _, f in ipairs(E:imports()) do if not f.unnamed then names[#names + 1] = f.name end end
        end
    end
    for _, n in ipairs(require("mpq.standard_names").MAP_FILES) do names[#names + 1] = n end
    for _, n in ipairs({ "war3mapEditor.lua", "(listfile)", "(attributes)", "(signature)" }) do names[#names + 1] = n end
    for p = 0, 11 do names[#names + 1] = string.format("war3mapAI\\p%02d.lua", p) end
    return names
end
-- }}}

-- {{{ mapfile.export
function mapfile.export(map_path, dir, opts)
    opts = opts or {}
    local bytes = read(map_path)
    if not bytes then return nil, "can't read " .. map_path end
    local tables, terr = patch.tables(bytes)
    if not tables then return nil, terr end
    local a, aerr = mpq.open(map_path)
    if not a then return nil, aerr end
    local list = a:files(names_of(map_path))
    local manifest = { format = mapfile.FORMAT, source = map_path:match("([^/]+)$"), files = {}, modes = { "wc3" },
                       hash_n = tables.hash_n, slots = {}, lightweight = opts.lightweight or nil }
    local head = bytes:sub(1, tables.base)
    if #head > 0 then
        manifest.header = head
        local w = require("mpq.map_wrapper").parse(head .. string.rep("\0", 512))
        if w then manifest.name = w.map_name end
    end
    -- the folder written afresh, but for wow/ (the WoW layer is the
    -- project's own: a WC3 map doesn't carry it)
    os.execute("mkdir -p " .. sh(dir) .. " && find " .. sh(dir) .. " -mindepth 1 -maxdepth 1 ! -name wow -exec rm -rf {} +")
    local key_of_block, report = {}, { readable = 0, raw = 0, left_out = 0, unnamed = 0 }
    for _, f in ipairs(list) do
        local unnamed = f.name:match("^File%d+%.") ~= nil
        local ok, data = pcall(a._storm.read, a._storm, f.name)
        if ok and data then
            local key = f.name
            key_of_block[f.block] = key
            local entry = { size = #data, unnamed = unnamed or nil }
            local form = not unnamed and FORMS[f.name]
            local kept = false
            if form then
                -- the readable form, if it gives the file back byte for byte
                local okt, text, extra = pcall(form.text, data)
                if okt and text then
                    local files = { [form.path] = text }
                    for k, v in pairs(extra or {}) do files[k] = v end
                    local okb, back = pcall(form.bytes, files)
                    if okb and back == data then
                        for p, t in pairs(files) do write(dir .. "/" .. p, t) end
                        entry.form, entry.path = f.name, form.path
                        kept = true
                        report.readable = report.readable + 1
                    end
                end
            end
            if not kept then
                entry.path = raw_path(f.name, unnamed)
                if opts.lightweight and entry.path:match("^assets/") then
                    entry.external = true
                    report.left_out = report.left_out + 1
                else
                    write(dir .. "/" .. entry.path, data)
                    report.raw = report.raw + 1
                end
                if unnamed then report.unnamed = report.unnamed + 1 end
            end
            manifest.files[key] = entry
        end
    end
    a:close()
    -- the hash table: every slot, with the file it finds
    local slot_ids = {}
    for s in pairs(tables.slots) do slot_ids[#slot_ids + 1] = s end
    table.sort(slot_ids)
    for _, s in ipairs(slot_ids) do
        local e = tables.slots[s]
        manifest.slots[#manifest.slots + 1] = { slot = s, a = e[1], b = e[2], locale = e[3],
                                                file = key_of_block[e[4]] }
    end
    local wow = { "-- The WoW layer of the unified format (issue 911's design): nothing yet.",
                  "-- Files here are left out of a WC3 build (mapfile.validate says so)." }
    if not read(dir .. "/wow/README.txt") then write(dir .. "/wow/README.txt", table.concat(wow, "\n") .. "\n") end
    write(dir .. "/manifest.lua", mapfile.data_text(manifest, { "slots" }, "manifest"))
    report.files = report.readable + report.raw + report.left_out
    return true, report
end
-- }}}

-- {{{ reading a folder back
local function manifest_of(dir)
    local text = read(dir .. "/manifest.lua")
    if not text then return nil, "no manifest.lua in " .. dir end
    local m, err = mapfile.read_data(text, "manifest")
    if not m then return nil, "manifest.lua: " .. tostring(err) end
    return m
end

-- external assets: from a map or a folder
local function asset_source(from)
    if not from then return nil end
    if mapfile.is_project(from) then
        return function(name, entry) return read(from .. "/" .. entry.path) end
    end
    local a = mpq.open(from)
    if not a then return nil end
    return function(name) local ok, d = pcall(a._storm.read, a._storm, name) return ok and d or nil end
end

-- { name = bytes } for the map, and the problems found
local function gather(dir, m, opts)
    local files, problems, used = {}, {}, {}
    local external = asset_source(opts.assets_from)
    for name, e in pairs(m.files) do
        used[e.path] = true
        if e.form then
            local form = FORMS[e.form]
            local texts = { [form.path] = read(dir .. "/" .. form.path) }
            used[form.path] = true
            for _, p in ipairs(form.also or {}) do texts[p] = read(dir .. "/" .. p); used[p] = true end
            if not texts[form.path] then
                problems[#problems + 1] = { level = "error", message = form.path .. " is missing" }
            else
                local ok, b = pcall(form.bytes, texts)
                if ok then files[name] = b
                else problems[#problems + 1] = { level = "error", message = form.path .. ": " .. tostring(b) } end
            end
        elseif e.external then
            local d = external and external(name, e)
            if d then files[name] = d
            else problems[#problems + 1] = { level = "error", message = name .. " is left out (a lightweight project): "
                .. "give assets_from" } end
        else
            local d = read(dir .. "/" .. e.path)
            if d then files[name] = d
            else problems[#problems + 1] = { level = "warn", message = e.path .. " was taken away: " .. name .. " left out" } end
        end
    end
    -- files put in the folder since: imports by their path
    local added = {}
    for _, p in ipairs(walk(dir)) do
        if not used[p] and p ~= "manifest.lua" then
            if p:match("^wow/") then
                if p ~= "wow/README.txt" then
                    problems[#problems + 1] = { level = "warn", message = p .. ": WoW-only, left out of a WC3 build" }
                end
            elseif p:match("^assets/") then
                local name = p:sub(8):gsub("/", "\\")
                files[name] = read(dir .. "/" .. p)
                added[name] = true
            else
                problems[#problems + 1] = { level = "warn", message = p .. " isn't part of the map (put new files under assets/)" }
            end
        end
    end
    return files, problems, added
end

function mapfile.validate(dir, mode, opts)
    local m, err = manifest_of(dir)
    if not m then return { { level = "error", message = err } } end
    if (mode or "wc3") ~= "wc3" then return { { level = "error", message = "only WC3 builds so far" } } end
    local _, problems = gather(dir, m, opts or {})
    return problems
end
-- }}}

-- {{{ mapfile.build
function mapfile.build(dir, out, opts)
    opts = opts or {}
    local m, err = manifest_of(dir)
    if not m then return nil, err end
    local files, problems, added = gather(dir, m, opts)
    for _, p in ipairs(problems) do if p.level == "error" then return nil, p.message, problems end end
    local slots, stored = {}, {}
    for _, s in ipairs(m.slots or {}) do
        local f = s.file
        if f and files[f] == nil then f = nil end      -- taken out
        slots[s.slot] = { s.a, s.b, s.locale, file = f }
        if f then stored[f] = files[f] end
    end
    local named = {}
    for name in pairs(added) do named[name] = name; stored[name] = files[name] end
    -- the listfile names what's been added
    if next(added) and files["(listfile)"] then
        local list = files["(listfile)"]
        local names = {}
        for n in pairs(added) do names[#names + 1] = n end
        table.sort(names)
        local sep = (#list > 0 and not list:match("[\r\n]$")) and "\r\n" or ""
        stored["(listfile)"] = list .. sep .. table.concat(names, "\r\n") .. "\r\n"
    end
    -- a hash table big enough (a power of two, at least as big as before)
    local count = 0
    for _ in pairs(stored) do count = count + 1 end
    local hash_n = m.hash_n or 16
    while hash_n <= count do hash_n = hash_n * 2 end
    if hash_n ~= m.hash_n then
        -- a new size moves every slot: put everything in by name (unnamed
        -- files can't be: they'd be lost)
        for _, s in pairs(slots) do
            if s.file and m.files[s.file] and m.files[s.file].unnamed then
                return nil, "too many files for the map's hash table with unnamed files in it"
            end
        end
        slots = {}
        for name in pairs(stored) do named[name] = name end
    end
    local archive, berr = patch.build(hash_n, slots, stored, named)
    if not archive then return nil, berr end
    local header = m.header or ""
    if header == "" then
        local name = m.name or "Map"
        header = "HM3W\0\0\0\0" .. name .. "\0" .. bw.new():u32(0):u32(12):done()
        header = header .. string.rep("\0", 512 - #header)
    end
    write(out, header .. archive)
    return true, { files = count, problems = problems }
end
-- }}}

-- {{{ one file: a ZIP, stored (no compression), with CRC-32s
local crc_table
local function crc32(s)
    if not crc_table then
        crc_table = {}
        for i = 0, 255 do
            local c = i
            for _ = 1, 8 do
                if bit.band(c, 1) == 1 then c = bit.bxor(bit.rshift(c, 1), 0xEDB88320) else c = bit.rshift(c, 1) end
            end
            crc_table[i] = c
        end
    end
    local c = 0xFFFFFFFF
    for i = 1, #s do c = bit.bxor(crc_table[bit.band(bit.bxor(c, s:byte(i)), 0xFF)], bit.rshift(c, 8)) end
    return bit.bxor(c, 0xFFFFFFFF) % 4294967296
end
mapfile.crc32 = crc32

function mapfile.pack(dir, file)
    local parts, central, offset = {}, {}, 0
    local paths = walk(dir)
    for _, p in ipairs(paths) do
        local d = read(dir .. "/" .. p)
        local crc = crc32(d)
        local local_head = bw.new():u32(0x04034b50):u16(20):u16(0):u16(0):u16(0):u16(0):u32(crc)
            :u32(#d):u32(#d):u16(#p):u16(0):done() .. p
        central[#central + 1] = bw.new():u32(0x02014b50):u16(20):u16(20):u16(0):u16(0):u16(0):u16(0):u32(crc)
            :u32(#d):u32(#d):u16(#p):u16(0):u16(0):u16(0):u16(0):u32(0):u32(offset):done() .. p
        parts[#parts + 1] = local_head
        parts[#parts + 1] = d
        offset = offset + #local_head + #d
    end
    local cd = table.concat(central)
    local tail = bw.new():u32(0x06054b50):u16(0):u16(0):u16(#paths):u16(#paths):u32(#cd):u32(offset):u16(0):done()
    write(file, table.concat(parts) .. cd .. tail)
    return true, #paths
end

function mapfile.unpack(file, dir)
    local z = read(file)
    if not z then return nil, "can't read " .. file end
    local function u32(at) local a, b, c, d = z:byte(at, at + 3) return a + b * 256 + c * 65536 + d * 16777216 end
    local function u16v(at) local a, b = z:byte(at, at + 1) return a + b * 256 end
    local eocd = z:find("PK\5\6", #z - 65557 > 0 and #z - 65557 or 1, true)
    if not eocd then return nil, "not a ZIP" end
    local n, cd_at = u16v(eocd + 10), u32(eocd + 16) + 1
    os.execute("rm -rf " .. sh(dir) .. " && mkdir -p " .. sh(dir))
    local at = cd_at
    for _ = 1, n do
        if u32(at) ~= 0x02014b50 then return nil, "a broken ZIP directory" end
        local method, crc, size = u16v(at + 10), u32(at + 16), u32(at + 20)
        local name_len, extra_len, comment_len = u16v(at + 28), u16v(at + 30), u16v(at + 32)
        local local_at = u32(at + 42) + 1
        local name = z:sub(at + 46, at + 45 + name_len)
        if method ~= 0 then return nil, name .. " is compressed (only stored .wex files are read)" end
        if name:find("%.%.") or name:match("^/") then return nil, "a path out of the folder: " .. name end
        local data_at = local_at + 30 + u16v(local_at + 26) + u16v(local_at + 28)
        local d = z:sub(data_at, data_at + size - 1)
        if crc32(d) ~= crc then return nil, name .. " is damaged (CRC)" end
        write(dir .. "/" .. name, d)
        at = at + 46 + name_len + extra_len + comment_len
    end
    return true, n
end
-- }}}

-- {{{ from the command line
if AS_SCRIPT then
    -- this file is the module the editor asks for too
    package.loaded["editor.mapfile"] = mapfile
    local cmd, x, y = arg[1], arg[2], arg[3]
    local ok, rep
    if cmd == "export" then ok, rep = mapfile.export(x, y, { lightweight = arg[4] == "--light" })
    elseif cmd == "build" then ok, rep = mapfile.build(x, y, { assets_from = arg[4] })
    elseif cmd == "pack" then ok, rep = mapfile.pack(x, y)
    elseif cmd == "unpack" then ok, rep = mapfile.unpack(x, y)
    elseif cmd == "validate" then
        local probs = mapfile.validate(x, "wc3")
        for _, p in ipairs(probs) do print(p.level .. ": " .. p.message) end
        print(#probs == 0 and "no problems" or (#probs .. " problems"))
        os.exit(0)
    else
        print("usage: mapfile.lua export MAP DIR [--light] | build DIR OUT [ASSETS_FROM] | pack DIR FILE | unpack FILE DIR | validate DIR")
        os.exit(1)
    end
    if ok then
        if type(rep) == "table" then
            local parts = {}
            for k, v in pairs(rep) do if type(v) ~= "table" then parts[#parts + 1] = k .. "=" .. tostring(v) end end
            table.sort(parts)
            print(cmd .. ": " .. table.concat(parts, " "))
        else print(cmd .. ": " .. tostring(rep)) end
    else print(cmd .. " failed: " .. tostring(rep)) os.exit(1) end
end
-- }}}

return mapfile
