--[[
Overrides: a Player's Own Models in Place of the Ones a Map Asks For (Issue 504)

The owner, 2026-09-26: "use the models that the map requests. Even if
they're stock. The user will build per-stock-model overrides that they can
then have rendered on their end." An override says: wherever a map asks
for this model path, draw this file instead, on my machine only. A set of
overrides is one plain text file, so it can be passed to another player
over rmail (609) as it is; "asset pack" now means such a set.

The file is data, never code: it is read line by line and nothing in it
runs, so a set received from someone else can't do anything but name
models. Its form:

    wete-overrides 1
    # a comment; blank lines are skipped
    name<TAB>Grim footmen
    override<TAB>Units\Human\Footman\Footman<TAB>sha256:<64 hex><TAB>scale=1.2<TAB>tint=255,200,200
    override<TAB>Doodads\Terrain\LordaeronTree\LordaeronTree<TAB>sha256:<64 hex><TAB>team_colour=off<TAB>map=sha256:<64 hex>

  first line   "wete-overrides" and the format's version, 1
  name         the set's name, shown when it is passed on (optional, once)
  override     the model path replaced; the file replacing it, by its hash
               in the player's store (issue 604, assets/dedup.lua); then any
               of, each at most once:
                 scale=N         a number above 0, multiplied with the
                                 unit's own scale; default 1
                 tint=R,G,B      0-255 each, multiplied with the unit's own
                                 tint; default 255,255,255
                 team_colour=on  the replacement's team-colour textures take
                                 the owner's colour (default); "off" keeps
                                 the replacement's own texture there
                 map=HASH        only on the map whose file has this hash;
                                 default: every map

A model path matches whatever its case, slash direction or extension
(.mdx, .mdl or none), as the game's paths do. On one map, an override for
that map wins over one for every map. A file naming the same path twice
for the same scope is refused, with both line numbers.

    local overrides = require("assets.overrides")
    local set = overrides.load(overrides.file_for(ROOT))     -- an empty set when there is none
    local entry = set:lookup("units\\human\\footman\\footman.mdx", map_hash)
    entry.file, entry.scale, entry.tint, entry.team_colour   -- "sha256:...", 1.2, {255,200,200}, true
    set:add({ path = "...", file = "sha256:...", scale = 1.2 })
    set:remove("...", map_hash_or_nil)
    overrides.save(set, path)                                -- written whole, then renamed into place
    local both, conflicts = overrides.merge({ mine, theirs })   -- the first set wins a conflict
]]

local overrides = {}

overrides.HEADER = "wete-overrides"
overrides.VERSION = 1
overrides.FILE_NAME = "overrides.txt"

local HASH = "^sha256:%x+$"

-- {{{ function overrides.key
-- The form paths are compared in: lower case, forward slashes, no leading
-- slash, no .mdx or .mdl.
function overrides.key(path)
    local k = path:gsub("\\", "/"):gsub("^/+", ""):lower()
    k = k:gsub("%.mdx$", ""):gsub("%.mdl$", "")
    return k
end
-- }}}

-- {{{ local function is_hash
local function is_hash(s)
    return type(s) == "string" and #s == 71 and s:match(HASH) ~= nil and s == s:lower()
end
-- }}}

local Set = {}
Set.__index = Set

-- {{{ function overrides.new
-- An empty set, optionally named.
function overrides.new(name)
    return setmetatable({ name = name, entries = {}, by_scope = {} }, Set)
end
-- }}}

-- {{{ local function scope_of
local function scope_of(map)
    return map or "*"
end
-- }}}

-- {{{ local function check_entry
-- An entry's fields, checked and filled with defaults; nil and a reason
-- when one is wrong.
local function check_entry(e)
    if type(e.path) ~= "string" or e.path == "" or e.path:find("[\t\r\n]") then
        return nil, "the model path is missing or holds a tab or line break"
    end
    if not is_hash(e.file) then
        return nil, "the file must be a hash, sha256: and 64 lower-case hex digits"
    end
    if e.map ~= nil and not is_hash(e.map) then
        return nil, "map must be a hash, sha256: and 64 lower-case hex digits"
    end
    local scale = e.scale == nil and 1 or e.scale
    if type(scale) ~= "number" or not (scale > 0) or scale == math.huge then
        return nil, "scale must be a number above 0"
    end
    local tint = e.tint or { 255, 255, 255 }
    if type(tint) ~= "table" or #tint ~= 3 then
        return nil, "tint must be three numbers"
    end
    for i = 1, 3 do
        local c = tint[i]
        if type(c) ~= "number" or c < 0 or c > 255 or c % 1 ~= 0 then
            return nil, "tint must be three whole numbers from 0 to 255"
        end
    end
    local team = e.team_colour
    if team == nil then team = true end
    if type(team) ~= "boolean" then
        return nil, "team_colour must be on or off"
    end
    return {
        path = e.path, key = overrides.key(e.path), file = e.file, map = e.map,
        scale = scale, tint = { tint[1], tint[2], tint[3] }, team_colour = team,
        line = e.line,
    }
end
-- }}}

-- {{{ function Set:add
-- Adds one override (a table with path, file and any of scale, tint,
-- team_colour, map). One already there for the same path and scope is
-- replaced: the player changed their mind. Returns the entry, or nil and
-- a reason.
function Set:add(e)
    local entry, why = check_entry(e)
    if not entry then
        return nil, why
    end
    local scope = scope_of(entry.map)
    self.by_scope[scope] = self.by_scope[scope] or {}
    local old = self.by_scope[scope][entry.key]
    if old then
        for i, x in ipairs(self.entries) do
            if x == old then
                table.remove(self.entries, i)
                break
            end
        end
    end
    self.by_scope[scope][entry.key] = entry
    self.entries[#self.entries + 1] = entry
    return entry
end
-- }}}

-- {{{ function Set:remove
-- Takes the override for this path and scope (nil: every map) out.
-- Returns true when there was one.
function Set:remove(path, map)
    local scope = self.by_scope[scope_of(map)]
    local key = overrides.key(path)
    local entry = scope and scope[key]
    if not entry then
        return false
    end
    scope[key] = nil
    for i, x in ipairs(self.entries) do
        if x == entry then
            table.remove(self.entries, i)
            break
        end
    end
    return true
end
-- }}}

-- {{{ function Set:lookup
-- The override for a model path on a map (its file's hash, or nil when
-- unknown): the map's own first, then the one for every map; nil when
-- neither.
function Set:lookup(path, map)
    local key = overrides.key(path)
    if map then
        local own = self.by_scope[map]
        if own and own[key] then
            return own[key]
        end
    end
    local every = self.by_scope["*"]
    return every and every[key] or nil
end
-- }}}

-- {{{ function Set:count
function Set:count()
    return #self.entries
end
-- }}}

-- {{{ local function parse_option
-- One key=value of an override line into the entry table; a reason when
-- it can't be read.
local function parse_option(e, field, seen)
    local k, v = field:match("^([%w_]+)=(.*)$")
    if not k then
        return "expected key=value, got " .. string.format("%q", field)
    end
    if seen[k] then
        return k .. " given twice"
    end
    seen[k] = true
    if k == "scale" then
        e.scale = tonumber(v)
        if not e.scale then return "scale is not a number: " .. v end
    elseif k == "tint" then
        local r, g, b = v:match("^(%d+),(%d+),(%d+)$")
        if not r then return "tint must be R,G,B: " .. v end
        e.tint = { tonumber(r), tonumber(g), tonumber(b) }
    elseif k == "team_colour" then
        if v == "on" then e.team_colour = true
        elseif v == "off" then e.team_colour = false
        else return "team_colour must be on or off: " .. v end
    elseif k == "map" then
        e.map = v
    else
        return "unknown option " .. k
    end
    return nil
end
-- }}}

-- {{{ local function split_tabs
local function split_tabs(line)
    local fields = {}
    for field in (line .. "\t"):gmatch("([^\t]*)\t") do
        fields[#fields + 1] = field
    end
    return fields
end
-- }}}

-- {{{ function overrides.parse
-- A set from a file's text. source names it in messages. Returns the set,
-- or nil and a list of "source:line: problem" strings: every problem in
-- the file, not only the first.
function overrides.parse(text, source)
    source = source or "overrides"
    local set = overrides.new()
    local problems = {}
    local function problem(n, msg)
        problems[#problems + 1] = string.format("%s:%d: %s", source, n, msg)
    end
    local n = 0
    local header_seen = false
    for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        local line = raw:gsub("\r$", "")
        if not header_seen then
            local word, version = line:match("^(%S+) (%d+)$")
            if word ~= overrides.HEADER then
                problem(n, "not an overrides file (the first line must be \"" .. overrides.HEADER .. " 1\")")
                return nil, problems
            end
            if tonumber(version) ~= overrides.VERSION then
                problem(n, "format version " .. version .. " is not known (this reader knows 1)")
                return nil, problems
            end
            header_seen = true
        elseif line == "" or line:match("^#") then
            -- blank, or a comment
        else
            local fields = split_tabs(line)
            local kind = fields[1]
            if kind == "name" then
                if #fields ~= 2 or fields[2] == "" then
                    problem(n, "name takes one value")
                elseif set.name then
                    problem(n, "the set is named twice")
                else
                    set.name = fields[2]
                end
            elseif kind == "override" then
                local e = { path = fields[2], file = fields[3], line = n }
                local seen, bad = {}, nil
                for i = 4, #fields do
                    bad = parse_option(e, fields[i], seen)
                    if bad then break end
                end
                if #fields < 3 then
                    problem(n, "an override needs a model path and a file")
                elseif bad then
                    problem(n, bad)
                else
                    local entry, why = check_entry(e)
                    if not entry then
                        problem(n, why)
                    else
                        local scope = set.by_scope[scope_of(entry.map)]
                        local earlier = scope and scope[entry.key]
                        if earlier then
                            problem(n, "the same model path and map as line " .. tostring(earlier.line))
                        else
                            set:add(entry)
                        end
                    end
                end
            else
                problem(n, "unknown line kind " .. string.format("%q", kind))
            end
        end
    end
    if #problems > 0 then
        return nil, problems
    end
    return set
end
-- }}}

-- {{{ local function number_text
-- A number as the file writes it: whole numbers without a point, others
-- with as few digits as read back the same.
local function number_text(x)
    if x % 1 == 0 and math.abs(x) < 2 ^ 53 then
        return string.format("%d", x)
    end
    for digits = 1, 17 do
        local s = string.format("%." .. digits .. "g", x)
        if tonumber(s) == x then
            return s
        end
    end
    return string.format("%.17g", x)
end
-- }}}

-- {{{ function overrides.write
-- The set as file text: the header, its name, then one line per override
-- in the order added. Options at their defaults are left out.
function overrides.write(set)
    local lines = { overrides.HEADER .. " " .. overrides.VERSION }
    if set.name then
        lines[#lines + 1] = "name\t" .. set.name
    end
    for _, e in ipairs(set.entries) do
        local fields = { "override", e.path, e.file }
        if e.scale ~= 1 then
            fields[#fields + 1] = "scale=" .. number_text(e.scale)
        end
        if e.tint[1] ~= 255 or e.tint[2] ~= 255 or e.tint[3] ~= 255 then
            fields[#fields + 1] = string.format("tint=%d,%d,%d", e.tint[1], e.tint[2], e.tint[3])
        end
        if not e.team_colour then
            fields[#fields + 1] = "team_colour=off"
        end
        if e.map then
            fields[#fields + 1] = "map=" .. e.map
        end
        lines[#lines + 1] = table.concat(fields, "\t")
    end
    return table.concat(lines, "\n") .. "\n"
end
-- }}}

-- {{{ function overrides.file_for
-- The player's own overrides file: <player data>/overrides.txt.
function overrides.file_for(root)
    return require("assets.player_data").folder(root) .. "/" .. overrides.FILE_NAME
end
-- }}}

-- {{{ function overrides.load
-- The set in a file; an empty set when the file isn't there (no overrides
-- yet). A file that is there but wrong is an error listing its problems:
-- the player meant something by it.
function overrides.load(path)
    local f = io.open(path, "rb")
    if not f then
        return overrides.new()
    end
    local text = f:read("*a")
    f:close()
    local set, problems = overrides.parse(text, path)
    if not set then
        error("overrides: " .. path .. " can't be read:\n  " .. table.concat(problems, "\n  "), 2)
    end
    return set
end
-- }}}

-- {{{ function overrides.save
-- Writes the set to a file: to a file beside it first, then renamed into
-- place, so a reader never sees half a file.
function overrides.save(set, path)
    local part = path .. ".part"
    local f, err = io.open(part, "wb")
    if not f then
        error("overrides: can't write " .. part .. ": " .. tostring(err), 2)
    end
    f:write(overrides.write(set))
    f:close()
    local ok, rename_err = os.rename(part, path)
    if not ok then
        os.remove(part)
        error("overrides: can't put " .. path .. " in place: " .. tostring(rename_err), 2)
    end
    return path
end
-- }}}

-- {{{ function overrides.merge
-- One set from several, in priority order: for each path and scope the
-- first set that has one wins. Returns the merged set and a list of
-- conflicts { path, map, kept (set name or position), dropped } where two
-- sets named different files.
function overrides.merge(sets)
    local merged = overrides.new()
    local conflicts = {}
    local from = {}
    for i, set in ipairs(sets) do
        local label = set.name or ("set " .. i)
        for _, e in ipairs(set.entries) do
            local here = merged:lookup(e.path, e.map)
            if here and here.map == e.map then
                if here.file ~= e.file then
                    conflicts[#conflicts + 1] = { path = e.path, map = e.map, kept = from[here], dropped = label }
                end
            else
                local entry = merged:add(e)
                from[entry] = label
            end
        end
    end
    return merged, conflicts
end
-- }}}

overrides.Set = Set

return overrides
