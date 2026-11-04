--[[
Shared Map-and-Model List: the File (Issue 609)

A player who wants a playmate to see their models for a map publishes a
list: the map (its hash and name), and for each asset they replaced, its
key, hash, size and where else it can be had. The receiver keeps it as
one of their asset packs (share/profile.lua) only if they choose to; the
W client uses one for a single game (its issue 1110).

    local list = require("share.list")
    local l = list.build({ map = "maps/x.w3x", map_name = "Castle Fight",
                           pack = "<player data>/asset-packs/mine",     -- the sharer's overrides
                           types = { hfoo = "units/knight/knight.mdx" }, -- optional: a unit type's model
                           author = "Ana" })
    local text = list.encode(l)        -- the file
    local l2, err = list.decode(text)  -- read back: data only, checked
    list.missing(l2, store)            -- hashes a dedup store lacks
    list.bundle(l2, pack, hashes, dir) -- the sharer copies those files into DIR, named by hash

The file is a Lua table, as the issue gives it:

    return {
      author = "Ana", created = "2026-11-02",
      map = { hash = "sha256:...", name = "Castle Fight", sources = { } },
      entries = {
        { key = "units/footman/footman.mdx", hash = "sha256:...", size = 1234, sources = { } },
        { key = "hfoo", path = "units/knight/knight.mdx", hash = "sha256:...", size = 99 },
      },
    }

It is never run: decode() reads only that shape (strings, numbers,
booleans, tables), so a list from someone else can't run code, loop for
ever or fill the memory. Only art and sound are carried (an entry's file
must be one of list.ART); data that changes how the game plays (unit
tables, scripts, the map's object files) is refused, so two players with
different lists play the same game.
]]

local list = {}

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."
local SHA_256 = HERE .. "/../../../burner-of-down-things/src/015-sha-256.lua"

list.PREFIX = "sha256:"
list.MAX_BYTES = 4 * 1024 * 1024     -- a list file larger than this is refused
list.MAX_ENTRIES = 100000

-- What a list may carry: art and sound, by extension.
list.ART = { blp = true, tga = true, png = true, dds = true, jpg = true, jpeg = true,
             mdx = true, mdl = true, wav = true, mp3 = true, ogg = true, flac = true }

-- {{{ local helpers
local sha_256
local function sha()
    if not sha_256 then sha_256 = dofile(SHA_256) end
    return sha_256
end

local function sh(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function key_of(path)
    return (path:gsub("\\", "/"):gsub("^/+", ""):lower())
end
list.key_of = key_of

local function ext_of(path)
    return (path:match("%.([%w]+)$") or ""):lower()
end
-- }}}

-- {{{ function list.hash_file
function list.hash_file(path)
    return list.PREFIX .. sha().of_file(path)
end
-- }}}

-- {{{ function list.check_path
-- A logical asset path a list may name: relative, no "..", no NUL or
-- newline, an art or sound extension. Gives the path's key, or nil and why.
function list.check_path(path)
    if type(path) ~= "string" or path == "" or #path > 260 then return nil, "not a path" end
    if path:find("[%z\n\r\t]") then return nil, "a path with a control character" end
    local key = key_of(path)
    if key:match("^%a:") then return nil, "an absolute path" end
    for part in key:gmatch("[^/]+") do
        if part == ".." or part == "." then return nil, "a path with . or .." end
    end
    if key == "" or key:sub(-1) == "/" then return nil, "not a file" end
    if not list.ART[ext_of(key)] then
        return nil, key .. " isn't art or sound (only " .. "models, textures and sounds are shared)"
    end
    return key
end
-- }}}

-- {{{ function list.check
-- Raises an error naming what is wrong with list L; returns L.
function list.check(l)
    local function bad(msg) error("list: " .. msg, 0) end
    if type(l) ~= "table" then bad("not a table") end
    if l.author ~= nil and type(l.author) ~= "string" then bad("author isn't text") end
    if l.created ~= nil and type(l.created) ~= "string" then bad("created isn't text") end
    if type(l.map) ~= "table" then bad("no map") end
    if type(l.map.hash) ~= "string" or not l.map.hash:match("^sha256:%x+$") or #l.map.hash ~= 71 then
        bad("the map's hash isn't sha256:<64 hex>")
    end
    if l.map.name ~= nil and type(l.map.name) ~= "string" then bad("the map's name isn't text") end
    if type(l.entries) ~= "table" then bad("no entries") end
    if #l.entries > list.MAX_ENTRIES then bad("too many entries") end
    local seen = {}
    for i, e in ipairs(l.entries) do
        local where = "entry " .. i
        if type(e) ~= "table" then bad(where .. " isn't a table") end
        if type(e.key) ~= "string" then bad(where .. " has no key") end
        if type(e.hash) ~= "string" or not e.hash:match("^sha256:%x+$") or #e.hash ~= 71 then
            bad(where .. "'s hash isn't sha256:<64 hex>")
        end
        if type(e.size) ~= "number" or e.size < 0 or e.size ~= math.floor(e.size) then bad(where .. "'s size isn't a count") end
        local path = e.path or e.key
        if e.key:match("^%w%w%w%w$") then
            -- a unit type, doodad or other object id: its model goes at e.path
            if type(e.path) ~= "string" then bad(where .. " (" .. e.key .. ") names a type but no path for its model") end
        end
        local key, why = list.check_path(path)
        if not key then bad(where .. ": " .. why) end
        if seen[e.key] then bad(where .. " repeats " .. e.key) end
        seen[e.key] = true
        if e.sources ~= nil then
            if type(e.sources) ~= "table" then bad(where .. "'s sources isn't a list") end
            for _, s in ipairs(e.sources) do if type(s) ~= "string" then bad(where .. " has a source that isn't text") end end
        end
        if e.provenance_id ~= nil and type(e.provenance_id) ~= "string" then bad(where .. "'s provenance_id isn't text") end
    end
    return l
end
-- }}}

-- {{{ function list.encode
-- The list as the text of a Lua table (keys sorted, so the same list is
-- the same text).
local function encode(v, indent)
    local t = type(v)
    if t == "string" then return (string.format("%q", v):gsub("\\\n", "\\n")) end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then error("list: can't write " .. tostring(v)) end
        return v == math.floor(v) and string.format("%d", v) or string.format("%.17g", v)
    end
    if t == "boolean" then return tostring(v) end
    if t ~= "table" then error("list: can't write a " .. t) end
    local inner = indent .. "  "
    local parts = {}
    for _, item in ipairs(v) do parts[#parts + 1] = inner .. encode(item, inner) end
    local keys = {}
    for k in pairs(v) do
        if type(k) == "string" then keys[#keys + 1] = k
        elseif not (type(k) == "number" and k >= 1 and k <= #v and k == math.floor(k)) then
            error("list: can't write a table key of type " .. type(k))
        end
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local name = k:match("^[%a_][%w_]*$") and k or ("[" .. encode(k, inner) .. "]")
        parts[#parts + 1] = inner .. name .. " = " .. encode(v[k], inner)
    end
    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, ",\n") .. ",\n" .. indent .. "}"
end

-- Any table of that shape as text (no check): used for the trust file too.
function list.serialize(t)
    return "return " .. encode(t, "") .. "\n"
end

function list.encode(l)
    list.check(l)
    return "-- A shared map-and-model list (world-edit-to-execute, issue 609)\nreturn " .. encode(l, "") .. "\n"
end
-- }}}

-- {{{ function list.decode
-- Reads a list's text without running it: only `return` and a table of
-- strings, numbers, booleans and tables, with -- comments. Gives the
-- checked list, or nil and a message.
local function reader(text)
    local pos, depth = 1, 0
    local function fail(msg) error({ msg = msg .. " (at byte " .. pos .. ")" }, 0) end
    local function skip()
        while true do
            local s, e = text:find("^[ \t\r\n]+", pos)
            if s then pos = e + 1 end
            if text:sub(pos, pos + 1) == "--" then
                if text:sub(pos + 2, pos + 3) == "[[" then
                    local close = text:find("]]", pos + 4, true)
                    if not close then fail("an unclosed comment") end
                    pos = close + 2
                else
                    local nl = text:find("\n", pos, true)
                    pos = nl and nl + 1 or #text + 1
                end
            elseif not s then
                return
            end
        end
    end
    local value
    local ESC = { n = "\n", t = "\t", r = "\r", ["\\"] = "\\", ['"'] = '"', ["'"] = "'", a = "\a", b = "\b",
                  f = "\f", v = "\v", ["\n"] = "\n" }
    local function str()
        local q = text:sub(pos, pos)
        pos = pos + 1
        local out = {}
        while true do
            local c = text:sub(pos, pos)
            if c == "" or c == "\n" then fail("an unclosed string") end
            if c == q then pos = pos + 1; break end
            if c == "\\" then
                local n = text:sub(pos + 1, pos + 1)
                local d = text:match("^%d%d?%d?", pos + 1)
                if d then
                    if tonumber(d) > 255 then fail("a bad escape") end
                    out[#out + 1] = string.char(tonumber(d))
                    pos = pos + 1 + #d
                elseif ESC[n] then
                    out[#out + 1] = ESC[n]
                    pos = pos + 2
                else
                    fail("a bad escape")
                end
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
        return table.concat(out)
    end
    local function tbl()
        depth = depth + 1
        if depth > 16 then fail("tables nested too deep") end
        pos = pos + 1
        local t, n = {}, 0
        while true do
            skip()
            local c = text:sub(pos, pos)
            if c == "}" then pos = pos + 1; break end
            if c == "" then fail("an unclosed table") end
            local k
            local name, after = text:match("^([%a_][%w_]*)%s*=()", pos)
            if name and name ~= "true" and name ~= "false" then
                k = name
                pos = after
            elseif c == "[" then
                pos = pos + 1
                skip()
                k = value()
                skip()
                if text:sub(pos, pos) ~= "]" then fail("a missing ]") end
                pos = pos + 1
                skip()
                if text:sub(pos, pos) ~= "=" then fail("a missing =") end
                pos = pos + 1
                if type(k) ~= "string" then fail("a key that isn't text") end
            end
            skip()
            local v = value()
            if k then
                t[k] = v
            else
                n = n + 1
                t[n] = v
            end
            skip()
            local sep = text:sub(pos, pos)
            if sep == "," or sep == ";" then pos = pos + 1
            elseif sep ~= "}" then fail("a missing , or }") end
        end
        depth = depth - 1
        return t
    end
    value = function()
        skip()
        local c = text:sub(pos, pos)
        if c == "{" then return tbl() end
        if c == '"' or c == "'" then return str() end
        local num = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
        if num and num ~= "" and num ~= "-" then
            pos = pos + #num
            local v = tonumber(num)
            if not v then fail("a bad number") end
            return v
        end
        if text:sub(pos, pos + 3) == "true" then pos = pos + 4; return true end
        if text:sub(pos, pos + 4) == "false" then pos = pos + 5; return false end
        fail("something other than text, a number, true, false or a table")
    end
    skip()
    if text:sub(pos, pos + 5) ~= "return" then fail("no return") end
    pos = pos + 6
    local v = value()
    skip()
    if pos <= #text then fail("more after the table") end
    return v
end

-- The table in TEXT, read the same way, unchecked; or nil and a message.
function list.parse(text)
    if type(text) ~= "string" then return nil, "list: no text" end
    if #text > list.MAX_BYTES then return nil, "list: larger than " .. list.MAX_BYTES .. " bytes" end
    local ok, v = pcall(reader, text)
    if not ok then return nil, "list: can't read it: " .. (type(v) == "table" and v.msg or tostring(v)) end
    return v
end

function list.decode(text)
    local v, err0 = list.parse(text)
    if v == nil then return nil, err0 end
    local good, err = pcall(list.check, v)
    if not good then return nil, err end
    return v
end
-- }}}

-- {{{ function list.build
-- A list from the sharer's pack folder (every art and sound file in it,
-- keyed by its path) and the map. opts: map (the map file), map_name,
-- pack (the folder), types ({id -> path inside the pack}: a unit type's
-- model), author, created (default today), sources ({key -> {urls}}).
-- Gives the list and the paths left out (not art or sound).
function list.build(opts)
    local l = {
        author = opts.author, created = opts.created or os.date("%Y-%m-%d"),
        map = { hash = list.hash_file(opts.map), name = opts.map_name or opts.map:match("([^/]+)$"), sources = {} },
        entries = {},
    }
    local left_out, by_key = {}, {}
    local p = io.popen("find -L " .. sh(opts.pack) .. " -mindepth 1 -type f -printf '%P\\n' 2>/dev/null")
    local rels = {}
    for rel in p:lines() do rels[#rels + 1] = rel end
    p:close()
    table.sort(rels, function(a, b) return key_of(a) < key_of(b) end)
    for _, rel in ipairs(rels) do
        local key = list.check_path(rel)
        if key and not by_key[key] then
            local full = opts.pack .. "/" .. rel
            local f = io.open(full, "rb")
            local size = f:seek("end")
            f:close()
            local e = { key = key, hash = list.hash_file(full), size = size,
                        sources = (opts.sources and opts.sources[key]) or {} }
            l.entries[#l.entries + 1] = e
            by_key[key] = e
        else
            left_out[#left_out + 1] = rel
        end
    end
    local ids = {}
    for id in pairs(opts.types or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local key = key_of(opts.types[id])
        local e = by_key[key]
        if not e then error("list: the model for " .. id .. " (" .. opts.types[id] .. ") isn't in the pack", 2) end
        l.entries[#l.entries + 1] = { key = id, path = key, hash = e.hash, size = e.size, sources = e.sources }
    end
    return list.check(l), left_out
end
-- }}}

-- {{{ function list.missing
-- The hashes of L's entries that STORE (a dedup store) doesn't hold, each
-- once, in the list's order.
function list.missing(l, store)
    local out, seen = {}, {}
    for _, e in ipairs(l.entries) do
        if not seen[e.hash] and not store:exists(e.hash) then
            out[#out + 1] = e.hash
        end
        seen[e.hash] = true
    end
    return out
end
-- }}}

-- {{{ function list.bundle
-- The sharer's side of "only what's missing is sent": copies the files of
-- PACK that L names with the hashes in WANTED into DIR, each named by its
-- hash's hex. Gives how many were copied; an error when a wanted hash
-- isn't one of the list's, or the pack's file no longer matches it.
function list.bundle(l, pack, wanted, dir)
    local by_hash = {}
    for _, e in ipairs(l.entries) do by_hash[e.hash] = e.path or e.key end
    os.execute("mkdir -p " .. sh(dir))
    local n = 0
    for _, hash in ipairs(wanted) do
        local key = by_hash[hash]
        if not key then error("list: " .. tostring(hash) .. " isn't in the list", 2) end
        local src = pack .. "/" .. key
        local f = io.open(src, "rb")
        if not f then
            -- a pack may hold the file under another case
            local p = io.popen("find -L " .. sh(pack) .. " -type f -iname " .. sh(key:match("[^/]+$")) .. " -printf '%P\\n' 2>/dev/null")
            for rel in p:lines() do
                if key_of(rel) == key then src = pack .. "/" .. rel; break end
            end
            p:close()
            f = io.open(src, "rb")
        end
        if not f then error("list: " .. key .. " isn't in the pack any more", 2) end
        f:close()
        if list.hash_file(src) ~= hash then error("list: " .. key .. " changed since the list was made", 2) end
        local out = assert(io.open(dir .. "/" .. hash:sub(#list.PREFIX + 1), "wb"))
        local inp = assert(io.open(src, "rb"))
        while true do
            local piece = inp:read(65536)
            if not piece then break end
            out:write(piece)
        end
        inp:close()
        out:close()
        n = n + 1
    end
    return n
end
-- }}}

return list
