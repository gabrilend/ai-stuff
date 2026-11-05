--[[
install_plan.lua - what installing a build folder into AzerothCore means, as data (issue W02f, step 2)

W02's converter writes the server's files into the build folder; nothing
puts them into a server yet (W02f step 3 will). This writes down, before
anything is installed, exactly what an install would do, as
<build>/install-plan.lua (data, read in an empty environment):

  sql      the build's SQL files, in the order they are run, and the
           database each goes into
  tables   every statement of them: which table of which database, what
           it does (delete, with its WHERE; insert; replace), its columns
           (or how many values a row has, for a table filled by
           position), and how many rows
  files    each file the server reads, from the build folder to a place
           (a symbolic folder: the owner's settings say where it is) and
           a path under it, including the shim (server-side/ale/wc3shim/,
           which the converter copies into the build as server/ale/)
  kept     the build's other server files and why nothing installs them
  places   what each place is, and that none of it is checked against a
           real AzerothCore
  waiting  what an install will need that isn't built

install_plan.check(plan, schema, build_dir) checks a plan against a schema
(databases -> tables -> columns) and the build folder: every table and
column exists, every row has as many values as its columns, every file is
there, the stamp names it, and every file the stamp names is installed,
run or kept with a reason. The tests check it against a stand-in for
W02h's empty world database (src/tests/fixtures/install-plan/); step 3 is
to run the same check against the owner's server before installing.

NOTHING HERE IS CHECKED AGAINST AZEROTHCORE OR ALE. The places are from
memory and from this repository's notes (docs/wow-client-bridge.md:
where the owner's server data is; docs/archive/: older notes naming the
world database acore_world and ALE's lua_scripts/); the tables and
columns are the ones the converter writes (creatures.lua, dbc.lua), whose
layouts are themselves from memory. W02f lists each as unchecked.

    local install_plan = require("wowbuild.install_plan")
    install_plan.copy_shim(build_dir, project_dir)   -- server/ale/wc3shim/, server/ale/LICENSE
    local plan = install_plan.write(build_dir, serialize)
    local ok, problems = install_plan.check(install_plan.read(build_dir), schema, build_dir)
]]

local server_stamp = require("wowbuild.server_stamp")

local install_plan = {}

install_plan.FILE = "install-plan.lua"
install_plan.FORMAT = 1

-- the shim, copied into the build as bytes (the converter runs none of
-- it): every module but the stand-in for ALE, and the folder's licence
install_plan.SHIM = {
    from = "server-side/ale/wc3shim",
    to = "server/ale/wc3shim",
    leave_out = { ["fake_ale.lua"] = "a stand-in for ALE's API, for the tests" },
    licence = { from = "server-side/LICENSE", to = "server/ale/LICENSE" },
}

-- the SQL files, in the order they run: the tables' rows before the
-- creatures that name their factions and display ids
install_plan.SQL = {
    { file = "server/dbc.sql", database = "world", what = "the client tables' rows for the <table>_dbc copies (W02c)" },
    { file = "server/world.sql", database = "world", what = "the creatures (W02b, W02h)" },
}

-- where things go. Every one is from memory or from this repository's
-- notes, none checked against a running AzerothCore (W02f)
install_plan.PLACES = {
    world = { kind = "database", checked = false,
        what = "AzerothCore's world database: W02h's tables with no rows but the maps'",
        note = "named in the worldserver's settings (from memory); this repository's archived notes call it acore_world (docs/archive/azerothcore-2026-01-07)" },
    dbc = { kind = "folder", checked = false,
        what = "the folder the worldserver reads its DBC files from when it starts",
        note = "the owner's extracted server data has dbc/ beside maps/, vmaps/ and mmaps/ (docs/wow-client-bridge.md); that the worldserver reads it through its data folder setting is from memory" },
    ale_scripts = { kind = "folder", checked = false,
        what = "the folder ALE runs Lua scripts from",
        note = "lua_scripts/ beside the worldserver, from memory (W02e, left open 5); how require finds wc3shim there is unchecked" },
    ale_maps = { kind = "folder", checked = false,
        what = "where W02f step 3's loader reads each map's script and data",
        note = "kept out of ale_scripts: ALE runs every .lua there (from memory), and a map's script runs only inside the shim" },
}

-- {{{ helpers
local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function write_file(path, bytes)
    local f, err = io.open(path, "wb")
    if not f then error("can't write " .. path .. ": " .. tostring(err), 0) end
    f:write(bytes)
    f:close()
end

local function list_dir(dir)
    local out = {}
    local p = io.popen("ls -1 " .. quote(dir) .. " 2>/dev/null")
    if p then for name in p:lines() do out[#out + 1] = name end p:close() end
    table.sort(out)
    return out
end
-- }}}

-- {{{ install_plan.copy_shim: the shim's files into the build, as bytes
-- dir: this project's folder. Returns the files written ({ path, bytes })
function install_plan.copy_shim(build_dir, dir)
    dir = (dir or "./"):gsub("/?$", "/")
    local S = install_plan.SHIM
    local out_dir = build_dir .. "/" .. S.to
    os.execute("rm -rf " .. quote(out_dir))
    local made = os.execute("mkdir -p " .. quote(out_dir))
    if made ~= 0 and made ~= true then error("can't make " .. out_dir, 0) end
    local files = {}
    for _, name in ipairs(list_dir(dir .. S.from)) do
        if name:match("%.lua$") and not S.leave_out[name] then
            local bytes = read_file(dir .. S.from .. "/" .. name)
            if not bytes then error("can't read the shim's " .. name, 0) end
            write_file(out_dir .. "/" .. name, bytes)
            files[#files + 1] = { path = S.to .. "/" .. name, bytes = #bytes }
        end
    end
    if #files == 0 then error("no shim at " .. dir .. S.from, 0) end
    local lic = read_file(dir .. S.licence.from)
    if not lic then error("no licence at " .. dir .. S.licence.from, 0) end
    write_file(build_dir .. "/" .. S.licence.to, lic)
    files[#files + 1] = { path = S.licence.to, bytes = #lic }
    return files
end
-- }}}

-- {{{ install_plan.statements: the converter's SQL, statement by statement
-- Reads what the converter writes (creatures.sql, output's server_sql),
-- not SQL in general: comments, quoted strings ('' and \ escapes),
-- `names`, and the statements DELETE FROM, INSERT INTO, REPLACE INTO
-- (with or without a column list) and SET. Anything else is kept as
-- { does = "other" }, which check refuses.
local function tokens(text)
    local out, i, n = {}, 1, #text
    while i <= n do
        local c = text:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c == "-" and text:sub(i + 1, i + 1) == "-" then
            local e = text:find("\n", i, true)
            i = e and e + 1 or n + 1
        elseif c == "/" and text:sub(i + 1, i + 1) == "*" then
            local e = text:find("*/", i + 2, true)
            i = e and e + 2 or n + 1
        elseif c == "'" then
            local j = i + 1
            while j <= n do
                local d = text:sub(j, j)
                if d == "\\" then j = j + 2
                elseif d == "'" and text:sub(j + 1, j + 1) == "'" then j = j + 2
                elseif d == "'" then break
                else j = j + 1 end
            end
            out[#out + 1] = { t = "value" }
            i = j + 1
        elseif c == "`" then
            local e = text:find("`", i + 1, true) or n
            out[#out + 1] = { t = "name", v = text:sub(i + 1, e - 1) }
            i = e + 1
        elseif c:match("[%(%),;]") then
            out[#out + 1] = { t = c }
            i = i + 1
        else
            local j = i
            while j <= n and not text:sub(j, j):match("[%s%(%),;'`]") do j = j + 1 end
            local word = text:sub(i, j - 1)
            out[#out + 1] = { t = "word", v = word:upper(), raw = word }
            i = j
        end
    end
    return out
end

function install_plan.statements(text)
    local list, cur = {}, {}
    for _, tk in ipairs(tokens(text or "")) do
        if tk.t == ";" then
            if #cur > 0 then list[#list + 1] = cur end
            cur = {}
        else
            cur[#cur + 1] = tk
        end
    end
    if #cur > 0 then list[#list + 1] = cur end
    local out = {}
    for _, s in ipairs(list) do
        local w1, w2 = s[1].v, s[2] and s[2].v
        local st
        local function rest(from)
            local o = {}
            for j = from, #s do
                local tk = s[j]
                o[#o + 1] = tk.t == "name" and ("`" .. tk.v .. "`") or tk.t == "word" and tk.raw or tk.t == "value" and "'...'" or tk.t
            end
            return table.concat(o, " ")
        end
        if w1 == "SET" then
            st = { does = "set", set = rest(2) }
        elseif w1 == "DELETE" and w2 == "FROM" and s[3] and s[3].t == "name" then
            st = { does = "delete", table = s[3].v }
            if s[4] and s[4].v == "WHERE" then st.where = rest(5) end
        elseif (w1 == "INSERT" or w1 == "REPLACE") and w2 == "INTO" and s[3] and s[3].t == "name" then
            st = { does = w1:lower(), table = s[3].v, rows = 0 }
            local k = 4
            if s[k] and s[k].t == "(" then
                st.columns = {}
                k = k + 1
                while s[k] and s[k].t ~= ")" do
                    if s[k].t == "name" then st.columns[#st.columns + 1] = s[k].v
                    elseif s[k].t ~= "," then st.odd = true end
                    k = k + 1
                end
                k = k + 1
            end
            if not (s[k] and s[k].v == "VALUES") then
                st = { does = "other", table = st.table }
            else
                -- each top-level ( ... ) is a row; its values are the
                -- commas one level in, plus one
                local depth, width, widths = 0, 0, {}
                for j = k + 1, #s do
                    local t = s[j].t
                    if t == "(" then
                        depth = depth + 1
                        if depth == 1 then width = 1 end
                    elseif t == ")" then
                        if depth == 1 then st.rows = st.rows + 1 widths[width] = true end
                        depth = depth - 1
                    elseif t == "," and depth == 1 then
                        width = width + 1
                    end
                end
                local seen = {}
                for wd in pairs(widths) do seen[#seen + 1] = wd end
                table.sort(seen)
                if #seen == 1 then st.values = seen[1]
                elseif #seen > 1 then st.values_differ = seen end
            end
        else
            st = { does = "other", first = w1 }
        end
        out[#out + 1] = st
    end
    return out
end
-- }}}

-- {{{ install_plan.make: the plan of a build folder as it is now
function install_plan.make(build_dir)
    local plan = { format = install_plan.FORMAT, sql = {}, tables = {}, files = {}, kept = {}, waiting = {}, places = {} }
    for name, p in pairs(install_plan.PLACES) do
        plan.places[name] = { kind = p.kind, what = p.what, note = p.note, checked = p.checked }
    end
    -- the SQL, in its order
    for _, q in ipairs(install_plan.SQL) do
        local text = read_file(build_dir .. "/" .. q.file)
        if text then
            local entry = { file = q.file, database = q.database, what = q.what }
            plan.sql[#plan.sql + 1] = entry
            for _, st in ipairs(install_plan.statements(text)) do
                if st.does == "set" then
                    entry.sets = entry.sets or {}
                    entry.sets[#entry.sets + 1] = st.set
                else
                    st.database = q.database
                    st.from = q.file
                    plan.tables[#plan.tables + 1] = st
                end
            end
        end
    end
    -- the files, each to its place
    local function file(from, place, to, extra)
        local f = { from = from, place = place, to = to }
        for k, v in pairs(extra or {}) do f[k] = v end
        plan.files[#plan.files + 1] = f
    end
    for _, name in ipairs(list_dir(build_dir .. "/server/dbc")) do
        if name:sub(-4) == ".dbc" then
            file("server/dbc/" .. name, "dbc", name,
                { replaces = "the stock table of that name: this one is it with the maps' rows added; keep the stock one to put back" })
        end
    end
    local S = install_plan.SHIM
    for _, name in ipairs(list_dir(build_dir .. "/" .. S.to)) do
        if name:match("%.lua$") then file(S.to .. "/" .. name, "ale_scripts", "wc3shim/" .. name) end
    end
    if read_file(build_dir .. "/" .. S.licence.to) then
        file(S.licence.to, "ale_scripts", "wc3shim/LICENSE",
            { stamped = false, why = "the server doesn't read it: it goes with the shim's code (AGPL v3)" })
    end
    local maps = {}
    for _, dir in ipairs(list_dir(build_dir .. "/server/triggers")) do
        local any = false
        for _, leaf in ipairs({ "war3map.lua", "map-data.lua" }) do
            local rel = "server/triggers/" .. dir .. "/" .. leaf
            if read_file(build_dir .. "/" .. rel) then file(rel, "ale_maps", dir .. "/" .. leaf) any = true end
        end
        if read_file(build_dir .. "/server/triggers/" .. dir .. "/natives-report.lua") then any = true end
        if any then maps[#maps + 1] = dir end
    end
    -- what isn't installed, and why
    if read_file(build_dir .. "/patch-W.MPQ") then
        plan.kept[#plan.kept + 1] = { file = "patch-W.MPQ",
            why = "the stock client's (W02f step 4), and what AzerothCore's extractors read for the server's maps (W02d)" }
    end
    -- what isn't built
    for _, dir in ipairs(maps) do
        plan.waiting[#plan.waiting + 1] = "W02d: the server's maps/, vmaps/ and mmaps/ files for " .. dir ..
            ", made by AzerothCore's extractors from the client with patch-W.MPQ"
    end
    plan.waiting[#plan.waiting + 1] = "W02f step 3: the loader in ale_scripts that starts each map's script in the shim, and the install itself"
    return plan
end
-- }}}

-- {{{ install_plan.write / read
-- serialize: data -> Lua text (wowbuild.serialize: keys sorted, so the same
-- build gives the same plan, byte for byte)
function install_plan.write(build_dir, serialize)
    local plan = install_plan.make(build_dir)
    local text = "-- W02f step 2: what installing this build folder into AzerothCore means (src/wowbuild/install_plan.lua).\n" ..
        "-- Data only. Nothing in it is checked against a real AzerothCore or ALE: see issues/W02f-launcher-and-loader.md.\n" ..
        "return " .. serialize(plan) .. "\n"
    local path = build_dir .. "/" .. install_plan.FILE
    write_file(path .. ".part", text)
    local ok, e = os.rename(path .. ".part", path)
    if not ok then error("can't write " .. path .. ": " .. tostring(e), 0) end
    return plan, text
end

function install_plan.remove(build_dir)
    os.remove(build_dir .. "/" .. install_plan.FILE)
end

-- the plan, read in an empty environment, or nil and why
function install_plan.read(build_dir)
    local text = read_file(build_dir .. "/" .. install_plan.FILE)
    if not text then return nil, "no " .. install_plan.FILE end
    local chunk, err = loadstring(text, "=" .. install_plan.FILE)
    if not chunk then return nil, install_plan.FILE .. ": " .. tostring(err) end
    setfenv(chunk, {})
    local ok, plan = pcall(chunk)
    if not ok or type(plan) ~= "table" then return nil, install_plan.FILE .. " isn't a table" end
    if plan.format ~= install_plan.FORMAT then return nil, install_plan.FILE .. " isn't format " .. install_plan.FORMAT end
    return plan
end
-- }}}

-- {{{ install_plan.check: a plan against a schema and its build folder
-- schema: { <database> = { <table> = { columns = { names } } or { count = n } } }
-- (a table filled by position needs only its count). build_dir: optional;
-- with it, the files are checked against the folder and its server-stamp.
-- Returns true, or false and a list of problems (strings)
local function safe_rel(p)
    return type(p) == "string" and p ~= "" and p:sub(1, 1) ~= "/" and not p:find("\\", 1, true)
        and not ("/" .. p .. "/"):find("/%.%.?/") and not p:find("//", 1, true)
end

function install_plan.check(plan, schema, build_dir)
    local problems = {}
    local function bad(s) problems[#problems + 1] = s end
    if type(plan) ~= "table" or plan.format ~= install_plan.FORMAT then
        return false, { "not a format " .. install_plan.FORMAT .. " plan" }
    end
    schema = schema or {}
    local places = plan.places or {}
    for _, q in ipairs(plan.sql or {}) do
        if not schema[q.database] then bad(q.file .. ": no database " .. tostring(q.database)) end
        if build_dir and not read_file(build_dir .. "/" .. q.file) then bad(q.file .. ": not in the build") end
        if not (places[q.database] and places[q.database].kind == "database") then
            bad(q.file .. ": its database " .. tostring(q.database) .. " isn't one of the plan's places")
        end
    end
    for i, st in ipairs(plan.tables or {}) do
        local where = string.format("%s, statement %d", tostring(st.from), i)
        local db = schema[st.database]
        local t = db and st.table and db[st.table]
        if st.does == "other" or st.odd then
            bad(where .. ": a statement the plan can't place")
        elseif not db then
            bad(where .. ": no database " .. tostring(st.database))
        elseif not t then
            bad(where .. ": no table " .. tostring(st.table) .. " in " .. st.database)
        elseif st.does == "insert" or st.does == "replace" then
            local count = t.columns and #t.columns or t.count
            local have = {}
            for _, c in ipairs(t.columns or {}) do have[c] = true end
            local want
            if st.columns then
                local seen = {}
                for _, c in ipairs(st.columns) do
                    if seen[c] then bad(where .. ": column " .. c .. " twice") end
                    seen[c] = true
                    if not t.columns then bad(where .. ": " .. st.table .. " is filled by position, not by name")
                    elseif not have[c] then bad(where .. ": no column " .. c .. " in " .. st.table) end
                end
                want = #st.columns
            else
                want = count
            end
            if st.values_differ then
                bad(where .. ": its rows have " .. table.concat(st.values_differ, " or ") .. " values")
            elseif (st.rows or 0) == 0 then
                bad(where .. ": no rows")
            elseif st.values ~= want then
                bad(string.format("%s: %s's rows have %s values, %d wanted", where, st.table, tostring(st.values), want or -1))
            end
        end
    end
    local stamped = {}
    if build_dir then
        for _, rel in ipairs(server_stamp.files(build_dir)) do stamped[rel] = true end
    end
    local to_seen, from_seen = {}, {}
    for _, f in ipairs(plan.files or {}) do
        local p = places[f.place]
        if not (p and p.kind == "folder") then bad(tostring(f.from) .. ": no folder " .. tostring(f.place) .. " among the plan's places") end
        if not safe_rel(f.to) then bad(tostring(f.from) .. ": goes to " .. tostring(f.to) .. ", not a path inside its place") end
        if not safe_rel(f.from) then bad(tostring(f.from) .. ": not a path inside the build") end
        local key = tostring(f.place) .. ":" .. tostring(f.to)
        if to_seen[key] then bad(tostring(f.from) .. ": goes where " .. to_seen[key] .. " goes") end
        to_seen[key] = f.from
        from_seen[f.from or ""] = true
        if build_dir then
            if not read_file(build_dir .. "/" .. tostring(f.from)) then bad(tostring(f.from) .. ": not in the build") end
            if f.stamped ~= false and not stamped[f.from] then bad(tostring(f.from) .. ": the server-stamp doesn't name it") end
        end
    end
    if build_dir then
        local accounted = {}
        for _, q in ipairs(plan.sql or {}) do accounted[q.file] = true end
        for _, k in ipairs(plan.kept or {}) do accounted[k.file] = true end
        for rel in pairs(stamped) do
            if not accounted[rel] and not from_seen[rel] then bad(rel .. ": the server reads it, and the plan neither installs nor keeps it") end
        end
    end
    table.sort(problems)
    return #problems == 0, problems
end
-- }}}

return install_plan
