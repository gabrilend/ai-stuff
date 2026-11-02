--[[
Catalogue: The Maps and Models a Source Offers (Issue 603)

One file per source, under <player data>/catalogue/<source>.lua: a Lua
table of entries, written by the finders and the downloader and read by
the catalogue viewer (issue 1001). The file is plain data: it is read with
no access to anything (no functions, no globals), so a catalogue can't run
code.

    local catalogue = require("fetch.catalogue")
    catalogue.write(path, { source = "my-folder", entries = { ... } })
    local cat = catalogue.read(path)       -- nil and a message when absent or damaged

An entry (issue 603's fields; only kind and title are required):
    kind              "map" or "model"
    title, author, version, posted, terms   strings, as the source states them
    page_url, download_url, preview_url     strings
    size_bytes        integer
    published_hash    "sha256:..." when the source publishes one (a download must match it)
    hash              "sha256:...", once downloaded
    checked           what the downloader verified, once downloaded
]]

local catalogue = {}

catalogue.KINDS = { map = true, model = true }

-- {{{ local function serialize
local function serialize(v, indent, out)
    local t = type(v)
    if t == "string" then
        out[#out + 1] = string.format("%q", v)
    elseif t == "number" then
        out[#out + 1] = (v == math.floor(v) and math.abs(v) < 2^53) and string.format("%d", v) or string.format("%.17g", v)
    elseif t == "boolean" then
        out[#out + 1] = tostring(v)
    elseif t == "table" then
        out[#out + 1] = "{\n"
        local pad = string.rep("    ", indent + 1)
        local n = #v
        for i = 1, n do
            out[#out + 1] = pad
            serialize(v[i], indent + 1, out)
            out[#out + 1] = ",\n"
        end
        local keys = {}
        for k in pairs(v) do
            if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then
                if type(k) ~= "string" then error("catalogue: a key must be a string, got " .. type(k)) end
                keys[#keys + 1] = k
            end
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            out[#out + 1] = pad
            out[#out + 1] = k:match("^[%a_][%w_]*$") and k or ("[" .. string.format("%q", k) .. "]")
            out[#out + 1] = " = "
            serialize(v[k], indent + 1, out)
            out[#out + 1] = ",\n"
        end
        out[#out + 1] = string.rep("    ", indent) .. "}"
    else
        error("catalogue: can't store a " .. t)
    end
end
-- }}}

-- {{{ function catalogue.check
-- Raises when an entry lacks what every entry must have.
function catalogue.check(entry, i)
    local where = "catalogue: entry " .. tostring(i or "?")
    if type(entry) ~= "table" then error(where .. " isn't a table", 3) end
    if not catalogue.KINDS[entry.kind] then error(where .. ": kind is \"map\" or \"model\", got " .. tostring(entry.kind), 3) end
    if type(entry.title) ~= "string" or entry.title == "" then error(where .. " has no title", 3) end
end
-- }}}

-- {{{ function catalogue.write
-- Writes CAT ({ source, entries }) to PATH, by way of a file beside it.
function catalogue.write(path, cat)
    if type(cat) ~= "table" or type(cat.source) ~= "string" or type(cat.entries) ~= "table" then
        error("catalogue.write: wants { source = NAME, entries = { ... } }", 2)
    end
    for i, e in ipairs(cat.entries) do catalogue.check(e, i) end
    local out = { "-- The catalogue of one source (issue 603). Plain data: written by\n",
                  "-- src/fetch, read by the catalogue viewer (1001).\nreturn " }
    serialize(cat, 0, out)
    out[#out + 1] = "\n"
    local dir = path:match("^(.*)/[^/]+$")
    if dir then os.execute("mkdir -p '" .. dir:gsub("'", "'\\''") .. "'") end
    local part = path .. ".part"
    local f = assert(io.open(part, "wb"))
    f:write(table.concat(out))
    f:close()
    assert(os.rename(part, path))
end
-- }}}

-- {{{ function catalogue.read
-- The catalogue at PATH, or nil and a message. Loaded as text only, with
-- an empty environment.
function catalogue.read(path)
    local f = io.open(path, "rb")
    if not f then return nil, "no catalogue at " .. path end
    local text = f:read("*a")
    f:close()
    if text:byte(1) == 27 then return nil, path .. " is compiled code, not a catalogue" end
    local chunk, err
    if setfenv then
        chunk, err = loadstring(text, "=" .. path)
        if chunk then setfenv(chunk, {}) end
    else
        chunk, err = load(text, "=" .. path, "t", {})
    end
    if not chunk then return nil, "the catalogue " .. path .. " doesn't load: " .. tostring(err) end
    local ok, cat = pcall(chunk)
    if not ok then return nil, "the catalogue " .. path .. " raised an error: " .. tostring(cat) end
    if type(cat) ~= "table" or type(cat.entries) ~= "table" then
        return nil, "the catalogue " .. path .. " isn't { source, entries }"
    end
    for i, e in ipairs(cat.entries) do
        local good, msg = pcall(catalogue.check, e, i)
        if not good then return nil, msg end
    end
    return cat
end
-- }}}

return catalogue
