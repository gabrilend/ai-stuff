--[[
triggers.lua - a WC3 map's triggers, readied for the server (issue W02e)

The converter's side of W02e. The server's side, the shim that runs a
map's script inside AzerothCore's Lua engine (ALE), lives in
server-side/ale/wc3shim/ under its own licence (AGPL v3:
docs/licensing-and-boundaries.md). This file runs none of it: it reads the
shim's list of the natives it implements (server-side/ale/wc3shim/covered.lua)
as data, in an empty environment.

For a map with a script (war3map.j, or scripts\war3map.j), it writes into
the build folder:

  server/triggers/<dir>/war3map.lua  the script transpiled to Lua (the
                                     project's transpiler, "env" scope, with
                                     the project's runtime's native types,
                                     as src/jass/vm.lua loads it)
  server/triggers/<dir>/map-data.lua what the shim needs of the build: the
                                     map id, map.lua's WC3 -> WoW transform,
                                     W02b's templates, factions and spawns,
                                     the script's global names, typed stand-ins
                                     and the runtime's constants (data)
  server/triggers/<dir>/natives-report.lua  the coverage report (data): every
                                     native and Blizzard.j function the
                                     script calls, how often, whether the
                                     shim has it, and what the project's
                                     own runtime does with it

"Natives" here means every name the script calls but doesn't define:
common.j's natives, and Blizzard.j's functions, which no map carries
(both live in the player's WC3 install). The shim implements both, as the
project's runtime does (src/jass/natives/bj.lua).

    local triggers = require("wowbuild.triggers")
    local scan = triggers.scan(source)                  -- war3map.j text
    local report = triggers.coverage(scan, triggers.covered(DIR), triggers.reference(), templates)
    local summary = triggers.build(source, build_dir, { C = C, ids = ids, transform = t, dir = DIR })
]]

local lexer = require("jass.lexer")
local parser = require("jass.parser")
local transpiler = require("jass.transpiler")

local triggers = {}

-- each map of a build folder has its own: server/triggers/<map directory>/
triggers.FOLDER = "server/triggers"
function triggers.paths(directory)
    local base = triggers.FOLDER .. "/" .. tostring(directory or "map")
    return { folder = base, script = base .. "/war3map.lua", data = base .. "/map-data.lua",
             report = base .. "/natives-report.lua" }
end
triggers.COVERED = "server-side/ale/wc3shim/covered.lua"
-- natives whose second argument is the unit type made (a rawcode)
triggers.CREATES_UNIT = { CreateUnit = 2, CreateUnitAtLoc = 2, CreateUnitAtLocSaveLast = 2,
                          CreateNUnitsAtLoc = 2, CreateNUnitsAtLocFacingLocBJ = 2,
                          CreateCorpse = 2, ReplaceUnitBJ = 2 }

-- {{{ triggers.read_script
-- the map's script from an open archive (mpq's), or nil
function triggers.read_script(archive)
    for _, name in ipairs({ "war3map.j", "scripts\\war3map.j", "Scripts\\war3map.j" }) do
        if archive:has(name) then
            local s = archive:extract(name)
            if s then return s, name end
        end
    end
end
-- }}}

-- {{{ triggers.scan
-- Every call in the script: { calls = name -> sites, defined = name ->
-- true, natives_declared = { names }, globals = { names }, created =
-- type id -> sites (rawcodes given to CreateUnit and friends), ast,
-- errors }
function triggers.scan(source)
    local tokens, lex_errors = lexer.tokenize(source)
    local ast, parse_errors = parser.parse(tokens)
    local S = { calls = {}, defined = {}, natives_declared = {}, globals = {}, created = {}, ast = ast,
                errors = {} }
    for _, e in ipairs(parse_errors or {}) do S.errors[#S.errors + 1] = tostring(e.message or e) end
    S.lex_errors = lex_errors and #lex_errors or 0
    local function rawcode_of(node)
        if type(node) == "table" and node.type == "LITERAL" and (node.literal_type == "rawcode" or node.literal_type == "fourcc") then
            return tostring(node.value)
        end
    end
    local function called(name, args)
        S.calls[name] = (S.calls[name] or 0) + 1
        local at = triggers.CREATES_UNIT[name]
        local id = at and args and rawcode_of(args[at])
        if id then S.created[id] = (S.created[id] or 0) + 1 end
    end
    local function walk(n)
        if type(n) ~= "table" then return end
        local t = n.type
        if t == "FUNCTION_DEF" and n.name then S.defined[n.name] = true
        elseif t == "NATIVE_DECL" and n.name then S.natives_declared[#S.natives_declared + 1] = n.name
        elseif t == "CALL_STMT" and n.name then called(n.name, n.arguments)
        elseif t == "CALL_EXPR" and type(n.callee) == "table" and n.callee.type == "IDENTIFIER" then
            called(n.callee.name, n.arguments)
        elseif t == "GLOBAL_BLOCK" then
            for _, g in ipairs(n.declarations or {}) do if g.name then S.globals[#S.globals + 1] = g.name end end
        end
        for k, v in pairs(n) do
            if type(v) == "table" and k ~= "parent" then walk(v) end
        end
    end
    walk(ast)
    table.sort(S.natives_declared)
    return S
end
-- }}}

-- {{{ triggers.covered
-- The shim's list (data): name -> group, and the groups in order
function triggers.covered(dir)
    local path = (dir or "./"):gsub("/?$", "/") .. triggers.COVERED
    local f = io.open(path, "rb")
    if not f then error("no shim list at " .. path, 0) end
    local text = f:read("*a")
    f:close()
    local chunk, err = loadstring(text, "=" .. triggers.COVERED)
    if not chunk then error(triggers.COVERED .. ": " .. tostring(err), 0) end
    setfenv(chunk, {})
    local ok, list = pcall(chunk)
    if not ok or type(list) ~= "table" then error(triggers.COVERED .. ": " .. tostring(list), 0) end
    local by_name, groups = {}, {}
    for _, g in ipairs(list.groups or {}) do
        local names = {}
        for name in tostring(g.names or ""):gmatch("%S+") do
            by_name[name] = g.name
            names[#names + 1] = name
        end
        groups[#groups + 1] = { name = g.name, about = g.about, names = names }
    end
    return { version = list.version, by_name = by_name, groups = groups }
end
-- }}}

-- {{{ triggers.reference
-- The project's own runtime (src/jass/vm.lua): which names it implements,
-- which of those deliberately do nothing, and its native types (for the
-- transpiler)
function triggers.reference()
    local V = require("jass.vm").new(nil, { player = 0 })
    -- the constants with plain values (numbers, booleans, strings); handles
    -- the runtime makes (bj_FORCE_ALL_PLAYERS ...) are the shim's to make
    local constants = {}
    for k, v in pairs(V.constants) do
        local t = type(v)
        if t == "number" or t == "boolean" or t == "string" then constants[k] = v end
    end
    return { natives = V.natives, noop = V.noop, types = V.types, global_types = V.global_types, constants = constants }
end
-- }}}

-- {{{ triggers.coverage
-- The report for one script. templates: W02b's (each with .id), to name
-- the unit types the script makes that have no creature template.
function triggers.coverage(scan, covered, ref, templates)
    local list = {}
    local n = { names = 0, calls = 0, covered_names = 0, covered_calls = 0, reference_missing = 0, reference_noop = 0 }
    local declared = {}
    for _, name in ipairs(scan.natives_declared) do declared[name] = true end
    for name, sites in pairs(scan.calls) do
        if not scan.defined[name] then
            local group = covered.by_name[name]
            local reference = ref.natives[name] and (ref.noop[name] and "no-op" or "does") or "missing"
            list[#list + 1] = { name = name, calls = sites, shim = group ~= nil, group = group,
                                reference = reference, declared_in_map = declared[name] or nil }
            n.names, n.calls = n.names + 1, n.calls + sites
            if group then n.covered_names, n.covered_calls = n.covered_names + 1, n.covered_calls + sites end
            if reference == "missing" then n.reference_missing = n.reference_missing + 1 end
            if reference == "no-op" then n.reference_noop = n.reference_noop + 1 end
        end
    end
    table.sort(list, function(a, b) return a.calls > b.calls or (a.calls == b.calls and a.name < b.name) end)
    local uncovered = {}
    for _, e in ipairs(list) do if not e.shim then uncovered[#uncovered + 1] = e.name end end
    table.sort(uncovered)
    local has_template = {}
    for _, t in ipairs(templates or {}) do has_template[t.id] = true end
    local no_template = {}
    for id in pairs(scan.created) do if not has_template[id] then no_template[#no_template + 1] = id end end
    table.sort(no_template)
    n.uncovered_names = #uncovered
    n.uncovered_calls = n.calls - n.covered_calls
    n.covered_percent_names = n.names > 0 and math.floor(1000 * n.covered_names / n.names + 0.5) / 10 or 0
    n.covered_percent_calls = n.calls > 0 and math.floor(1000 * n.covered_calls / n.calls + 0.5) / 10 or 0
    return {
        counts = n,
        natives = list,
        uncovered = uncovered,
        unit_types_without_template = no_template,
        natives_declared_in_map = scan.natives_declared,
        parse_errors = #scan.errors > 0 and scan.errors or nil,
        shim = { version = covered.version, groups = (function()
            local g = {}
            for _, x in ipairs(covered.groups) do g[#g + 1] = { name = x.name, about = x.about, natives = #x.names } end
            return g
        end)() },
    }
end
-- }}}

-- {{{ triggers.map_data
-- What the shim reads of the build (map-data.lua): o = { C = creatures.prepare's,
-- ids = W02c's, transform = map.lua's wc3_to_wow, directory, globals,
-- stubs = name -> "integer" | "real" | "string" for natives the shim lacks,
-- constants = the reference runtime's constants with plain values }
function triggers.map_data(o)
    local C = o.C
    local templates, factions, spawns = {}, {}, {}
    for _, t in ipairs(C and C.templates or {}) do
        templates[#templates + 1] = { id = t.id, faction = t.faction.template, entry = t.entry, name = t.name }
    end
    for _, f in ipairs(C and C.factions or {}) do
        factions[#factions + 1] = { template = f.template, name = f.name, players = f.players }
    end
    for _, s in ipairs(C and C.spawns or {}) do
        spawns[#spawns + 1] = { guid = s.guid, entry = s.template.entry, id = s.id, player = s.player,
                                x = s.wc3[1], y = s.wc3[2] }
    end
    local T = o.transform or {}
    return {
        format = 1,
        map = { id = o.ids and o.ids.map or 0, instance = 0, directory = o.directory },
        wc3_to_wow = { scale = T.scale, x0 = T.x0, y0 = T.y0, rule = T.rule },
        templates = templates,
        factions = factions,
        spawns = spawns,
        globals = o.globals or {},
        stubs = o.stubs or {},
        constants = o.constants or {},
    }
end
-- }}}

-- {{{ triggers.build
-- source: the script text (or nil). o: { C, ids, transform, directory,
-- dir (this project's folder, for the shim's list), serialize (data ->
-- Lua text), write (path, bytes) }. Returns the summary for the
-- conversion report, and the files written.
function triggers.build(source, build_dir, o)
    local files = {}
    local P = triggers.paths(o.directory)
    local function put(rel, text)
        o.write(build_dir .. "/" .. rel, text)
        files[#files + 1] = { path = rel, bytes = #text }
    end
    os.execute("rm -rf '" .. (build_dir .. "/" .. P.folder):gsub("'", "'\\''") .. "'")
    os.execute("mkdir -p '" .. (build_dir .. "/" .. P.folder):gsub("'", "'\\''") .. "'")
    if not source then
        local text = "-- W02e: this map has no script (war3map.j), so nothing runs on the server\nreturn " ..
            o.serialize({ format = 1, script = false }) .. "\n"
        put(P.report, text)
        return { script = false, report = P.report }, files
    end
    local t0 = os.clock()
    local scan = triggers.scan(source)
    local ref = triggers.reference()
    local covered = triggers.covered(o.dir)
    local report = triggers.coverage(scan, covered, ref, o.C and o.C.templates)
    report.format = 1
    report.map = o.directory
    report.script = { name = o.script_name or "war3map.j", bytes = #source }

    -- the script, transpiled as the project's runtime loads it
    local transpiled = { file = P.script }
    if #scan.errors == 0 then
        local lua, errors = transpiler.transpile(scan.ast, { scope = "env", native_types = ref.types,
                                                             global_types = ref.global_types })
        if errors and #errors > 0 then
            transpiled.error = tostring(errors[1].message or errors[1])
            transpiled.errors = #errors
        end
        if lua and not transpiled.error then
            local ok, err = loadstring(lua, "=war3map.lua")
            if not ok then transpiled.error = "lua: " .. tostring(err) end
        end
        if lua and not transpiled.error then
            put(P.script, "-- W02e: " .. tostring(o.directory) .. "'s war3map.j, transpiled for the server's wc3shim (src/wowbuild/triggers.lua)\n" .. lua)
            transpiled.bytes = #lua
        end
    else
        transpiled.error = "parse: " .. scan.errors[1]
    end
    report.transpiled = transpiled

    -- the natives the shim lacks that answer a number or a string: their
    -- stand-ins answer 0 or "" (the reference runtime's types), so the
    -- arithmetic around them keeps the thread going
    local stubs = {}
    for _, name in ipairs(report.uncovered) do
        local kind = ref.types[name]
        if kind == "integer" or kind == "real" or kind == "string" then stubs[name] = kind end
    end
    local data = triggers.map_data({ C = o.C, ids = o.ids, transform = o.transform, directory = o.directory,
                                     globals = scan.globals, stubs = stubs, constants = ref.constants })
    put(P.data, "-- W02e: what the server's wc3shim reads of this build (src/wowbuild/triggers.lua): data only\nreturn " ..
        o.serialize(data) .. "\n")
    report.seconds = os.clock() - t0
    put(P.report, "-- W02e: the natives this map's script calls, and which the server's wc3shim has (src/wowbuild/triggers.lua): data only\nreturn " ..
        o.serialize(report) .. "\n")
    local c = report.counts
    return {
        script = true, report = P.report, transpiled = transpiled.error == nil, transpile_error = transpiled.error,
        names = c.names, calls = c.calls, covered_names = c.covered_names, covered_calls = c.covered_calls,
        covered_percent_names = c.covered_percent_names, covered_percent_calls = c.covered_percent_calls,
        uncovered = c.uncovered_names, reference_missing = c.reference_missing,
        unit_types_without_template = #report.unit_types_without_template,
    }, files
end
-- }}}

return triggers
